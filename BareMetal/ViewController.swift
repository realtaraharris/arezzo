//
//  ViewController.swift
//  BareMetal
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import AudioToolbox
import Combine
import Foundation
import Metal
import QuartzCore
import simd // vector_float2, vector_float4
import UIKit

class RenderedShape {
    var startIndex: Int
    var endIndex: Int
    var geometryBuffer: MTLBuffer
    var colorBuffer: MTLBuffer
    var widthBuffer: MTLBuffer

    init(startIndex: Int, endIndex: Int, geometryBuffer: MTLBuffer, colorBuffer: MTLBuffer, widthBuffer: MTLBuffer) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.geometryBuffer = geometryBuffer
        self.colorBuffer = colorBuffer
        self.widthBuffer = widthBuffer
    }
}

class ViewController: UIViewController, ToolbarDelegate {
    func startExport() {
        let outputUrl = getDocumentsDirectory().appendingPathComponent("BareMetalVideo.m4v")

        do {
            try FileManager.default.removeItem(at: outputUrl)
        } catch let error as NSError {
            print("Error: \(error.domain)")
        }

        let screenScale = UIScreen.main.scale
        let outputSize = CGSize(width: view.frame.width * screenScale, height: view.frame.height * screenScale)

        // let outputSize = CGSize(width: 320, height: 200)
        self.mvr = MetalVideoRecorder(outputURL: outputUrl, size: outputSize)
        self.mvr!.startRecording()

        let (startIndex, endIndex) = self.drawOperationCollector.getTimestampIndices(startPosition: self.startPosition, endPosition: self.endPosition)
        var timestampIterator = self.drawOperationCollector.getTimestampIterator(startIndex: startIndex, endIndex: endIndex)

        let firstPlaybackTimestamp = self.drawOperationCollector.timestamps[startIndex]
        let firstTimestamp = self.drawOperationCollector.timestamps[0]
        let timeOffset = firstPlaybackTimestamp - firstTimestamp

        self.playingState.lastIndexRead = calcBufferOffset(timeOffset: timeOffset)
        let totalAudioLength: Float = Float(self.drawOperationCollector.audioData.count)

        let (firstTime, _) = timestampIterator.next()!
        let startTime = CFAbsoluteTimeGetCurrent()

        print("firstTime:", firstTime, "startTime:", startTime)

        func renderNext() {
            let (currentTime, nextTime) = timestampIterator.next()!

            print("currentTime:", currentTime, "nextTime:", nextTime)

            if nextTime == -1 {
                self.playingState.running = false
                return
            }

            self.render(endTimestamp: currentTime, present: false)

            let fireDate = startTime + nextTime - firstTime
        }
        self.playingState.running = true

        while self.playingState.running {
            renderNext()
        }

        self.mvr!.endRecording {}
    }

    func endExport() {}

    var device: MTLDevice!
    var metalLayer: CAMetalLayer

    var segmentVertexBuffer: MTLBuffer!
    var segmentIndexBuffer: MTLBuffer!
    var capVertexBuffer: MTLBuffer!
    var capIndexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!

    var renderedShapes: [RenderedShape] = []

    var commandQueue: MTLCommandQueue!
    var segmentRenderPipelineState: MTLRenderPipelineState!
    var capRenderPipelineState: MTLRenderPipelineState!
    var timer: CADisplayLink!
    var selectedColor: [Float] = [1.0, 0.0, 0.0, 1.0]
    var lineWidth: Float = DEFAULT_LINE_WIDTH
    var playing: Bool = false
    var recording: Bool = false
    var mode: String = "draw"
    private var width: CGFloat = 0.0
    private var height: CGFloat = 0.0
    var startPosition: Double = 0.0
    var endPosition: Double = 1.0

    var queue: AudioQueueRef?
    var recordingState: RecordingState
    var playingState: PlayingState

    var mvr: MetalVideoRecorder?

    @available(iOS 9.1, *)
    public enum TouchType: Equatable, CaseIterable {
        case finger, pencil

        var uiTouchTypes: [UITouch.TouchType] {
            switch self {
            case .finger:
                return [.direct, .indirect]
            case .pencil:
                return [.pencil, .stylus]
            }
        }
    }

    @available(iOS 9.1, *)
    public lazy var allowedTouchTypes: [TouchType] = [.finger, .pencil]

    private var lastTimestampDrawn: Double = 0
    private var uiRects: [String: CGRect] = [:]
    private var translation: CGPoint = .zero // [Float] = [0.0, 0.0]
    var drawOperationCollector: DrawOperationCollector // TODO: consider renaming this to shapeCollector
    public var toolbar: Toolbar
    private let capEdges = 21

