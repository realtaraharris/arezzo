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

protocol DrawOperation {
    var type: String { get }
}

struct CubicBezierParameters: DrawOperation {
    var type: String
    var start: [Float]
    var end: [Float]
    var control1: [Float]
    var control2: [Float]
    var lineWidth: Float = 0.050
    var timestamp: Int64 = 0

    init(start: [Float], end: [Float], control1: [Float], control2: [Float], timestamp: Int64) {
        type = "CubicBezier"
        self.start = start
        self.end = end
        self.control1 = control1
        self.control2 = control2
        self.timestamp = timestamp
    }
}

struct QuadraticBezierParameters: DrawOperation {
    var type: String
    var start: [Float]
    var end: [Float]
    var control: [Float]
    var lineWidth: Float = 0.050
    var timestamp: Int64 = 0

    init(start: [Float], end: [Float], control: [Float], timestamp: Int64) {
        type = "QuadraticBezier"
        self.start = start
        self.end = end
        self.control = control
        self.timestamp = timestamp
    }
}

struct PenDown: DrawOperation {
    var type: String
    var color: [Float]
    init(color: [Float]) {
        type = "PenDown"
        self.color = color
    }
}

struct PenUp: DrawOperation {
    var type: String
    init() {
        type = "PenUp"
    }
}

public extension Float {
    static func r(n: Float, tol: Float) -> Float {
        let low = n - tol
        let high = n + tol
        return tol == 0 || low > high ? n : Float.random(in: low ..< high)
    }
}

class ContentViewDelegate: ObservableObject {
    var didChange = PassthroughSubject<ContentViewDelegate, Never>()
    var objectWillChange = PassthroughSubject<ContentViewDelegate, Never>()

