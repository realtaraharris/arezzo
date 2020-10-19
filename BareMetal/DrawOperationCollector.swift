//
//  DrawOperationCollector.swift
//  BareMetal
//
//  Created by Max Harris on 9/3/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation
import Metal

class Shape {
    var geometry: [Float] = []
    var timestamp: [Int64] = []
    var geometryBuffer: MTLBuffer!
    var colorBuffer: MTLBuffer!

    func addShape(point: [Float], timestamp: Int64, device: MTLDevice, color: [Float]) {
        // filter out duplicate points here so as to keep zero-length line segments out of the system
        let geometryCount = geometry.count
        if geometryCount == 0 {
            colorBuffer = device.makeBuffer(
                bytes: color,
                length: color.count * 4,
                options: .storageModeShared
            )
        } else if geometryCount >= 2,
            geometry[geometryCount - 2] == point[0],
            geometry[geometryCount - 1] == point[1] {
            return
        }

        self.timestamp.append(timestamp)

        geometry.append(contentsOf: point)
        geometryBuffer = device.makeBuffer(
            bytes: geometry,
            length: geometry.count * 4,
            options: .storageModeShared
        )
    }

    func getIndex(timestamp: Int64) -> Int {
        let inputArr = self.timestamp
        let searchItem = timestamp

        var lowerIndex = 0
        var upperIndex = inputArr.count - 1

        while true {
            let currentIndex = (lowerIndex + upperIndex) / 2

            // return values are multiplied by 2 because there are two components for each point in the geometryBuffer
            if inputArr[currentIndex] == searchItem {
                return currentIndex * 2
            } else if lowerIndex > upperIndex {
                return upperIndex * 2
            } else {
                if inputArr[currentIndex] > searchItem {
                    upperIndex = currentIndex - 1
                } else {
                    lowerIndex = currentIndex + 1
                }
            }
        }
    }
}

enum PenState {
    case down, up
}

class DrawOperationCollector {
    var shapeList: [Shape] = []
    var provisionalShapeIndex = 0
    var device: MTLDevice
    var activeColor: [Float] = []

    var penState: PenState = .down

    init(device: MTLDevice) {
        self.device = device
    }

    func addOp(_ op: DrawOperation) {
        if op.type == "PenDown" {
            let penDownOp = op as! PenDown
            penState = .down
            activeColor = penDownOp.color
            shapeList.append(Shape())
        } else if op.type == "Point", penState == .down {
            let lastShape = shapeList[shapeList.count - 1]
            let pointOp = op as! Point
            lastShape.addShape(point: pointOp.point, timestamp: pointOp.timestamp, device: device, color: activeColor)
        } else if op.type == "PenUp" {
            penState = .up
        }
    }

    func beginProvisionalOps() {
        provisionalShapeIndex = shapeList.count
    }

    func commitProvisionalOps() {
        provisionalShapeIndex = shapeList.count
    }

    func cancelProvisionalOps() {
        shapeList.removeSubrange(provisionalShapeIndex ..< shapeList.count)
    }
}
