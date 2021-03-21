//
//  ViewController.swift
//  BareMetal
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import AudioToolbox
import Combine
import CoreMedia
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

extension FileManager {
    func removePossibleItem(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            fatalError("\(error)")
        }
    }
}

@available(iOS 14.0, *)
@available(macCatalyst 14.0, *)
class ViewController: UIViewController, ToolbarDelegate {
    func setColor(color: UIColor) {
        let tempy = [
            Float(color.cgColor.components![0]),
            Float(color.cgColor.components![1]),
            Float(color.cgColor.components![2]),
            Float(color.cgColor.components![3]),
        ]
        self.selectedColor = tempy
    }

    func startExport() {
        let screenScale = UIScreen.main.scale
        let outputSize = CGSize(width: self.view.frame.width * screenScale, height: self.view.frame.height * screenScale)

        self.toolbar.startExportButton?.setTitle("Exporting", for: .normal)
        self.toolbar.startExportButton?.isEnabled = false
        self.toolbar.exportProgressIndicator?.isHidden = false

        DispatchQueue.global().async {
            self.actuallyDoExport(outputSize)
        }
    }

    func actuallyDoExport(_ outputSize: CGSize) {
        let outputUrl = getDocumentsDirectory().appendingPathComponent("BareMetalVideo.m4v")

        FileManager.default.removePossibleItem(at: outputUrl)

        self.mvr = MetalVideoRecorder(outputURL: outputUrl, size: outputSize)

        let (startIndex, endIndex) = self.drawOperationCollector.getTimestampIndices(startPosition: self.startPosition, endPosition: self.endPosition)
        var timestampIterator = self.drawOperationCollector.getTimestampIterator(startIndex: startIndex, endIndex: endIndex)

        let firstPlaybackTimestamp = self.drawOperationCollector.timestamps[startIndex]
        let firstTimestamp = self.drawOperationCollector.timestamps[0]
        let timeOffset = firstPlaybackTimestamp - firstTimestamp

        self.mvr!.startRecording(firstTimestamp)

        self.playingState.lastIndexRead = calcBufferOffset(timeOffset: timeOffset)

        let frameCount: Float = Float(self.drawOperationCollector.timestamps.count)
        var framesRendered = 0

        func renderNext() {
            let (currentTime, nextTime) = timestampIterator.next()!

            if nextTime == -1 {
                self.playingState.running = false
                return
            }

            self.renderOffline(firstTimestamp: firstPlaybackTimestamp, endTimestamp: currentTime)

            for op in self.drawOperationCollector.opList {
                if op.type != .audioClip || op.timestamp != currentTime { continue }
                let audioClip = op as! AudioClip
                let samples = createAudio(sampleBytes: audioClip.audioSamples, startFrm: audioClip.timestamp, nFrames: audioClip.audioSamples.count / 2, sampleRate: SAMPLE_RATE, numChannels: UInt32(CHANNEL_COUNT))
                self.mvr!.writeAudio(samples: samples!)
            }

            DispatchQueue.main.async {
                self.toolbar.exportProgressIndicator?.progress = Float(framesRendered) / frameCount
                framesRendered += 1
            }
        }
        self.playingState.running = true

        while self.playingState.running {
            renderNext()
        }

        self.mvr!.endRecording {
            DispatchQueue.main.async {
                self.toolbar.startExportButton?.setTitle("Start Export", for: .normal)
                self.toolbar.startExportButton?.isEnabled = true
                self.toolbar.exportProgressIndicator?.isHidden = true
                self.toolbar.exportProgressIndicator?.progress = 0
            }
        }
    }

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
    var nextRenderTimer: CFRunLoopTimer?

    var runNumber: Int = 0
    var currentRunNumber: Int = 0

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
    public var recordingThread: Thread = Thread()

    var playbackSliderPosition: Float = 0
    var playbackSliderTimer: CFRunLoopTimer?

    // For pencil interactions
    private lazy var pencilInteraction = UIPencilInteraction()

