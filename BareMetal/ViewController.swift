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

let DEFAULT_STROKE_THICKNESS: Float = 0.01

func getCurrentTimestamp() -> Int64 {
    Date().toMilliseconds()
}

extension Date {
    func toMilliseconds() -> Int64 {
        Int64(timeIntervalSince1970 * 1000)
    }
}

func veryRandomVect() -> [Float] { [Float.r(n: Float.random(in: -1.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
                                    Float.r(n: Float.random(in: -1.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0))] }

public extension Float {
    static func r(n: Float, tol: Float) -> Float {
        let low = n - tol
        let high = n + tol
        return tol == 0 || low > high ? n : Float.random(in: low ..< high)
    }
}

struct Matrix4x4 {
    var X: SIMD4<Float>
    var Y: SIMD4<Float>
    var Z: SIMD4<Float>
    var W: SIMD4<Float>

    init() {
        X = SIMD4<Float>(x: 1, y: 0, z: 0, w: 0)
        Y = SIMD4<Float>(x: 0, y: 1, z: 0, w: 0)
        Z = SIMD4<Float>(x: 0, y: 0, z: 1, w: 0)
        W = SIMD4<Float>(x: 0, y: 0, z: 0, w: 1)
    }

    static func translate(x: Float, y: Float) -> Matrix4x4 {
        var mat: Matrix4x4 = Matrix4x4()

        mat.W.x = x
        mat.W.y = y

        return mat
    }
}

struct Uniforms {
    let modelViewMatrix: Matrix4x4
}

class ContentViewDelegate: ObservableObject {
    var didChange = PassthroughSubject<ContentViewDelegate, Never>()
    var objectWillChange = PassthroughSubject<ContentViewDelegate, Never>()

    var playing: Bool = false {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    var recording: Bool = false {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    // TODO: this is gross. is there nicer a way to call functions?
    var clear: Bool = false {
        didSet {
            didChange.send(self)
            clear = false
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    var selectedColor: Color = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0) {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    var strokeWidth: Float = DEFAULT_STROKE_THICKNESS {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    var mode: String = "draw" {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    var uiRects: [String: CGRect] = [:] {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }
}

class ViewController: UIViewController {
    var device: MTLDevice!
    var metalLayer: CAMetalLayer
    var vertexBuffer: MTLBuffer!
    var colorBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var quadraticBezierBuffer: MTLBuffer!
    var cubicBezierBuffer: MTLBuffer!
    var vertexColorBuffer: MTLBuffer!
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

    private var delegate = ContentViewDelegate()
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
    private var playbackStartTimestamp: Int64 = Date().toMilliseconds()
    private var playbackEndTimestamp: Int64 = Date().toMilliseconds()
    private var timestamps = OrderedSet<Int64>()
    private var lastTimestampDrawn: Int64 = 0
    private var uiRects: [String: CGRect] = [:]
    private var translation: [Float] = [0.0, 0.0]

    private var drawOperations: [DrawOperation]

    // For pencil interactions
    @available(iOS 12.1, *)
    private lazy var pencilInteraction = UIPencilInteraction()

    required init?(coder aDecoder: NSCoder) {
        metalLayer = CAMetalLayer()

//        let speedScale: Int64 = 100_000
//        let firstTimestamp = getCurrentTimestamp()
        drawOperations = [
            //                        PenDown(color: [1.0, 0.0, 1.0, 1.0], lineWidth: DEFAULT_STROKE_THICKNESS, timestamp: firstTimestamp),
//            Line(start: [-0.68938684, -1], end: [-0.68938684, 0.14252508], timestamp: 0),
//            QuadraticBezier(start: [-0.68938684, -0.14252508], end: [-0.6803631, -0.14252508], control: [-0.68938684, -0.14252508], timestamp: firstTimestamp + 1 * speedScale),
//            QuadraticBezier(start: [-0.6803631, -0.14252508], end: [-0.6278378, -0.13724208], control: [-0.6713394, -0.14252508], timestamp: firstTimestamp + 2 * speedScale),
//            QuadraticBezier(start: [-0.6278378, -0.13724208], end: [-0.25760883, -0.1199224], control: [-0.5843361, -0.13195896], timestamp: firstTimestamp + 3 * speedScale),
//            QuadraticBezier(start: [-0.25760883, -0.1199224], end: [0.0788641, -0.10788584], control: [0.0691185, -0.10788584], timestamp: firstTimestamp + 1 * speedScale),
//            QuadraticBezier(start: [0.0788641, -0.10788584], end: [0.1432414, -0.11152661], control: [0.088609695, -0.10788584], timestamp: firstTimestamp + 4 * speedScale),
//            QuadraticBezier(start: [0.1432414, -0.11152661], end: [0.19852078, -0.11516762], control: [0.19787312, -0.11516762], timestamp: firstTimestamp + 5 * speedScale),
//            QuadraticBezier(start: [0.24, 0.3], end: [0.4, 0.4], control: [0.2, 0.6], timestamp: 1_595_985_214_348),
//            PenUp(timestamp: firstTimestamp + 6 * speedScale),
//            PenDown(color: [1.0, 0.0, 0.0, 1.0], lineWidth: DEFAULT_STROKE_THICKNESS, timestamp: 1_595_985_214_351),
//            CubicBezier(start: veryRandomVect(), end: veryRandomVect(), control1: veryRandomVect(), control2: veryRandomVect(), timestamp: 1_595_985_214_390),
//            PenUp(timestamp: 1_595_985_214_395),
        ]

        super.init(coder: aDecoder)
    }

    @objc override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        device = MTLCreateSystemDefaultDevice()

        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame

        let screenScale = UIScreen.main.scale
        metalLayer.drawableSize = CGSize(width: view.frame.width * screenScale, height: view.frame.height * screenScale)
        view.layer.addSublayer(metalLayer)

        let controller = UIHostingController(rootView: Toolbar(delegate: delegate))
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

        textChangePublisher = delegate.didChange.sink { delegate in
            // TODO: this is gross. is there nicer a way to call functions?
            if delegate.clear {
                self.drawOperations.removeAll(keepingCapacity: false)
                self.timestamps.removeAll(keepingCapacity: false)
            }

            if delegate.playing {
                self.startPlaying()
            }

            if !delegate.playing {
                self.stopPlaying()
            }

            if delegate.recording {
                self.startRecording()
            }

            if !delegate.recording {
                self.stopRecording()
            }

            self.mode = delegate.mode
            self.uiRects = delegate.uiRects

            self.selectedColor = delegate.selectedColor.toColorArray()
            self.strokeWidth = delegate.strokeWidth
        }

        guard let defaultLibrary = device.makeDefaultLibrary() else { return }

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "basic_vertex")
        pipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "basic_fragment")
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let vertexDesc = MTLVertexDescriptor()
        vertexDesc.attributes[0].format = MTLVertexFormat.float3
        vertexDesc.attributes[0].offset = 0
        vertexDesc.attributes[0].bufferIndex = 0
        vertexDesc.attributes[1].format = MTLVertexFormat.float4
        vertexDesc.attributes[1].offset = 0
        vertexDesc.attributes[1].bufferIndex = 0
        vertexDesc.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
        vertexDesc.layouts[0].stride = MemoryLayout<Float>.stride * 8

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

    final func veryRandomColor() -> [Float] {
        [Float.r(n: Float.random(in: 0.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
         Float.r(n: Float.random(in: 0.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
         Float.r(n: Float.random(in: 0.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
         0.7]
    }

    final func closeShape(thickness: Float, miterLimit: Float, points: [[Float]], vertexData: inout [Float], color: [Float], colorData: inout [Float]) {
        let triangles = dumpTriangleStrip(thickness: thickness, miterLimit: miterLimit, points: points)
        shapeIndex.append(triangles.count / 3)
        vertexData.append(contentsOf: triangles)
        colorData.append(contentsOf: color)
    }

    public func startPlaying() {
        if playing { return }

        playing = true

        var timestampIterator = timestamps.makeIterator()
        let baselineTime = DispatchTime.now()
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
        recording = true
    }

    public func stopRecording() {
        recording = false
    }

    final func generateVerts() {
        let bezierOptions = BezierTesselationOptions(
            curveAngleToleranceEpsilon: 0.3, mAngleTolerance: 0.02, mCuspLimit: 0.0, miterLimit: 1.0, scale: 100
        )

        var vertexData: [Float] = []
        var colorData: [Float] = []
        shapeIndex.removeAll() // clear this or else render() will loop infinitely

        var points: [[Float]] = []

        var openShape: Bool = false
        var activeColor: [Float] = [0.0, 1.0, 1.0, 1.0]
        var activeLineWidth: Float = DEFAULT_STROKE_THICKNESS

        var translation: [Float] = [0.0, 0.0]

        for op in drawOperations {
            if playing, op.timestamp > playbackEndTimestamp { continue }

            if op.type == "Pan" {
                let panOp = op as! Pan

                let deltaX = panOp.end[0] - panOp.start[0]
                let deltaY = panOp.end[1] - panOp.start[1]

                translation[0] += deltaX
                translation[1] += deltaY
            }

            if op.type == "PenDown" {
                let penDownOp = op as! PenDown
                activeColor = penDownOp.color
                activeLineWidth = penDownOp.lineWidth
                points.removeAll()
                openShape = true
            }
            if op.type == "Line" {
                let lineOp = op as! Line
                points.append(lineOp.start)
                points.append(lineOp.end)
            }
            if op.type == "QuadraticBezier" {
                let bezierOp = op as! QuadraticBezier
                tesselateQuadraticBezier(start: bezierOp.start, control: bezierOp.control, end: bezierOp.end, points: &points, options: bezierOptions)
            }
            if op.type == "CubicBezier" {
                let bezierOp = op as! CubicBezier
                tesselateCubicBezier(start: bezierOp.start, control1: bezierOp.control1, control2: bezierOp.control2, end: bezierOp.end, points: &points, options: bezierOptions)
            }
            if op.type == "PenUp" {
                closeShape(thickness: activeLineWidth, miterLimit: bezierOptions.miterLimit, points: points, vertexData: &vertexData, color: activeColor, colorData: &colorData)
                openShape = false
            }
        }

        if openShape {
            closeShape(thickness: activeLineWidth, miterLimit: bezierOptions.miterLimit, points: points, vertexData: &vertexData, color: activeColor, colorData: &colorData)
            openShape = false
        }

        if drawOperations.count == 0 || vertexData.count == 0 { return }

        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData,
                                         length: dataSize,
                                         options: .storageModeShared)

        colorBuffer = device.makeBuffer(bytes: colorData, length: colorData.count * MemoryLayout.size(ofValue: colorData[0]), options: .storageModeShared)

        let modelViewMatrix: Matrix4x4 = Matrix4x4.translate(x: translation[0], y: translation[1])
        let uniform = Uniforms(modelViewMatrix: modelViewMatrix)
        let uniforms = [uniform]
        uniformBuffer = device.makeBuffer(
            length: MemoryLayout<Uniforms>.size,
            options: []
        )
        memcpy(uniformBuffer.contents(), uniforms, MemoryLayout<Uniforms>.size)

        self.translation = translation
    }

    func addDebugPath(_ rect: CGRect?, _ path: inout UIBezierPath) {
        if rect == nil { return }

//        drawOperations.append(PenDown(color: [0.0, 0.0, 0.0, 1.0], timestamp: 0))
//        drawOperations.append(Line(start: transform(Float(rect!.origin.x), Float(rect!.origin.y)),
//                                   end: transform(Float(rect!.origin.x + rect!.width), Float(rect!.origin.y)),
//                                   timestamp: 0))
//        drawOperations.append(PenUp(timestamp: 0))
//
//        drawOperations.append(PenDown(color: [0.0, 0.0, 0.0, 1.0], timestamp: 0))
//        drawOperations.append(Line(start: transform(Float(rect!.origin.x + rect!.width), Float(rect!.origin.y)),
//                                   end: transform(Float(rect!.origin.x + rect!.width), Float(rect!.origin.y + rect!.height)),
//                                   timestamp: 0))
//        drawOperations.append(PenUp(timestamp: 0))

        path.move(to: CGPoint(x: rect!.origin.x, y: rect!.origin.y))
        path.addLine(to: CGPoint(x: rect!.origin.x + rect!.width, y: rect!.origin.y))
        path.addLine(to: CGPoint(x: rect!.origin.x + rect!.width, y: rect!.origin.y + rect!.height))
        path.addLine(to: CGPoint(x: rect!.origin.x, y: rect!.origin.y + rect!.height))
        path.close()
    }

    final func render() {
//        var path = UIBezierPath()
//
//        for (_, value) in uiRects {
//            addDebugPath(value, &path)
//        }
//
//        let oldRef = debugShapeLayer
//        debugShapeLayer.path = path.cgPath
//        debugShapeLayer.strokeColor = UIColor.blue.cgColor
//        debugShapeLayer.fillColor = UIColor.clear.cgColor
//        debugShapeLayer.lineWidth = 3
//
//        // don't add a sublayer unless we don't have one
//        if view.layer.sublayers!.count == 2 {
//            view.layer.addSublayer(debugShapeLayer)
//        }
//        view.layer.replaceSublayer(oldRef, with: debugShapeLayer)

        guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 255.0 / 255.0, green: 255.0 / 255.0, blue: 255.0 / 255.0, alpha: 1.0)

//        if drawOperations.count != previousDropOpCount {
        generateVerts()
//            previousDropOpCount = drawOperations.count
//        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder.setVertexBuffer(colorBuffer, offset: 0, index: 1)
        renderCommandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 2)

        var currentVertexPosition = 0
        for (index, start) in shapeIndex.enumerated() {
            renderCommandEncoder.setVertexBufferOffset(index * 4 * 4, index: 1) // 4 floats per index, 4 bytes per float
            renderCommandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: currentVertexPosition, vertexCount: start)
            currentVertexPosition += start
        }

        renderCommandEncoder.endEncoding()
        commandBuffer.present(drawable)
        // NB: you can pass in a time to present the finished image:
        // present(drawable: drawable, atTime presentationTime: CFTimeInterval)
        commandBuffer.commit()
    }

    final func transform(_ x: Float, _ y: Float) -> [Float] {
        let frameWidth: Float = Float(view.frame.size.width)
        let frameHeight: Float = Float(view.frame.size.height)

        return [
            (2.0 * x / frameWidth) - 1.0,
            (2.0 * -y / frameHeight) + 1.0,
        ]
    }

    func checkTouch(_ touch: UITouch) -> Bool {
        let x = touch.location(in: view).x
        let y = touch.location(in: view).y

        for (key, value) in uiRects {
            if x > value.minX, x < value.maxX, y > value.minY, y < value.maxY {
//                print("found hit in \(key)")
                return true
            }
        }
        return false
    }

    override open func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard isDrawingEnabled, let touch = touches.first else { return }
        if checkTouch(touch) { return }

        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }

        setTouchPoints(for: touch, view: view)
        firstPoint = touch.location(in: view)

        let timestamp = getCurrentTimestamp()
        timestamps.append(timestamp)
        drawOperations.append(PenDown(color: selectedColor,
                                      lineWidth: strokeWidth,
                                      timestamp: timestamp))
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard isDrawingEnabled, let touch = touches.first else { return }
        if checkTouch(touch) { return }

        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }

        updateTouchPoints(for: touch, in: view)
        let timestamp = getCurrentTimestamp()
        timestamps.append(timestamp)

//        if shouldDrawStraight {
//        } else {

        if mode == "draw" {
            let midPoints = getMidPoints()
            var start = transform(Float(midPoints.0.x), Float(midPoints.0.y))
            var control = transform(Float(previousPoint.x), Float(previousPoint.y))
            var end = transform(Float(midPoints.1.x), Float(midPoints.1.y))

//            print("before translation:", start, control, end)
//            print("translation:", translation)

            start[0] -= translation[0]
            start[1] -= translation[1]

            control[0] -= translation[0]
            control[1] -= translation[1]

            end[0] -= translation[0]
            end[1] -= translation[1]

//            print("after translation:", start, control, end)

            if start[0] == control[0], start[1] == control[1] {
                return
            }

            let params = QuadraticBezier(start: start, end: end, control: control, timestamp: timestamp)
            drawOperations.append(params)
        } else if mode == "pan" {
            let midPoints = getMidPoints()
            let start = transform(Float(midPoints.0.x), Float(midPoints.0.y))
            let end = transform(Float(midPoints.1.x), Float(midPoints.1.y))
            drawOperations.append(Pan(start: start, end: end, timestamp: timestamp))
        } else {
            print("invalid mode: \(mode)")
        }
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard isDrawingEnabled, let touch = touches.first else { return }
        if checkTouch(touch) { return }

        let timestamp = getCurrentTimestamp()
        timestamps.append(timestamp)
        drawOperations.append(PenUp(timestamp: timestamp))
    }

    override open func touchesCancelled(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard isDrawingEnabled, let touch = touches.first else { return }
        if checkTouch(touch) { return }
    }

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
