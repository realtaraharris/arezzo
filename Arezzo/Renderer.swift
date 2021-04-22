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

extension ViewController {
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

    final func generateVerts(endTimestamp: Double) {
        self.renderedShapes.removeAll(keepingCapacity: false)

        var translation: CGPoint = .zero

        for shape in self.drawOperationCollector.shapeList {
            if shape.type == DrawOperationType.pan {
                if shape.geometry.count == 0 { continue }
                let startX = shape.geometry[0]
                let startY = shape.geometry[1]
                let end = shape.getIndex(timestamp: endTimestamp)
                if end >= 2 {
                    translation.x += CGFloat(shape.geometry[end - 2] - startX)
                    translation.y += CGFloat(shape.geometry[end - 1] - startY)
                }

                continue
            }

            if shape.timestamp.count == 0 || shape.geometryBuffer == nil { continue }
            // if shape.notInWindow() { continue }

            let start = 0
            let end = shape.getIndex(timestamp: endTimestamp)

            if start > end || start == end { continue }

            if shape.type == DrawOperationType.line {
                let input = shape.geometry
                var output: [Float] = []
                for i in stride(from: 0, to: input.count - 1, by: 2) {
                    output.append(contentsOf: [input[i] - Float(translation.x), input[i + 1] - Float(translation.y)])
                }

                let geometryBuffer = self.device.makeBuffer(
                    bytes: output,
                    length: output.count * 4,
                    options: .cpuCacheModeWriteCombined
                )

                self.renderedShapes.append(RenderedShape(
                    startIndex: start,
                    endIndex: end,
                    geometryBuffer: geometryBuffer!,
                    colorBuffer: shape.colorBuffer,
                    widthBuffer: shape.widthBuffer
                ))
            } else if shape.type == DrawOperationType.portal {
                let input = shape.geometry

                let startX = input[start + 0], startY = input[start + 1], endX = input[end - 2], endY = input[end - 1]
                let width = endX - startX
                let height = endY - startY

                let output: [Float] = [
                    startX - Float(translation.x), startY - Float(translation.y),
                    startX - Float(translation.x), startY + height - Float(translation.y),
                    endX - Float(translation.x), endY - Float(translation.y),
                    startX + width - Float(translation.x), startY - Float(translation.y),
                    startX - Float(translation.x), startY - Float(translation.y),
                ]

                let geometryBuffer = self.device.makeBuffer(
                    bytes: output,
                    length: output.count * 4,
                    options: .cpuCacheModeWriteCombined
                )

                self.renderedShapes.append(RenderedShape(
                    startIndex: start,
                    endIndex: 8,
                    geometryBuffer: geometryBuffer!,
                    colorBuffer: shape.colorBuffer,
                    widthBuffer: shape.widthBuffer
                ))
            }
        }

        let tr = self.transform(translation)
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

    final func renderOffline(firstTimestamp _: Double, endTimestamp: Double, videoRecorder: MetalVideoRecorder) {
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
        if let error = commandBuffer.error as NSError? {
            if let infos = error.userInfo[MTLCommandBufferEncoderInfoErrorKey]
                as? [MTLCommandBufferEncoderInfo] {
                for info in infos {
                    print(info.label + info.debugSignposts.joined())
                    if info.errorState == .faulted {
                        print(info.label + " faulted!")
                    }
                }
            }
        }
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

        videoRecorder.writeFrame(forTexture: texture, timestamp: endTimestamp)
    }

    final func render(endTimestamp: Double) {
        guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0 / 255.0, green: 0.0 / 255.0, blue: 0.0 / 255.0, alpha: 1.0)

        self.generateVerts(endTimestamp: endTimestamp)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        if let error = commandBuffer.error as NSError? {
            if let infos = error.userInfo[MTLCommandBufferEncoderInfoErrorKey]
                as? [MTLCommandBufferEncoderInfo] {
                for info in infos {
                    print(info.label + info.debugSignposts.joined())
                    if info.errorState == .faulted {
                        print(info.label + " faulted!")
                    }
                }
            }
        }
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
            (-2.0 * y / frameHeight) - 1.0,
        ]
    }
}
