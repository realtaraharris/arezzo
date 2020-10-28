//
//  ViewController.swift
//  BareMetal
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Combine
import Metal
import QuartzCore
import simd // vector_float2, vector_float4
import SwiftUI
import UIKit

let DEFAULT_STROKE_THICKNESS: Float = 5

class RenderedShape {
    var startIndex: Int
    var endIndex: Int
    var geometryBuffer: MTLBuffer
    var colorBuffer: MTLBuffer

    init(startIndex: Int, endIndex: Int, geometryBuffer: MTLBuffer, colorBuffer: MTLBuffer) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.geometryBuffer = geometryBuffer
        self.colorBuffer = colorBuffer
    }
}

class ViewController: UIViewController, ToolbarDelegate {
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
    var strokeWidth: Float = DEFAULT_STROKE_THICKNESS
    var playing: Bool = false
    var recording: Bool = false
    var mode: String = "draw"

    private var delegate = ContentViewDelegate()
    private var audioRec = AudioRecorder()
    private var audioPla = AudioPlayer()
    private var changePublisher: AnyCancellable?

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

    private var playbackStartTimestamp: Int64 = 0 // Date().toMilliseconds()
    private var playbackEndTimestamp: Int64 = Date().toMilliseconds()
    private var timestamps = OrderedSet<Int64>()
    private var lastTimestampDrawn: Int64 = 0
    private var uiRects: [String: CGRect] = [:]
    private var translation: CGPoint = .zero // [Float] = [0.0, 0.0]
    private var drawOperationCollector: DrawOperationCollector // TODO: consider renaming this to shapeCollector
//    private var newToolbar: ToolbarEx
    private var id: Int64 = 0
    private let capEdges = 9

    private var points: [[Float]] = []
    private var indexData: [Float] = []
    private var panStart: CGPoint = .zero

    // For pencil interactions
    @available(iOS 12.1, *)
    private lazy var pencilInteraction = UIPencilInteraction()

    required init?(coder aDecoder: NSCoder) {
        self.metalLayer = CAMetalLayer()

        self.device = MTLCreateSystemDefaultDevice()

        self.drawOperationCollector = DrawOperationCollector(device: self.device)
        /*
         drawOperationCollector.beginProvisionalOps()
         drawOperationCollector.addOp(PenDown(color: [1.0, 0.0, 1.0, 1.0], lineWidth: DEFAULT_STROKE_THICKNESS, timestamp: Date().toMilliseconds(), id: 0))
         drawOperationCollector.addOp(Point(point: [310, 645], timestamp: Date().toMilliseconds(), id: 1))
         drawOperationCollector.addOp(Point(point: [284.791, 429.16245], timestamp: Date().toMilliseconds(), id: 1))
         drawOperationCollector.addOp(Point(point: [800, 100], timestamp: Date().toMilliseconds(), id: 1))
         drawOperationCollector.addOp(PenUp(timestamp: Date().toMilliseconds(), id: 4))
         drawOperationCollector.commitProvisionalOps()
         */

        // newToolbar = ToolbarEx()

        super.init(coder: aDecoder)
    }

