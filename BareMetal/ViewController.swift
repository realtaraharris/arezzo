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

class ViewController: UIViewController, ToolbarDelegate {
    var device: MTLDevice!
    var metalLayer: CAMetalLayer
    var vertexBuffer: MTLBuffer!
    var colorBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var pointBuffer: MTLBuffer!
    var quadraticBezierBuffer: MTLBuffer!
    var cubicBezierBuffer: MTLBuffer!
    var vertexColorBuffer: MTLBuffer!

    var pointBuffers: [MTLBuffer] = []

    var commandQueue: MTLCommandQueue!
    var renderPipelineState: MTLRenderPipelineState!
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

    private var points: [[Float]] = []
    private var colorData: [Float] = []
    private var indexData: [Float] = []

    // For pencil interactions
    @available(iOS 12.1, *)
    private lazy var pencilInteraction = UIPencilInteraction()

    required init?(coder aDecoder: NSCoder) {
        metalLayer = CAMetalLayer()

        device = MTLCreateSystemDefaultDevice()

//        let speedScale: Int64 = 100_000
//        let firstTimestamp = getCurrentTimestamp()
        drawOperationCollector = DrawOperationCollector(device: device)
//        drawOperationCollector.addOp(PenDown(color: [1.0, 0.0, 1.0, 1.0], lineWidth: DEFAULT_STROKE_THICKNESS, timestamp: 0, id: 0))
//        drawOperationCollector.addOp(Point(point: [284.791, 429.16245], timestamp: 0, id: 1))
//        drawOperationCollector.addOp(Point(point: [316.145, 420.13748], timestamp: 0, id: 2))
//        drawOperationCollector.addOp(Point(point: [841.316, 592.8283], timestamp: 0, id: 3))
//        drawOperationCollector.addOp(PenUp(timestamp: 0, id: 4))
//        drawOperations = [
//            PenDown(color: [1.0, 0.0, 1.0, 1.0], lineWidth: DEFAULT_STROKE_THICKNESS, timestamp: 0),
//            Line(start: [200, 10], end: [300, 300], timestamp: 0),
//            Line(start: [20, 200], end: [600, 90], timestamp: 0),
//            QuadraticBezier(start: [0, 200], end: [1200, 200], control: [600, 0], timestamp: 0),
//            CubicBezier(start: [10, 20], end: [0, 900], control1: [50, 50], control2: [100, 100], timestamp: 0),
//            Line(start: [-0.68938684, -1], end: [-0.68938684, 0.14252508], timestamp: 0),
//            QuadraticBezier(start: [-0.68938684, -0.14252508], end: [-0.6803631, -0.14252508], control: [-0.68938684, -0.14252508], timestamp: firstTimestamp + 1 * speedScale),
//            QuadraticBezier(start: [-0.6803631, -0.14252508], end: [-0.6278378, -0.13724208], control: [-0.6713394, -0.14252508], timestamp: firstTimestamp + 2 * speedScale),
//            QuadraticBezier(start: [-0.6278378, -0.13724208], end: [-0.25760883, -0.1199224], control: [-0.5843361, -0.13195896], timestamp: firstTimestamp + 3 * speedScale),
//            QuadraticBezier(start: [-0.25760883, -0.1199224], end: [0.0788641, -0.10788584], control: [0.0691185, -0.10788584], timestamp: firstTimestamp + 1 * speedScale),
//            QuadraticBezier(start: [0.0788641, -0.10788584], end: [0.1432414, -0.11152661], control: [0.088609695, -0.10788584], timestamp: firstTimestamp + 4 * speedScale),
//            QuadraticBezier(start: [0.1432414, -0.11152661], end: [0.19852078, -0.11516762], control: [0.19787312, -0.11516762], timestamp: firstTimestamp + 5 * speedScale),
//            QuadraticBezier(start: [0.24, 0.3], end: [0.4, 0.4], control: [0.2, 0.6], timestamp: 1_595_985_214_348),
//            PenUp(timestamp: 0),
//            PenDown(color: [1.0, 0.0, 0.0, 1.0], lineWidth: DEFAULT_STROKE_THICKNESS, timestamp: 1_595_985_214_351),
//            CubicBezier(start: veryRandomVect(), end: veryRandomVect(), control1: veryRandomVect(), control2: veryRandomVect(), timestamp: 1_595_985_214_390),
//            PenUp(timestamp: 1_595_985_214_395),
//        ]

//        newToolbar = ToolbarEx()

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

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "basic_vertex")
        pipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "basic_fragment")
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let vertexDesc = MTLVertexDescriptor()

        vertexDesc.attributes[0].format = MTLVertexFormat.float2
        vertexDesc.attributes[0].offset = 0
        vertexDesc.attributes[0].bufferIndex = 0

        vertexDesc.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
        vertexDesc.layouts[0].stride = MemoryLayout<Float>.stride * 4

        pipelineStateDescriptor.vertexDescriptor = vertexDesc

        do {
            try renderPipelineState = device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
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

//    func circleGeometry(resolution) {
//      let position = [[0, 0]]
//      for (wedge = 0; wedge <= resolution; wedge++) {
//        let theta = (2 * Math.PI * wedge) / resolution
//        position.append([0.5 * Math.cos(theta), 0.5 * Math.sin(theta)])
//      }
//      return {
//        buffer: regl.buffer(position),
//        count: position.length
//      }
//    }

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

        var _: [Float] = []
        colorData = []

        pointBuffers.removeAll(keepingCapacity: false)

        let currentTime = getCurrentTimestamp()

        var _: Bool = false
        var _: [Float] = [0.0, 1.0, 1.0, 1.0]
        var _: Float = DEFAULT_STROKE_THICKNESS

        var _: [Float] = []
        var _: [Float] = []
        for shape in drawOperationCollector.shapeList {
            if shape.timestamp.count == 0 { return }
            if shape.timestamp[0] > currentTime { return }

            // if shape.notInWindow() { return }

            let start = 0
            let end = shape.getIndex(timestamp: currentTime) * 2

            if start == end { continue }

            // let's add the points!
            let pointies: [Float] = Array(shape.geometry[start ..< Int(end)])

            if pointies.count == 0 { continue }
            if shape.renderBuffer != nil {
                pointBuffers.append(shape.renderBuffer)
            }
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

    final func render() {
        guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0 / 255.0, green: 0.0 / 255.0, blue: 0.0 / 255.0, alpha: 1.0)

        let vertexData: [Float] = [
            0.0, -0.5,
            1.0, -0.5,
            1.0, 0.5,
            0.0, 0.5,
        ]
        let indexData: [UInt32] = [3, 2, 1, 3, 0]
        indexBuffer = device.makeBuffer(bytes: indexData, length: indexData.count * MemoryLayout.size(ofValue: indexData[0]), options: .storageModeShared)

        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData,
                                         length: dataSize,
                                         options: .storageModeShared)

        generateVerts()

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)

        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder.setVertexBuffer(colorBuffer, offset: 0, index: 1)
        renderCommandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 2)

        // 24 points -> 2 line segment instances
        // 16 points -> 1 line segment instance
        // 8 points -> 0  line segment instances
        // 24 / 8 - 1 = 2
        // 16 / 8 - 1 = 1
        // 8 / 8 - 1 = 0