    var name: String = "" {
        didSet {
            self.didChange.send(self)
        }

        willSet {
            self.objectWillChange.send(self)
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

    var selectedColor: Color = .red {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }
}

// struct ContentViewEx: View {
//    @ObservedObject var delegate: ContentViewDelegate
//
//    init(delegate: ContentViewDelegate) {
//        self.delegate = delegate
//    }
//
//    var body: some View {
//        VStack {
//            Text(self.delegate.name).padding().background(Color.gray)
//            TextField("Enter name", text: self.$delegate.name)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//        }.padding().background(Color.green)
//    }
// }

class ViewController: UIViewController {
    var device: MTLDevice!
    var metalLayer: CAMetalLayer
    var vertexBuffer: MTLBuffer!
    var colorBuffer: MTLBuffer!
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

    private var delegate = ContentViewDelegate()
    private var contentView: ContentView!
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
    private var timestamps = NSMutableOrderedSet()
    private var lastTimestampDrawn: Int64 = 0

    private var drawOperations: [DrawOperation] = [
        PenDown(color: [1.0, 1.0, 0.0, 1.0]),
        QuadraticBezierParameters(start: [-0.68938684, -0.14252508], end: [-0.6803631, -0.14252508], control: [-0.68938684, -0.14252508], timestamp: 1_595_985_214_141),
        QuadraticBezierParameters(start: [-0.6803631, -0.14252508], end: [-0.6278378, -0.13724208], control: [-0.6713394, -0.14252508], timestamp: 1_595_985_214_158),
        QuadraticBezierParameters(start: [-0.6278378, -0.13724208], end: [-0.25760883, -0.1199224], control: [-0.5843361, -0.13195896], timestamp: 1_595_985_214_240),
        QuadraticBezierParameters(start: [-0.25760883, -0.1199224], end: [0.0788641, -0.10788584], control: [0.0691185, -0.10788584], timestamp: 1_595_985_214_265),
        QuadraticBezierParameters(start: [0.0788641, -0.10788584], end: [0.1432414, -0.11152661], control: [0.088609695, -0.10788584], timestamp: 1_595_985_214_323),
        QuadraticBezierParameters(start: [0.1432414, -0.11152661], end: [0.19852078, -0.11516762], control: [0.19787312, -0.11516762], timestamp: 1_595_985_214_348),
        QuadraticBezierParameters(start: [0.24, 0.3], end: [0.4, 0.4], control: [0.2, 0.6], timestamp: 1_595_985_214_348),
        PenUp(),
        PenDown(color: [1.0, 0.0, 0.0, 1.0]),
        CubicBezierParameters(start: veryRandomVect(), end: veryRandomVect(), control1: veryRandomVect(), control2: veryRandomVect(), timestamp: 1_595_985_214_348),
        PenUp(),
    ]

    // For pencil interactions
    @available(iOS 12.1, *)
    private lazy var pencilInteraction = UIPencilInteraction()

    required init?(coder aDecoder: NSCoder) {
        metalLayer = CAMetalLayer()

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

        contentView = ContentView(delegate: delegate)
        let controller = UIHostingController(rootView: contentView)
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
                self.drawOperations.removeAll()
            }

            self.selectedColor = delegate.selectedColor.toColorArray()
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

        generateVerts()

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

    final func generateVerts() {
        let bezierOptions = BezierTesselationOptions(
            curveAngleToleranceEpsilon: 0.3, mAngleTolerance: 0.02, mCuspLimit: 0.0, thickness: 0.01, miterLimit: 1.0, scale: 100
        )

        var vertexData: [Float] = []
        var colorData: [Float] = []
        shapeIndex.removeAll() // clear this or else render() will loop infinitely

        var points: [[Float]] = []

        var openShape: Bool = false
        var activeColor: [Float] = [0.0, 1.0, 1.0, 1.0]
        for op in drawOperations {
            if op.type == "PenDown" {
                let penDownOp = op as! PenDown
                activeColor = penDownOp.color
                points.removeAll()
                openShape = true
            }
            if op.type == "QuadraticBezier" {
                let bezierOp = op as! QuadraticBezierParameters
                tesselateQuadraticBezier(start: bezierOp.start, control: bezierOp.control, end: bezierOp.end, points: &points, options: bezierOptions)
            }
            if op.type == "CubicBezier" {
                let bezierOp = op as! CubicBezierParameters
                tesselateCubicBezier(start: bezierOp.start, control1: bezierOp.control1, control2: bezierOp.control2, end: bezierOp.end, points: &points, options: bezierOptions)
            }
            if op.type == "PenUp" {
                closeShape(thickness: bezierOptions.thickness, miterLimit: bezierOptions.miterLimit, points: points, vertexData: &vertexData, color: activeColor, colorData: &colorData)
                openShape = false
            }
        }

        if openShape {
            closeShape(thickness: bezierOptions.thickness, miterLimit: bezierOptions.miterLimit, points: points, vertexData: &vertexData, color: activeColor, colorData: &colorData)
            openShape = false
        }

        if drawOperations.count == 0 || vertexData.count == 0 { return }

        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData,
                                         length: dataSize,
                                         options: .storageModeShared)

        colorBuffer = device.makeBuffer(bytes: colorData, length: colorData.count * MemoryLayout.size(ofValue: colorData[0]), options: .storageModeShared)
    }

    final func render() {
        guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 255.0 / 255.0, green: 255.0 / 255.0, blue: 255.0 / 255.0, alpha: 1.0)

        if drawOperations.count != previousDropOpCount {
            generateVerts()
            previousDropOpCount = drawOperations.count
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder.setVertexBuffer(colorBuffer, offset: 0, index: 1)

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

    override open func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard isDrawingEnabled, let touch = touches.first else { return }
        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }

        setTouchPoints(for: touch, view: view)
        firstPoint = touch.location(in: view)
        let timestamp = getCurrentTimestamp()
        timestamps.add(timestamp)

        drawOperations.append(PenDown(color: self.selectedColor)) // veryRandomColor()))
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard isDrawingEnabled, let touch = touches.first else { return }
        if #available(iOS 9.1, *) {
            guard allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }
        }

        let timestamp = getCurrentTimestamp()

        updateTouchPoints(for: touch, in: view)

        if shouldDrawStraight {
        } else {
            let midPoints = getMidPoints()
            let start = transform(Float(midPoints.0.x), Float(midPoints.0.y))
            let control = transform(Float(previousPoint.x), Float(previousPoint.y))
            let end = transform(Float(midPoints.1.x), Float(midPoints.1.y))

            if start[0] == control[0], start[1] == control[1] {
                return
            }

            let params = QuadraticBezierParameters(start: start, end: end, control: control, timestamp: timestamp)
            drawOperations.append(params)
        }
    }

    override open func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
        drawOperations.append(PenUp())
    }

    override open func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {}

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
        let mid1: CGPoint = calculateMidPoint(previousPoint, p2: previousPreviousPoint)
        let mid2: CGPoint = calculateMidPoint(currentPoint, p2: previousPoint)
        return (mid1, mid2)
    }

    @objc func gameloop() {
        autoreleasepool {
            self.render()
        }
    }
}