    private var points: [[Float]] = []
    private var indexData: [Float] = []
    private var panStart: CGPoint = .zero
    private var panEnd: CGPoint = .zero
    private var panPosition: CGPoint = .zero
    public var playbackThread: Thread = Thread()
    public var recordingThread: Thread = Thread()

    var playbackSliderPosition: Float = 0
    var playbackSliderTimer: CFRunLoopTimer?

    // For pencil interactions
    @available(iOS 12.1, *)
    private lazy var pencilInteraction = UIPencilInteraction()

    required init?(coder aDecoder: NSCoder) {
        self.metalLayer = CAMetalLayer()

        self.device = MTLCreateSystemDefaultDevice()

        self.drawOperationCollector = DrawOperationCollector(device: self.device)

        self.recordingState = RecordingState(running: false, drawOperationCollector: self.drawOperationCollector)
        self.playingState = PlayingState(running: false, lastIndexRead: 0, audioData: [])
        /*
         drawOperationCollector.beginProvisionalOps()
         drawOperationCollector.addOp(PenDown(color: [1.0, 0.0, 1.0, 1.0], lineWidth: DEFAULT_LINE_WIDTH, timestamp: Date().toMilliseconds(), id: 0))
         drawOperationCollector.addOp(Point(point: [310, 645], timestamp: Date().toMilliseconds(), id: 1))
         drawOperationCollector.addOp(Point(point: [284.791, 429.16245], timestamp: Date().toMilliseconds(), id: 1))
         drawOperationCollector.addOp(Point(point: [800, 100], timestamp: Date().toMilliseconds(), id: 1))
         drawOperationCollector.addOp(PenUp(timestamp: Date().toMilliseconds(), id: 4))
         drawOperationCollector.commitProvisionalOps()
         */

        self.toolbar = Toolbar()

        super.init(coder: aDecoder)
    }

