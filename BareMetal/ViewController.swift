//
//  ViewController.swift
//  BareMetal
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Metal
import QuartzCore
import UIKit
import simd // vector_float2, vector_float4

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
    var quadraticBezierBuffer: MTLBuffer!
    var cubicBezierBuffer: MTLBuffer!
    var vertexColorBuffer: MTLBuffer!
    var commandQueue: MTLCommandQueue!
    var renderPipelineState: MTLRenderPipelineState!
    var timer: CADisplayLink!

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
//        pipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "bezier_vertex_quadratic")
//        pipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "bezier_fragment")
        pipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "basic_vertex")
        pipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "cubic_basic_fragment")
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            try renderPipelineState = device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch {
            print("Failed to create pipeline state, error \(error)")
        }

        commandQueue = device.makeCommandQueue() // this is expensive to create, so we save a reference to it

        timer = CADisplayLink(target: self, selector: #selector(ViewController.gameloop))
        timer.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
    }

        func generateVerts2 () {
    //        let bezierData = [CubicBezierParameters(
    //            start: vector_float2(0.0, 0.0),
    //            end: vector_float2(1.0, 0.0),
    //            control1: vector_float2(0.25, 1.0),
    //            control2: vector_float2(0.75, 1.0),
    //            itemColor: vector_float4(x: Float(arc4random_uniform(1000)) / 1000.0,
    //                                     y: Float(arc4random_uniform(1000)) / 1000.0,
    //                                     z: Float(arc4random_uniform(1000)) / 1000.0,
    //                                     w: 1.0),
    //            ts: Date().toMilliseconds()
    //        )]

            let bezierData = [QuadraticBezierParameters(
                start: vector_float2(0.0, 0.0),
                end: vector_float2(1.0, 0.0),
                control: vector_float2(0.5, 1.0),
                itemColor: vector_float4(x: Float(arc4random_uniform(1000)) / 1000.0,
                                         y: Float(arc4random_uniform(1000)) / 1000.0,
                                         z: Float(arc4random_uniform(1000)) / 1000.0,
                                         w: 1.0),
                ts: Date().toMilliseconds()
            )]
            
            let quad = [
                0, 0, 0,
                1, 0, 0,
                0.5, 1.0, 0
//          -1, -1, 0, // lower-left
//                -1, 1, 0, // upper-left
//                1, 1, 0, // upper-right
//                1, -1, 0 // lower-right
            ]

            let dataSize = quad.count * MemoryLayout.size(ofValue: quad[0])
    //        let dataSize = bezierData.count * MemoryLayout.size(ofValue: bezierData[0])
    //        vertexBuffer = device.makeBuffer(bytes: bezierData,
    //                                         length: dataSize,
    //                                         options: .storageModeShared)

            vertexBuffer = device.makeBuffer(bytes: quad,
                                             length: dataSize,
                                             options: .storageModeShared)
            
    //        vertexBuffer = device.makeBuffer(
    //            bytes: bezierData,
    //            length: bezierData.count * MemoryLayout<CubicBezierParameters>.size,
    //            options: .storageModeShared)
            
            vertexBuffer.label = "cubic beziers"

            vertexCount = quad.count // bezierData.count
        }
    
    func generateVerts () {
//        let tol: Float = Float.random(in: -0.1 ..< 0.1)

        let vertexData: [Float] = [
//            0.0, 0.0, 0.0, // start
//            0.7, 0.9, 0.0, // control1
//            0.0, 0.9, 0.0, // control2
//            1.0, 0.4, 0.0, // end
//            0.0, 0.0, 0.0

            0.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            1.0, 1.0, 0.0,
            0.0, 1.0, 0.0,
            0.0, 0.0, 0.0
        ]
        
        let cubicBezierData = [CubicBezierParameters(
            start: vector_float2(0.0, 0.0),
            end: vector_float2(1.0, 0.4),
            control1: vector_float2(0.7, 1.0),
            control2: vector_float2(0.2, 1.0),
            itemColor: vector_float4(x: Float(arc4random_uniform(1000)) / 1000.0,
                                     y: Float(arc4random_uniform(1000)) / 1000.0,
                                     z: Float(arc4random_uniform(1000)) / 1000.0,
                                     w: 1.0),
            ts: Date().toMilliseconds()
        )]
        
        let quadraticBezierData = [QuadraticBezierParameters(
            start: vector_float2(0.0, 0.0),
            end: vector_float2(1.0, 0.0),
            control: vector_float2(0.5, 0.75),
            itemColor: vector_float4(x: Float(arc4random_uniform(1000)) / 1000.0,
                                     y: Float(arc4random_uniform(1000)) / 1000.0,
                                     z: Float(arc4random_uniform(1000)) / 1000.0,
                                     w: 1.0),
            ts: Date().toMilliseconds()
        )]
        
        cubicBezierBuffer = device.makeBuffer(
        bytes: cubicBezierData,
        length: cubicBezierData.count * MemoryLayout<CubicBezierParameters>.size,
        options: .storageModeShared)

        quadraticBezierBuffer = device.makeBuffer(
            bytes: quadraticBezierData,
            length: quadraticBezierData.count * MemoryLayout<QuadraticBezierParameters>.size,
            options: .storageModeShared)

        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData,
                                         length: dataSize,
                                         options: .storageModeShared)

        vertexCount = vertexData.count/3
    }

    func render() {
        guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 255.0 / 255.0, green: 16.0 / 255.0, blue: 22.0 / 255.0, alpha: 1.0)

        generateVerts()

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder.setFragmentBuffer(cubicBezierBuffer, offset: 0, index: 0)
//        renderCommandEncoder.setFragmentBuffer()
        renderCommandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertexCount)
        renderCommandEncoder.endEncoding()
        commandBuffer.present(drawable)
        // NB: you can pass in a time to present the finished image:
        // present(drawable: drawable, atTime presentationTime: CFTimeInterval)
        commandBuffer.commit()
    }

    @objc func gameloop() {
        autoreleasepool {
            self.render()
        }
    }
}
