//
//  ViewController.swift
//  BareMetal
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Metal
import QuartzCore
import simd // vector_float2, vector_float4
import UIKit

struct CubicBezierParameters {
    static let coordinateRange: Float = 1.0

    var a: vector_float2 = vector_float2()
    var b: vector_float2 = vector_float2()
    var p1: vector_float2 = vector_float2()
    var p2: vector_float2 = vector_float2()

    var lineWidth: Float = 0.050

    var color: vector_float4 = vector_float4()
    var timestamp: Int64 = 0
    var elementsPerInstance: Int = 128

    init(start: vector_float2, end: vector_float2, control1: vector_float2, control2: vector_float2, itemColor: vector_float4, ts: Int64) {
        a = start
        b = end
        p1 = control1
        p2 = control2
        color = itemColor
        timestamp = ts
    }
}

struct QuadraticBezierParameters {
    static let coordinateRange: Float = 1.0

    var a: vector_float2 = vector_float2()
    var b: vector_float2 = vector_float2()
    var p: vector_float2 = vector_float2()

    var lineWidth: Float = 0.050

    var color: vector_float4 = vector_float4()
    var timestamp: Int64 = 0

    var elementsPerInstance: Int = 128

    init(start: vector_float2, end: vector_float2, control: vector_float2, itemColor: vector_float4, ts: Int64) {
        a = start
        b = end
        p = control
        color = itemColor
        timestamp = ts
    }
}

public extension Float {
    static func r(n: Float, tol: Float) -> Float {
        let low = n - tol
        let high = n + tol
        return tol == 0 || low > high ? n : Float.random(in: low ..< high)
    }
}

extension Date {
    func toMilliseconds() -> Int64 {
        Int64(timeIntervalSince1970 * 1000)
    }
}

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
    var renderCount: Int = 0

    var vertexCount: Int = 0

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
        view.layer.addSublayer(metalLayer)

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

    func veryRandomColor() -> [Float] {
        [Float.r(n: Float.random(in: 0.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
         Float.r(n: Float.random(in: 0.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
         Float.r(n: Float.random(in: 0.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
         0.7]
    }

    func addCubicBezier(
        start: [Float], c1: [Float], c2: [Float], end: [Float], options: BezierTesselationOptions, colorData: inout [Float], vertexData: inout [Float]
    ) {
        let cubicBezier = CubicBezierTesselator(start: start, c1: c1, c2: c2, end: end, existingPoints: [], options: options)
        let cubicBezierTriangles = cubicBezier.dumpTriangleStrip()

        shapeIndex.append(cubicBezierTriangles.count / 3)
        vertexData.append(contentsOf: cubicBezierTriangles)
        colorData.append(contentsOf: veryRandomColor())
    }

    func addQuadraticBezier(
        start: [Float], c: [Float], end: [Float], options: BezierTesselationOptions, colorData: inout [Float], vertexData: inout [Float]
    ) {
        let quadraticBezier = QuadraticBezierTesselator(start: start, c: c, end: end, options: options)
        let quadraticBezierTriangles = quadraticBezier.dumpTriangleStrip()

        shapeIndex.append(quadraticBezierTriangles.count / 3)
        vertexData.append(contentsOf: quadraticBezierTriangles)
        colorData.append(contentsOf: veryRandomColor())
    }

    func generateVerts() {
        let bezierOptions = BezierTesselationOptions(
            curveAngleToleranceEpsilon: 0.3, mAngleTolerance: 0.2, mCuspLimit: 0.0, thickness: 0.05, miterLimit: 1.0, scale: 300
        )

        var vertexData: [Float] = []
        var colorData: [Float] = []
        shapeIndex.removeAll() // clear this or else render() will loop infinitely
        colorData.removeAll()

        func veryRandomVect() -> [Float] { [Float.r(n: Float.random(in: -1.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
                                            Float.r(n: Float.random(in: -1.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0))] }
        for _ in 0 ... 4 {
        addCubicBezier(start: veryRandomVect(), c1: veryRandomVect(), c2: veryRandomVect(), end: veryRandomVect(), options: bezierOptions, colorData: &colorData, vertexData: &vertexData)
        addQuadraticBezier(start: veryRandomVect(), c: veryRandomVect(), end: veryRandomVect(), options: bezierOptions, colorData: &colorData, vertexData: &vertexData)
        }


        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData,
                                         length: dataSize,
                                         options: .storageModeShared)

        colorBuffer = device.makeBuffer(bytes: colorData, length: colorData.count * MemoryLayout.size(ofValue: colorData[0]), options: .storageModeShared)
    }

    func render() {
        guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 255.0 / 255.0, green: 255.0 / 255.0, blue: 255.0 / 255.0, alpha: 1.0)

//        if renderCount.isMultiple(of: 12) {
//            generateVerts()
//        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        var currentVertexPosition = 0
        for (index, start) in shapeIndex.enumerated() {
            renderCommandEncoder.setVertexBuffer(colorBuffer, offset: index * 4, index: 1)

            renderCommandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: currentVertexPosition, vertexCount: start)
            currentVertexPosition += start
        }

        renderCommandEncoder.endEncoding()
        commandBuffer.present(drawable)
        // NB: you can pass in a time to present the finished image:
        // present(drawable: drawable, atTime presentationTime: CFTimeInterval)
        commandBuffer.commit()
        renderCount += 1
    }

    @objc func gameloop() {
        autoreleasepool {
            self.render()
        }
    }
}