    required init?(coder aDecoder: NSCoder) {
        self.metalLayer = CAMetalLayer()

        self.device = MTLCreateSystemDefaultDevice()

        self.drawOperationCollector = DrawOperationCollector(device: self.device)

        self.recordingState = RecordingState(running: false, drawOperationCollector: self.drawOperationCollector)
        self.playingState = PlayingState(running: false, lastIndexRead: 0, audioData: [])
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
        self.playback(runNumber: self.runNumber)
        self.runNumber += 1
    }

    public func stopPlaying() {
        guard self.nextRenderTimer != nil else {
            self.playing = false
            return
        }
        CFRunLoopTimerInvalidate(self.nextRenderTimer)
        check(AudioQueueStop(self.queue!, true))
        check(AudioQueueDispose(self.queue!, true))
        self.playing = false
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
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                self.toolbar.saveIndicator?.startAnimating()
                self.toolbar.saveButton?.isEnabled = false
                self.toolbar.saveButton?.setTitle("Saving", for: UIControl.State.normal)
            }
            self.drawOperationCollector.serialize()
            DispatchQueue.main.async {
                self.toolbar.saveIndicator?.stopAnimating()
                self.toolbar.saveButton?.isEnabled = true
                self.toolbar.saveButton?.setTitle("Save", for: UIControl.State.normal)
            }
        }
    }

    func restore() {
        self.toolbar.restoreButton?.setTitle("Restoring", for: .normal)
        self.toolbar.restoreButton?.isEnabled = false
        self.toolbar.restoreProgressIndicator?.isHidden = false
        DispatchQueue.global().async {
            func progressCallback(todoCount: Int, todo: Int) {
                let progress = Float(todoCount) / Float(todo)

                DispatchQueue.main.async {
                    self.toolbar.restoreProgressIndicator?.progress = progress
                }
            }
            self.drawOperationCollector.deserialize(progressCallback)
            DispatchQueue.main.async {
                self.toolbar.restoreButton?.setTitle("Restore", for: .normal)
                self.toolbar.restoreButton?.isEnabled = true
                self.toolbar.restoreProgressIndicator?.isHidden = true
                self.toolbar.restoreProgressIndicator?.progress = 0
            }
        }
    }

    func clear() {
        print("CLEAR")
        self.panStart = .zero
        self.panEnd = .zero
        self.panPosition = .zero

        self.drawOperationCollector.clear()
        let timestamp = getCurrentTimestamp()
        self.render(endTimestamp: timestamp)
    }

    public func setLineWidth(_ lineWidth: Float) {
        self.lineWidth = lineWidth
    }

    func setPlaybackPosition(_ playbackPosition: Float) {
        let wasPlaying = self.playing
        if self.playing {
            self.stopPlaying()
        }
        if self.drawOperationCollector.timestamps.count == 0 { return }
        self.render(endTimestamp: self.drawOperationCollector.getTimestamp(position: Double(playbackPosition)))
        self.startPosition = Double(playbackPosition)
        self.endPosition = 1.0
        if wasPlaying {
            self.startPlaying()
        }
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

    final func renderOffline(firstTimestamp _: Double, endTimestamp: Double) {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2DArray
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = Int(self.width * 2)
        textureDescriptor.height = Int(self.height * 2)
        textureDescriptor.arrayLength = 1
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        let texture: MTLTexture = self.device.makeTexture(descriptor: textureDescriptor)!

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
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

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        self.mvr?.writeFrame(forTexture: texture, timestamp: endTimestamp)
    }

    final func render(endTimestamp: Double) {
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

        commandBuffer.present(drawable)
        commandBuffer.commit()

        // let captureManager = MTLCaptureManager.shared()
        // captureManager.stopCapture()
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

        guard self.allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }

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

        self.render(endTimestamp: timestamp)
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.recording, let touch = touches.first else { return }

        guard self.allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }

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

        self.render(endTimestamp: timestamp)
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

        self.render(endTimestamp: timestamp)
    }

    override open func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        self.drawOperationCollector.cancelProvisionalOps()
        guard self.recording else { return }

        let timestamp = getCurrentTimestamp()
        self.render(endTimestamp: timestamp)
    }
}