    @objc override func viewDidLoad() {
        super.viewDidLoad()

        self.translation = .zero // [0, 0]

        // Do any additional setup after loading the view.

        self.metalLayer.device = self.device
        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.framebufferOnly = true
        self.metalLayer.frame = view.layer.frame

        let screenScale = UIScreen.main.scale
        self.metalLayer.drawableSize = CGSize(width: view.frame.width * screenScale, height: view.frame.height * screenScale)
        view.layer.addSublayer(self.metalLayer)

        self.setupRender()

        // newToolbar.delegate = self
        // view.addSubview(newToolbar.view)

        let controller = UIHostingController(rootView: Toolbar(delegate: delegate, audioRec: audioRec, audioPla: audioPla))
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(controller)
        view.addSubview(controller.view)
        controller.view.backgroundColor = UIColor.clear
        controller.didMove(toParent: self)

        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        controller.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        controller.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        var previousDelegate: ContentViewDelegate = ContentViewDelegate()
        changePublisher = self.delegate.didChange.sink { delegate in
            // if delegate.clear {
            //     self.drawOperations.removeAll(keepingCapacity: false)
            //     self.timestamps.removeAll(keepingCapacity: false)
            // }

            if delegate.playing != previousDelegate.playing {
                if delegate.playing {
                    self.startPlaying()
                } else {
                    self.stopPlaying()
                }
            }

            if delegate.recording != previousDelegate.recording {
                if delegate.recording {
                    self.startRecording()
                } else {
                    self.stopRecording()
                }
            }

            self.mode = delegate.mode
            self.selectedColor = delegate.selectedColor.toColorArray()

            self.strokeWidth = delegate.strokeWidth

            previousDelegate = delegate.copy()
        }

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

        self.timer = CADisplayLink(target: self, selector: #selector(ViewController.gameloop))
        self.timer.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
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

        var timestampIterator = self.timestamps.makeIterator()
        let nextTime = timestampIterator.next()
        if nextTime == nil { return }
        var previousTimestamp: Int64 = nextTime!

        func getCurrentTimestamp() -> (timestamp: Int64, delta: Int64, pst: Int64, ok: Bool) {
            let nextval = timestampIterator.next()
            if nextval == nil { return (0, 0, 0, false) }
            let currentTimestamp = nextval!

            let delta: Int64 = currentTimestamp - previousTimestamp
            let pst = previousTimestamp
            previousTimestamp = currentTimestamp

            return (currentTimestamp, delta, pst, true)
        }

        DispatchQueue.global(qos: .userInteractive).async {
            while self.playing {
                let (timestamp, delta, _, ok) = getCurrentTimestamp()
                if !ok {
                    DispatchQueue.main.async {
                        self.delegate.playing = false
                    }
                    break
                }
                let sleepBy = UInt32(delta * 1000)
                usleep(sleepBy)
                self.playbackEndTimestamp = timestamp
            }
        }
    }

    public func stopPlaying() {
        self.playing = false
    }

    public func startRecording() {
        print("in startRecording")
        self.recording = true
        self.timestamps.append(getCurrentTimestamp())
    }

    public func stopRecording() {
        print("in stopRecording")
        self.recording = false
        self.timestamps.append(getCurrentTimestamp())
    }

    final func generateVerts() {
        self.renderedShapes.removeAll(keepingCapacity: false)

        self.translation = .zero

        for shape in self.drawOperationCollector.shapeList {
            if shape.type == "Pan" {
                if shape.panPoints.count == 0 { continue }
                let end = shape.getIndex(timestamp: self.playbackEndTimestamp)
                if end >= 4 {
                    self.translation.x += CGFloat(shape.panPoints[end - 2])
                    self.translation.y += CGFloat(shape.panPoints[end - 1])
                }

                continue
            }

            if shape.timestamp.count == 0 || shape.geometryBuffer == nil { continue }
            // if shape.notInWindow() { continue }

            let start = 0
            let end = shape.getIndex(timestamp: self.playbackEndTimestamp)

            if start > end || start == end { continue }

            self.renderedShapes.append(RenderedShape(
                startIndex: start,
                endIndex: end,
                geometryBuffer: shape.geometryBuffer,
                colorBuffer: shape.colorBuffer
            ))
        }

        let tr = self.transform(self.translation)
        let modelViewMatrix: Matrix4x4 = Matrix4x4.translate(x: tr[0], y: tr[1])
        let uniform = Uniforms(width: Float(view.frame.size.width), height: Float(view.frame.size.height), modelViewMatrix: modelViewMatrix)
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

    final func render() {
        guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0 / 255.0, green: 0.0 / 255.0, blue: 0.0 / 255.0, alpha: 1.0)

        self.generateVerts()

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.setVertexBuffer(self.uniformBuffer, offset: 0, index: 2)

        for index in 0 ..< self.renderedShapes.count {
            let rs: RenderedShape = self.renderedShapes[index]
            let instanceCount = (rs.endIndex - rs.startIndex) / 2
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
        // NB: you can pass in a time to present the finished image:
        // present(drawable: drawable, atTime presentationTime: CFTimeInterval)
        commandBuffer.commit()

        let captureManager = MTLCaptureManager.shared()
        captureManager.stopCapture()
    }

    final func transform(_ point: CGPoint) -> [Float] {
        let frameWidth: Float = Float(view.frame.size.width)
        let frameHeight: Float = Float(view.frame.size.height)
        let x: Float = Float(point.x)
        let y: Float = Float(point.y)

        return [
            (2.0 * x / frameWidth) + 1.0,
            (2.0 * -y / frameHeight) - 1.0,
        ]
    }

    func getNextId() -> Int64 {
        let id = self.id
        self.id += 1
        return id
    }

    // MARK: - input event handlers

    override open func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.recording, let touch = touches.first else { return }

        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }

        let timestamp = getCurrentTimestamp()
        timestamps.append(timestamp)
        self.playbackEndTimestamp = timestamp
        self.drawOperationCollector.beginProvisionalOps()
        self.drawOperationCollector.addOp(op: PenDown(color: self.selectedColor,
                                                      lineWidth: self.strokeWidth,
                                                      timestamp: timestamp,
                                                      id: self.getNextId()), mode: self.mode)

        let currentPoint = touch.location(in: view)
        if self.mode == "pan" {
            self.panStart = currentPoint
        }
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.recording, let touch = touches.first else { return }

        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }

        let timestamp = getCurrentTimestamp()
        timestamps.append(timestamp)
        self.playbackEndTimestamp = timestamp

        let currentPoint = touch.location(in: view)
        if self.mode == "draw" {
            self.drawOperationCollector.addOp(
                op: Point(point: [Float(currentPoint.x), Float(currentPoint.y)], timestamp: timestamp, id: self.getNextId()),
                mode: self.mode
            )
        } else if self.mode == "pan" {
            let delta: CGPoint = CGPoint(x: currentPoint.x - self.panStart.x, y: currentPoint.y - self.panStart.y)
            self.drawOperationCollector.addOp(
                op: Pan(point: [Float(delta.x), Float(delta.y)], timestamp: timestamp, id: self.getNextId()),
                mode: self.mode
            )
        } else {
            print("invalid mode: \(self.mode)")
        }
    }

    override open func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
//        triggerProgrammaticCapture()
        guard self.recording else { return }

        let timestamp = getCurrentTimestamp()
        timestamps.append(timestamp)
        self.playbackEndTimestamp = timestamp
        self.drawOperationCollector.addOp(op: PenUp(timestamp: timestamp, id: self.getNextId()), mode: self.mode)
        self.drawOperationCollector.commitProvisionalOps()
    }

    override open func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        self.drawOperationCollector.cancelProvisionalOps()
        guard self.recording else { return }
    }

    // MARK: - utility functions

    @objc func gameloop() {
        autoreleasepool {
            if self.playing || self.recording {
                self.render()
            }
        }
    }
}
