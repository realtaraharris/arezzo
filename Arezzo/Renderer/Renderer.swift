//
//  Renderer.swift
//  Arezzo
//
//  Created by Max Harris on 4/22/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import Metal
import QuartzCore
import simd

struct PortalRect {
    var rect: CGRect
    var name: String
}

class Renderer {
    var device: MTLDevice = MTLCreateSystemDefaultDevice()!
    var metalLayer: CAMetalLayer = CAMetalLayer()
    var segmentVertexBuffer: MTLBuffer!
    var segmentIndexBuffer: MTLBuffer!
    var capVertexBuffer: MTLBuffer!
    var capIndexBuffer: MTLBuffer!
    var commandQueue: MTLCommandQueue!
    var segmentRenderPipelineState: MTLRenderPipelineState!
    var capRenderPipelineState: MTLRenderPipelineState!
    var pipelineState: MTLRenderPipelineState!
    var width: Float = 0.0
    var height: Float = 0.0
    let capEdges = 21
    var portalRects: [PortalRect] = []

    init(frame: CGRect, scale: CGFloat) {
        self.metalLayer.device = self.device
        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.framebufferOnly = false
        self.metalLayer.frame = frame
        self.metalLayer.drawableSize = CGSize(width: frame.width * scale, height: frame.height * scale)

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

        guard let defaultLibrary = device.makeDefaultLibrary() else { return }

        let segmentPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        segmentPipelineStateDescriptor.label = "Line Segment Pipline"
        segmentPipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "line_segment_vertex")
        segmentPipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "line_fragment")
        segmentPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let capPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        capPipelineStateDescriptor.label = "Line Cap Pipline"
        capPipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "line_cap_vertex")
        capPipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "line_fragment")
        capPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let portalPiplineDescriptor = MTLRenderPipelineDescriptor()
        portalPiplineDescriptor.label = "Portal Pipline"
        portalPiplineDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "portal_vertex")
        portalPiplineDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "portal_fragment")
        portalPiplineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

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
            try self.pipelineState = self.device.makeRenderPipelineState(descriptor: portalPiplineDescriptor)
        } catch {
            print("Failed to create pipeline state, error \(error)")
        }

        self.commandQueue = self.device.makeCommandQueue() // this is expensive to create, so we save a reference to it

        self.width = Float(frame.width)
        self.height = Float(frame.height)
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

    func render(shapeList: [Shape], endTimestamp: Double, texture: MTLTexture) -> MTLCommandBuffer? {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0 / 255.0, green: 0.0 / 255.0, blue: 0.0 / 255.0, alpha: 1.0)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
        if let error = commandBuffer.error as NSError? {
            if #available(macCatalyst 14.0, *) {
                if let infos = error.userInfo[MTLCommandBufferEncoderInfoErrorKey]
                    as? [MTLCommandBufferEncoderInfo] {
                    for info in infos {
                        print(info.label + info.debugSignposts.joined())
                        if info.errorState == .faulted {
                            print(info.label + " faulted!")
                        }
                    }
                }
            } else {
                print("error:", error)
            }
        }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return nil }

        self.portalRects = []
        var translation: [Float] = [0.0, 0.0]

        // sum up the translation vect from the shapeList
        for shape in shapeList {
            if shape.type == DrawOperationType.pan {
                if shape.geometry.count == 0 { continue }
                let startX = shape.geometry[0]
                let startY = shape.geometry[1]
                let end = shape.getIndex(timestamp: endTimestamp)
                if end >= 2 {
                    translation[0] += Float(shape.geometry[end - 2] - startX)
                    translation[1] += Float(shape.geometry[end - 1] - startY)
                }
            }
        }
        renderCommandEncoder.setVertexBuffer(self.uniformTranslation(translation), offset: 0, index: 2)

        for shape in shapeList {
            // each time we encounter a translation, we subtract that from the final one calculated above
            if shape.type == DrawOperationType.pan {
                if shape.geometry.count == 0 { continue }
                let startX = shape.geometry[0]
                let startY = shape.geometry[1]
                let end = shape.getIndex(timestamp: endTimestamp)
                if end >= 2 {
                    translation[0] -= Float(shape.geometry[end - 2] - startX)
                    translation[1] -= Float(shape.geometry[end - 1] - startY)
                }

                renderCommandEncoder.setVertexBuffer(self.uniformTranslation(translation), offset: 0, index: 2)
                continue
            }

            if shape.timestamp.count == 0 { continue }
            // if shape.notInWindow() { continue }

            let start = 0
            let end = shape.getIndex(timestamp: endTimestamp)

            if start > end || start == end { continue }

            if shape.type == DrawOperationType.line {
                self.drawLines(points: shape.geometry, instanceCount: (end - start) / 2, shape: shape, renderCommandEncoder: renderCommandEncoder)
            } else if shape.type == DrawOperationType.portal {
                guard let rect = shape.getBoundingRect(endTimestamp: endTimestamp) else { continue }
                let x = rect[0], y = rect[1], width = rect[2], height = rect[3]

                self.portalRects.append(
                    PortalRect(
                        rect: CGRect(x: CGFloat(x + translation[0]), y: CGFloat(y + translation[1]), width: CGFloat(width), height: CGFloat(height)),
                        name: shape.name
                    )
                )

                let vertices: [PortalPreviewVertex] = [
                    PortalPreviewVertex(position: vector_float2(x: x + width, y: y), textureCoordinate: vector_float2(x: 1.0, y: 0.0)),
                    PortalPreviewVertex(position: vector_float2(x: x, y: y), textureCoordinate: vector_float2(x: 0.0, y: 0.0)),
                    PortalPreviewVertex(position: vector_float2(x: x, y: y + height), textureCoordinate: vector_float2(x: 0.0, y: 1.0)),

                    PortalPreviewVertex(position: vector_float2(x: x + width, y: y), textureCoordinate: vector_float2(x: 1.0, y: 0.0)),
                    PortalPreviewVertex(position: vector_float2(x: x, y: y + height), textureCoordinate: vector_float2(x: 0.0, y: 1.0)),
                    PortalPreviewVertex(position: vector_float2(x: x + width, y: y + height), textureCoordinate: vector_float2(x: 1.0, y: 1.0)),
                ]

                let vertexBuffer = self.device.makeBuffer(bytes: vertices, length: MemoryLayout<PortalPreviewVertex>.stride * vertices.count, options: .storageModeShared)!

                renderCommandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                renderCommandEncoder.setRenderPipelineState(self.pipelineState)

                renderCommandEncoder.setFragmentTexture(shape.texture, index: 0)
                renderCommandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)

                let points: [Float] = [
                    x, y,
                    x, y + height,
                    x + width, y + height,
                    x + width, y,
                    x, y,
                ]

                self.drawLines(points: points, instanceCount: 4, shape: shape, renderCommandEncoder: renderCommandEncoder)
            }
        }

        renderCommandEncoder.endEncoding()

        return commandBuffer
    }

    func drawLines(points: [Float], instanceCount: Int, shape: Shape, renderCommandEncoder: MTLRenderCommandEncoder) {
        let geometryBuffer = self.device.makeBuffer(
            bytes: points,
            length: points.count * 4,
            options: .storageModeShared
        )
        let colorBuffer = self.device.makeBuffer(
            bytes: shape.color,
            length: shape.color.count * 4,
            options: .storageModeShared
        )
        let lineWidthBuffer = self.device.makeBuffer(
            bytes: [shape.lineWidth],
            length: 4,
            options: .storageModeShared
        )

        renderCommandEncoder.setVertexBuffer(lineWidthBuffer!, offset: 0, index: 4)
        renderCommandEncoder.setVertexBuffer(geometryBuffer!, offset: 0, index: 3)
        renderCommandEncoder.setVertexBuffer(colorBuffer!, offset: 0, index: 1)

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

    func renderToBitmap(shapeList: [Shape], firstTimestamp _: Double, endTimestamp: Double, size: CGSize) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = Int(size.width)
        textureDescriptor.height = Int(size.height)
        textureDescriptor.arrayLength = 1
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .shared
        let texture: MTLTexture = self.device.makeTexture(descriptor: textureDescriptor)!

        let commandBuffer: MTLCommandBuffer = self.render(shapeList: shapeList, endTimestamp: endTimestamp, texture: texture)!

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return texture
    }

    func renderToVideo(shapeList: [Shape], firstTimestamp: Double, endTimestamp: Double, videoRecorder: MetalVideoRecorder) {
        let texture: MTLTexture = self.renderToBitmap(shapeList: shapeList, firstTimestamp: firstTimestamp, endTimestamp: endTimestamp, size: CGSize(width: CGFloat(self.width), height: CGFloat(self.height))) // TODO: pass in the desired size
        videoRecorder.writeFrame(forTexture: texture, timestamp: endTimestamp)
    }

    func renderToScreen(shapeList: [Shape], endTimestamp: Double) {
        guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else { return }

        let commandBuffer: MTLCommandBuffer = self.render(shapeList: shapeList, endTimestamp: endTimestamp, texture: drawable.texture)!

        commandBuffer.present(drawable)
        commandBuffer.commit()

        // let captureManager = MTLCaptureManager.shared()
        // captureManager.stopCapture()
    }

    func uniformTranslation(_ translation: [Float]) -> MTLBuffer {
        let frameWidth: Float = Float(self.width)
        let frameHeight: Float = Float(self.height)
        let modelViewMatrix: Matrix4x4 = Matrix4x4.translate(
            x: (2.0 * translation[0] / frameWidth) + 1.0,
            y: (-2.0 * translation[1] / frameHeight) - 1.0
        )
        let uniform = Uniforms(width: Float(self.width), height: Float(self.height), modelViewMatrix: modelViewMatrix)
        let uniformBuffer: MTLBuffer = self.device.makeBuffer(
            length: MemoryLayout<Uniforms>.size,
            options: []
        )!
        memcpy(uniformBuffer.contents(), [uniform], MemoryLayout<Uniforms>.size)

        return uniformBuffer
    }
}