    @objc override func viewDidLoad() {
        super.viewDidLoad()

        self.translation = .zero // [0, 0]

        // Do any additional setup after loading the view.

        self.metalLayer.device = self.device
        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.framebufferOnly = false
        self.metalLayer.frame = view.layer.frame

        let screenScale = UIScreen.main.scale
        self.metalLayer.drawableSize = CGSize(width: view.frame.width * screenScale, height: view.frame.height * screenScale)
        view.layer.addSublayer(self.metalLayer)

        self.setupRender()

        self.toolbar.delegate = self
        view.addSubview(self.toolbar.view)

        guard let defaultLibrary = device.makeDefaultLibrary() else { return }

        let segmentPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        segmentPipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "segment_vertex")
        segmentPipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "basic_fragment")
        segmentPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let capPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        capPipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "cap_vertex")
        capPipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "basic_fragment")
        capPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let vertexDesc = MTLVertexDescriptor()

        vertexDesc.attributes[0].format = MTLVertexFormat.float2
        vertexDesc.attributes[0].offset = 0
        vertexDesc.attributes[0].bufferIndex = 0

        vertexDesc.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
        vertexDesc.layouts[0].stride = MemoryLayout<Float>.stride * 4

        segmentPipelineStateDescriptor.vertexDescriptor = vertexDesc
        capPipelineStateDescriptor.vertexDescriptor = vertexDesc

        do {
            try self.segmentRenderPipelineState = self.device.makeRenderPipelineState(descriptor: segmentPipelineStateDescriptor)
            try self.capRenderPipelineState = self.device.makeRenderPipelineState(descriptor: capPipelineStateDescriptor)
        } catch {
            print("Failed to create pipeline state, error \(error)")
        }

        self.commandQueue = self.device.makeCommandQueue() // this is expensive to create, so we save a reference to it

        self.width = self.view.frame.width
        self.height = self.view.frame.height
    }

    @objc func stopPlayUI() {
        self.toolbar.togglePlaying()
    }

    func triggerProgrammaticCapture() {
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = self.device
        do {
            try captureManager.startCapture(with: captureDescriptor)
        } catch {
            fatalError("error when trying to capture: \(error)")
        }
    }

    public func startPlaying() {
        if self.playing { return }

        self.playing = true
        self.playingState.audioData = self.drawOperationCollector.audioData
        self.playingState.lastIndexRead = 0
        self.playbackThread = Thread(target: self, selector: #selector(self.playback(thread:)), object: nil)
        self.playbackThread.start()

        func updatePlaybackSlider(_: CFRunLoopTimer?) {
            self.toolbar.playbackSlider!.value = self.playbackSliderPosition
        }

        let sliderUpdateInterval: CFTimeInterval = 1 / 60 // seconds
        self.playbackSliderTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent(), sliderUpdateInterval, 0, 0, updatePlaybackSlider)
        RunLoop.current.add(self.playbackSliderTimer!, forMode: .common)
    }

    public func stopPlaying() {
        self.playing = false
        self.playbackThread.cancel()

        CFRunLoopTimerInvalidate(self.playbackSliderTimer)
    }

    public func startRecording() {
        print("in startRecording")
        self.recording = true
        self.recordingThread = Thread(target: self, selector: #selector(self.recording(thread:)), object: nil)
        self.recordingThread.start()
    }

    public func stopRecording() {
        print("in stopRecording")
        self.recording = false
        self.recordingThread.cancel()
    }

    public func setDrawMode() {
        self.mode = "draw"
    }

    public func setPanMode() {
        self.mode = "pan"
    }

    func save() {
        print("SAVE")
        self.drawOperationCollector.serialize()
    }

    func restore() {
        print("RESTORE")
        self.drawOperationCollector.deserialize()
    }

    func clear() {
        print("CLEAR")
        self.drawOperationCollector.clear()
        let timestamp = getCurrentTimestamp()
        self.render(endTimestamp: timestamp, present: true)
    }

    public func setLineWidth(_ lineWidth: Float) {
        self.lineWidth = lineWidth
    }

    func setPlaybackPosition(_ playbackPosition: Float) {
        print("playback position:", playbackPosition)
        self.startPosition = Double(playbackPosition)
        self.endPosition = 1.0
    }

    final func generateVerts(endTimestamp: Double) {
        self.renderedShapes.removeAll(keepingCapacity: false)

        self.translation = .zero

        for shape in self.drawOperationCollector.shapeList {
            if shape.type == "Pan" {
                if shape.panPoints.count == 0 { continue }
                let end = shape.getIndex(timestamp: endTimestamp)
                if end >= 2 {
                    self.translation.x += CGFloat(shape.panPoints[end - 2])
                    self.translation.y += CGFloat(shape.panPoints[end - 1])
                }

                continue
            }

            if shape.timestamp.count == 0 || shape.geometryBuffer == nil { continue }
            // if shape.notInWindow() { continue }

            let start = 0
            let end = shape.getIndex(timestamp: endTimestamp)

            if start > end || start == end { continue }

            self.renderedShapes.append(RenderedShape(
                startIndex: start,
                endIndex: end,
                geometryBuffer: shape.geometryBuffer,
                colorBuffer: shape.colorBuffer,
                widthBuffer: shape.widthBuffer
            ))
        }

        let tr = self.transform(self.translation)
        let modelViewMatrix: Matrix4x4 = Matrix4x4.translate(x: tr[0], y: tr[1])
        let uniform = Uniforms(width: Float(self.width), height: Float(self.height), modelViewMatrix: modelViewMatrix)
        let uniforms = [uniform]
        uniformBuffer = self.device.makeBuffer(
            length: MemoryLayout<Uniforms>.size,
            options: []
        )
        memcpy(self.uniformBuffer.contents(), uniforms, MemoryLayout<Uniforms>.size)
    }

    final func setupRender() {
        let segmentVertices: [Float] = [
            0.0, -0.5,
            0.0, 0.5,
            1.0, 0.5,
            1.0, -0.5,
        ]
        let segmentIndices: [UInt32] = shapeIndices(edges: 4)
        segmentVertexBuffer = self.device.makeBuffer(bytes: segmentVertices,
                                                     length: segmentVertices.count * MemoryLayout.size(ofValue: segmentVertices[0]),
                                                     options: .storageModeShared)
        self.segmentIndexBuffer = self.device.makeBuffer(bytes: segmentIndices,
                                                         length: segmentIndices.count * MemoryLayout.size(ofValue: segmentIndices[0]),
                                                         options: .storageModeShared)

        let capVertices: [Float] = circleGeometry(edges: capEdges)
        let capIndices: [UInt32] = shapeIndices(edges: capEdges)
        capVertexBuffer = self.device.makeBuffer(bytes: capVertices,
                                                 length: capVertices.count * MemoryLayout.size(ofValue: capVertices[0]),
                                                 options: .storageModeShared)
        self.capIndexBuffer = self.device.makeBuffer(bytes: capIndices,
                                                     length: capIndices.count * MemoryLayout.size(ofValue: capIndices[0]),
                                                     options: .storageModeShared)
    }

    final func render(endTimestamp: Double, present: Bool) {
        guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0 / 255.0, green: 0.0 / 255.0, blue: 0.0 / 255.0, alpha: 1.0)

        self.generateVerts(endTimestamp: endTimestamp)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.setVertexBuffer(self.uniformBuffer, offset: 0, index: 2)

        for index in 0 ..< self.renderedShapes.count {
            let rs: RenderedShape = self.renderedShapes[index]
            let instanceCount = (rs.endIndex - rs.startIndex) / 2
            renderCommandEncoder.setVertexBuffer(rs.widthBuffer, offset: 0, index: 4)
            renderCommandEncoder.setVertexBuffer(rs.geometryBuffer, offset: 0, index: 3)
            renderCommandEncoder.setVertexBuffer(rs.colorBuffer, offset: 0, index: 1)

            renderCommandEncoder.setRenderPipelineState(self.segmentRenderPipelineState)
            renderCommandEncoder.setVertexBuffer(self.segmentVertexBuffer, offset: 0, index: 0)
            renderCommandEncoder.drawIndexedPrimitives(
                type: .triangleStrip,
                indexCount: 4,
                indexType: MTLIndexType.uint32,
                indexBuffer: self.segmentIndexBuffer,
                indexBufferOffset: 0,
                instanceCount: instanceCount
            )

            renderCommandEncoder.setRenderPipelineState(self.capRenderPipelineState)
            renderCommandEncoder.setVertexBuffer(self.capVertexBuffer, offset: 0, index: 0)
            renderCommandEncoder.drawIndexedPrimitives(
                type: .triangleStrip,
                indexCount: self.capEdges,
                indexType: MTLIndexType.uint32,
                indexBuffer: self.capIndexBuffer,
                indexBufferOffset: 0,
                instanceCount: instanceCount + 1 // + 1 for the last cap
            )
        }

        renderCommandEncoder.endEncoding()

        if present {
            commandBuffer.present(drawable)
        } else {
            let texture = drawable.texture
            commandBuffer.addCompletedHandler { _ in
                self.mvr?.writeFrame(forTexture: texture)
            }
        }

        // NB: you can pass in a time to present the finished image:
        // present(drawable: drawable, atTime presentationTime: CFTimeInterval)
        commandBuffer.commit()

        let captureManager = MTLCaptureManager.shared()
        captureManager.stopCapture()
    }

    final func transform(_ point: CGPoint) -> [Float] {
        let frameWidth: Float = Float(self.width)
        let frameHeight: Float = Float(self.height)
        let x: Float = Float(point.x)
        let y: Float = Float(point.y)

        return [
            (2.0 * x / frameWidth) + 1.0,
            (2.0 * -y / frameHeight) - 1.0,
        ]
    }

    // MARK: - input event handlers

    override open func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.recording, let touch = touches.first else { return }

        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }

        let timestamp = getCurrentTimestamp()

        self.drawOperationCollector.beginProvisionalOps()
        self.drawOperationCollector.addOp(op: PenDown(color: self.selectedColor,
                                                      lineWidth: self.lineWidth,
                                                      timestamp: timestamp,
                                                      mode: self.mode))

        let currentPoint = touch.location(in: view)
        if self.mode == "pan" {
            self.panStart = currentPoint
        }

        self.render(endTimestamp: timestamp, present: true)
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.recording, let touch = touches.first else { return }

        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }

        let timestamp = getCurrentTimestamp()

        let currentPoint = touch.location(in: view)
        if self.mode == "draw" {
            self.drawOperationCollector.addOp(
                op: Point(point: [Float(currentPoint.x - self.panPosition.x), Float(currentPoint.y - self.panPosition.y)], timestamp: timestamp))
        } else if self.mode == "pan" {
            let delta: CGPoint = CGPoint(x: currentPoint.x - self.panStart.x, y: currentPoint.y - self.panStart.y)
            self.drawOperationCollector.addOp(
                op: Pan(point: [Float(delta.x), Float(delta.y)], timestamp: timestamp))
        } else {
            print("invalid mode: \(self.mode)")
        }

        self.render(endTimestamp: timestamp, present: true)
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
//        triggerProgrammaticCapture()
        guard self.recording, let touch = touches.first else { return }

        let timestamp = getCurrentTimestamp()

        self.drawOperationCollector.addOp(op: PenUp(timestamp: timestamp))
        self.drawOperationCollector.commitProvisionalOps()

        let currentPoint = touch.location(in: view)
        if self.mode == "pan" {
            self.panEnd = currentPoint

            let panDelta = CGPoint(x: self.panEnd.x - self.panStart.x, y: self.panEnd.y - self.panStart.y)

            self.panPosition = CGPoint(x: self.panPosition.x + panDelta.x, y: self.panPosition.y + panDelta.y)
        }

        self.render(endTimestamp: timestamp, present: true)
    }

    override open func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        self.drawOperationCollector.cancelProvisionalOps()
        guard self.recording else { return }

        let timestamp = getCurrentTimestamp()
        self.render(endTimestamp: timestamp, present: true)
    }
}
