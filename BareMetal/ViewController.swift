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

struct CachedFrame {
    var vertexData: [Float]
    var colorData: [Float]
    var shapeIndex: [Int]
    var translation: [Float]
}

class RenderedShape {
    var startIndex: Int
    var endIndex: Int
    var renderBuffer: MTLBuffer

    init(startIndex: Int, endIndex: Int, renderBuffer: MTLBuffer) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.renderBuffer = renderBuffer
    }
}

class ViewController: UIViewController, ToolbarDelegate {
    var device: MTLDevice!
    var metalLayer: CAMetalLayer
    var segmentVertexBuffer: MTLBuffer!
    var segmentIndexBuffer: MTLBuffer!
    var capVertexBuffer: MTLBuffer!
    var capIndexBuffer: MTLBuffer!
    var colorBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!

    var pointBuffer: MTLBuffer!
    var quadraticBezierBuffer: MTLBuffer!
    var cubicBezierBuffer: MTLBuffer!
    var vertexColorBuffer: MTLBuffer!

    var pointBuffers: [RenderedShape] = []

    var commandQueue: MTLCommandQueue!
    var segmentRenderPipelineState: MTLRenderPipelineState!
    var capRenderPipelineState: MTLRenderPipelineState!
    var timer: CADisplayLink!
    var shapeIndex: [Int] = []
    var vertexCount: Int = 0
    var previousDropOpCount = 0
    var selectedColor: [Float] = [1.0, 0.0, 0.0, 1.0]
    var strokeWidth: Float = DEFAULT_STROKE_THICKNESS
    var playing: Bool = false
    var recording: Bool = false
    var mode: String = "draw"
    let debugShapeLayer = CAShapeLayer()
    var cachedItems: [Int64: CachedFrame] = [:]

    var cluesLabel: UILabel!
    var answersLabel: UILabel!
    var currentAnswer: UITextField!
    var recordButton: UIButton!
    var letterButtons = [UIButton]()

    private var delegate = ContentViewDelegate()
    private var audioRec = AudioRecorder()
    private var audioPla = AudioPlayer()
    private var textChangePublisher: AnyCancellable?

    public var isDrawingEnabled = true
    public var shouldDrawStraight = false

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

    public var firstPoint: CGPoint = .zero
    public var currentPoint: CGPoint = .zero
    private var previousPoint: CGPoint = .zero
    private var previousPreviousPoint: CGPoint = .zero
    private var playbackStartTimestamp: Int64 = 0 // Date().toMilliseconds()
    private var playbackEndTimestamp: Int64 = Date().toMilliseconds()
    private var timestamps = OrderedSet<Int64>()
    private var lastTimestampDrawn: Int64 = 0
    private var uiRects: [String: CGRect] = [:]
    private var translation: [Float] = [0.0, 0.0]
    private var drawOperationCollector: DrawOperationCollector // TODO: consider renaming this to shapeCollector
//    private var newToolbar: ToolbarEx
    private var id: Int64 = 0
    private let capEdges = 9

    private var points: [[Float]] = []
    private var colorData: [Float] = []
    private var indexData: [Float] = []

    // For pencil interactions
    @available(iOS 12.1, *)
    private lazy var pencilInteraction = UIPencilInteraction()