//        if (pointBuffers.count > 0) {
        for index in 0 ..< pointBuffers.count {
            renderCommandEncoder.setVertexBuffer(pointBuffers[index], offset: 0, index: 3)
            renderCommandEncoder.drawIndexedPrimitives(
                type: .triangleStrip,
                indexCount: 5,
                indexType: MTLIndexType.uint32,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0,
                // the number of instances should be even and one less than
                // the number of points
                instanceCount: (pointBuffers[index].length / 8) - 1
            )
        }
//        }

        renderCommandEncoder.endEncoding()
        commandBuffer.present(drawable)
        // NB: you can pass in a time to present the finished image:
        // present(drawable: drawable, atTime presentationTime: CFTimeInterval)
        commandBuffer.commit()

        let captureManager = MTLCaptureManager.shared()
        captureManager.stopCapture()
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

//        if shouldDrawStraight {
//        } else {

        if mode == "draw" {
            let midPoints = getMidPoints()
            var start = [Float(midPoints.0.x), Float(midPoints.0.y)]
            var control = [Float(previousPoint.x), Float(previousPoint.y)]
            var end = [Float(midPoints.1.x), Float(midPoints.1.y)]

            start[0] -= translation[0]
            start[1] -= translation[1]

            control[0] -= translation[0]
            control[1] -= translation[1]

            end[0] -= translation[0]
            end[1] -= translation[1]

            if start[0] == control[0], start[1] == control[1] {
                return
            }

            /// CRITICAL here
            let currentPointEx = touch.location(in: view)
//            print("currentPointEx:", currentPointEx.x, currentPointEx.y)
            drawOperationCollector.addOp(Point(point: [Float(currentPointEx.x), Float(currentPointEx.y)], timestamp: timestamp, id: getNextId()))
//            drawOperationCollector.addOp(QuadraticBezier(start: start, end: end, control: control, timestamp: timestamp, id: getNextId()))
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
            self.render()
        }
    }
}
