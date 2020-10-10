//
//  DrawOperationCollector.swift
//  BareMetal
//
//  Created by Max Harris on 9/3/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation

class Shape {
    var geometry: [Float] = []
    var timestamp: [Int64] = []

    func addShape(point: [Float], timestamp: Int64) {
        geometry.append(contentsOf: point)
        self.timestamp.append(timestamp)
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

    var penState: PenState = .down

    func addOp(_ op: DrawOperation) {
        if op.type == "PenDown" {
            penState = .down
            shapeList.append(Shape())
        } else if op.type == "Point", penState == .down {
            let lastShape = shapeList[shapeList.count - 1]
            let pointOp = op as! Point
            lastShape.geometry.append(contentsOf: pointOp.point)
            lastShape.timestamp.append(pointOp.timestamp)
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
