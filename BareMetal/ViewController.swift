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

public extension Float {
    static func r(n: Float, tol: Float) -> Float {
        let low = n - tol
        let high = n + tol
        return tol == 0 || low > high ? n : Float.random(in: low ..< high)
    }
}

class ViewController: UIViewController {
    var device: MTLDevice!
    var metalLayer: CAMetalLayer
    var vertexBuffer: MTLBuffer!
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
        pipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "basic_vertex")
        pipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "basic_fragment")
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

    func generateVerts () {
        let tol: Float = Float.random(in: -0.1 ..< 0.1)

        let vertexData: [Float] = [
            Float.r(n: 0.0, tol: tol),
            Float.r(n: 0.5, tol: tol),
            Float.r(n: 0.0, tol: 0),

            Float.r(n: -0.5, tol: tol),
            Float.r(n: -0.5, tol: tol),
            Float.r(n: 0.0, tol: 0),

            Float.r(n: 0.5, tol: tol),
            Float.r(n: -0.5, tol: tol),
            Float.r(n: 0.0, tol: 0),

            Float.r(n: -0.9, tol: tol),
            Float.r(n: 0.1, tol: tol),
            Float.r(n: 0.0, tol: 0),

            Float.r(n: -0.1, tol: tol),
            Float.r(n: -0.1, tol: tol),
            Float.r(n:  0.0, tol: 0),

            Float.r(n: -1.0, tol: tol),
            Float.r(n: -1.0, tol: tol),
            Float.r(n: 0.0, tol: 0)
        ]

        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData,
                                         length: dataSize,
                                         options: .storageModeShared)

        vertexCount = vertexData.count
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
        renderCommandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
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