    required init?(coder aDecoder: NSCoder) {
        metalLayer = CAMetalLayer()

        device = MTLCreateSystemDefaultDevice()

        drawOperationCollector = DrawOperationCollector(device: device)
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

        translation = [0, 0]

        // Do any additional setup after loading the view.

        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame

        let screenScale = UIScreen.main.scale
        metalLayer.drawableSize = CGSize(width: view.frame.width * screenScale, height: view.frame.height * screenScale)
        view.layer.addSublayer(metalLayer)

        setupRender()

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
        textChangePublisher = delegate.didChange.sink { delegate in
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
            try segmentRenderPipelineState = device.makeRenderPipelineState(descriptor: segmentPipelineStateDescriptor)
            try capRenderPipelineState = device.makeRenderPipelineState(descriptor: capPipelineStateDescriptor)
        } catch {
            print("Failed to create pipeline state, error \(error)")
        }

        commandQueue = device.makeCommandQueue() // this is expensive to create, so we save a reference to it

        timer = CADisplayLink(target: self, selector: #selector(ViewController.gameloop))
        timer.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
    }

    func triggerProgrammaticCapture() {
        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = device
        do {
            try captureManager.startCapture(with: captureDescriptor)
        } catch {
            fatalError("error when trying to capture: \(error)")
        }
    }

    final func veryRandomColor() -> [Float] {
        [Float.r(n: Float.random(in: 0.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
         Float.r(n: Float.random(in: 0.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
         Float.r(n: Float.random(in: 0.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
         0.7]
    }

    public func startPlaying() {
        if playing { return }

        playing = true

        var timestampIterator = timestamps.makeIterator()
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
        playing = false
    }

    public func startRecording() {
        print("in startRecording")
        recording = true
        timestamps.append(getCurrentTimestamp())
    }

    public func stopRecording() {
        print("in stopRecording")
        recording = false
        timestamps.append(getCurrentTimestamp())
    }

    final func generateVerts() {
        let translation: [Float] = [0, 0]
        colorData = []
        pointBuffers.removeAll(keepingCapacity: false)

        var _: [Float] = [0.0, 1.0, 1.0, 1.0]
        var _: Float = DEFAULT_STROKE_THICKNESS

        for shape in drawOperationCollector.shapeList {
            if shape.timestamp.count == 0 || shape.renderBuffer == nil { continue }
            // if shape.notInWindow() { continue }

            let start = 0
            let end = shape.getIndex(timestamp: playbackEndTimestamp)

            if start > end || start == end { continue }

            pointBuffers.append(RenderedShape(
                startIndex: start,
                endIndex: end,
                renderBuffer: shape.renderBuffer
            ))
        }

        colorBuffer = device.makeBuffer(bytes: colorData, length: colorData.count * MemoryLayout.size(ofValue: 4), options: .storageModeShared)

        self.translation = translation

        let tr = transform(translation)
        let modelViewMatrix: Matrix4x4 = Matrix4x4.translate(x: tr[0], y: tr[1])
        let uniform = Uniforms(width: Float(view.frame.size.width), height: Float(view.frame.size.height), modelViewMatrix: modelViewMatrix)
        let uniforms = [uniform]
        uniformBuffer = device.makeBuffer(
            length: MemoryLayout<Uniforms>.size,
            options: []
        )
        memcpy(uniformBuffer.contents(), uniforms, MemoryLayout<Uniforms>.size)
    }

    final func setupRender() {
        let segmentVertices: [Float] = [
            0.0, -0.5,
            0.0, 0.5,
            1.0, 0.5,
            1.0, -0.5,
        ]
        let segmentIndices: [UInt32] = shapeIndices(edges: 4)
        segmentVertexBuffer = device.makeBuffer(bytes: segmentVertices,
                                                length: segmentVertices.count * MemoryLayout.size(ofValue: segmentVertices[0]),
                                                options: .storageModeShared)
        segmentIndexBuffer = device.makeBuffer(bytes: segmentIndices,
                                               length: segmentIndices.count * MemoryLayout.size(ofValue: segmentIndices[0]),
                                               options: .storageModeShared)

        let capVertices: [Float] = circleGeometry(edges: capEdges)
        let capIndices: [UInt32] = shapeIndices(edges: capEdges)
        capVertexBuffer = device.makeBuffer(bytes: capVertices,
                                            length: capVertices.count * MemoryLayout.size(ofValue: capVertices[0]),
                                            options: .storageModeShared)
        capIndexBuffer = device.makeBuffer(bytes: capIndices,
                                           length: capIndices.count * MemoryLayout.size(ofValue: capIndices[0]),
                                           options: .storageModeShared)
    }

    final func render() {
        guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0 / 255.0, green: 0.0 / 255.0, blue: 0.0 / 255.0, alpha: 1.0)

        generateVerts()

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.setVertexBuffer(colorBuffer, offset: 0, index: 1)
        renderCommandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 2)

        for index in 0 ..< pointBuffers.count {
            let rs: RenderedShape = pointBuffers[index]
            let instanceCount = (rs.endIndex - rs.startIndex) / 2
            renderCommandEncoder.setVertexBuffer(rs.renderBuffer, offset: 0, index: 3)

            renderCommandEncoder.setRenderPipelineState(segmentRenderPipelineState)
            renderCommandEncoder.setVertexBuffer(segmentVertexBuffer, offset: 0, index: 0)
            renderCommandEncoder.drawIndexedPrimitives(
                type: .triangleStrip,
                indexCount: 4,
                indexType: MTLIndexType.uint32,
                indexBuffer: segmentIndexBuffer,
                indexBufferOffset: 0,
                instanceCount: instanceCount
            )

            renderCommandEncoder.setRenderPipelineState(capRenderPipelineState)
            renderCommandEncoder.setVertexBuffer(capVertexBuffer, offset: 0, index: 0)
            renderCommandEncoder.drawIndexedPrimitives(
                type: .triangleStrip,
                indexCount: capEdges,
                indexType: MTLIndexType.uint32,
                indexBuffer: capIndexBuffer,
                indexBufferOffset: 0,
                instanceCount: instanceCount + 1 // + 1 for the last cap
            )
        }

        renderCommandEncoder.endEncoding()
        commandBuffer.present(drawable)
        // NB: you can pass in a time to present the finished image:
        // present(drawable: drawable, atTime presentationTime: CFTimeInterval)
        commandBuffer.commit()

//        let captureManager = MTLCaptureManager.shared()
//        captureManager.stopCapture()
    }

    final func transform(_ point: [Float]) -> [Float] {
        let frameWidth: Float = Float(view.frame.size.width)
        let frameHeight: Float = Float(view.frame.size.height)
        let x = point[0]
        let y = point[1]

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
        if !recording { return }

        guard isDrawingEnabled, let touch = touches.first else { return }

        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }

        setTouchPoints(for: touch, view: view)
        firstPoint = touch.location(in: view)

        let timestamp = getCurrentTimestamp()
        timestamps.append(timestamp)
        playbackEndTimestamp = timestamp
        drawOperationCollector.beginProvisionalOps()
        drawOperationCollector.addOp(PenDown(color: selectedColor,
                                             lineWidth: strokeWidth,
                                             timestamp: timestamp,
                                             id: getNextId()))
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        if !recording { return }

        guard isDrawingEnabled, let touch = touches.first else { return }

        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }

        updateTouchPoints(for: touch, in: view)
        let timestamp = getCurrentTimestamp()
        timestamps.append(timestamp)
        playbackEndTimestamp = timestamp

        if mode == "draw" {
            let currentPointEx = touch.location(in: view)
            drawOperationCollector.addOp(Point(point: [Float(currentPointEx.x), Float(currentPointEx.y)], timestamp: timestamp, id: getNextId()))
        } else if mode == "pan" {
            let midPoints = getMidPoints()
            let start = [Float(midPoints.0.x), Float(midPoints.0.y)]
            let end = [Float(midPoints.1.x), Float(midPoints.1.y)]
            drawOperationCollector.addOp(Pan(start: start, end: end, timestamp: timestamp, id: getNextId()))
        } else {
            print("invalid mode: \(mode)")
        }
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
//        triggerProgrammaticCapture()

        if !recording { return }

        guard isDrawingEnabled, let _ = touches.first else { return }

        let timestamp = getCurrentTimestamp()
        timestamps.append(timestamp)
        playbackEndTimestamp = timestamp
        drawOperationCollector.addOp(PenUp(timestamp: timestamp, id: getNextId()))
        drawOperationCollector.commitProvisionalOps()
    }

    override open func touchesCancelled(_ touches: Set<UITouch>, with _: UIEvent?) {
        print("touches cancelled!")

        drawOperationCollector.cancelProvisionalOps()

        if !recording { return }

        guard isDrawingEnabled, let _ = touches.first else { return }
    }

    // MARK: - utility functions

    private func setTouchPoints(for touch: UITouch, view: UIView) {
        previousPoint = touch.previousLocation(in: view)
        previousPreviousPoint = touch.previousLocation(in: view)
        currentPoint = touch.location(in: view)
    }

    private func updateTouchPoints(for touch: UITouch, in view: UIView) {
        previousPreviousPoint = previousPoint
        previousPoint = touch.previousLocation(in: view)
        currentPoint = touch.location(in: view)
    }

    private func calculateMidPoint(_ p1: CGPoint, p2: CGPoint) -> CGPoint {
        CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5)
    }

    private func getMidPoints() -> (CGPoint, CGPoint) {
        (
            calculateMidPoint(previousPoint, p2: previousPreviousPoint),
            calculateMidPoint(currentPoint, p2: previousPoint)
        )
    }

    @objc func gameloop() {
        autoreleasepool {
            if self.playing || self.recording {
                self.render()
            }
        }
    }
}
