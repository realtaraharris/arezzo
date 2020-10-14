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
    var renderBuffer: MTLBuffer!

    func addShape(point: [Float], timestamp: Int64, device: MTLDevice) {
        geometry.append(contentsOf: point)
        self.timestamp.append(timestamp)
        renderBuffer = device.makeBuffer(
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
            if inputArr[currentIndex] == searchItem {
                return currentIndex
            } else if lowerIndex > upperIndex {
                return upperIndex
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

    var penState: PenState = .down

    init(device: MTLDevice) {
        self.device = device
    }

    func addOp(_ op: DrawOperation) {
        if op.type == "PenDown" {
            penState = .down
            shapeList.append(Shape())
        } else if op.type == "Point", penState == .down {
            let lastShape = shapeList[shapeList.count - 1]
            let pointOp = op as! Point
            lastShape.addShape(point: pointOp.point, timestamp: pointOp.timestamp, device: device)
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
