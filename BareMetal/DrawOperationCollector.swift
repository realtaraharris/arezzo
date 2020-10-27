//
//  DrawOperationCollector.swift
//  BareMetal
//
//  Created by Max Harris on 9/3/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation
import Metal

enum PenState {
    case down, up
}

class DrawOperationCollector {
    var shapeList: [Shape] = []
    var provisionalShapeIndex = 0
    var device: MTLDevice
    var activeColor: [Float] = []
    var currentId: Int = 0

    var penState: PenState = .down

    init(device: MTLDevice) {
        self.device = device
    }

    func addOp(op: DrawOperation, mode: String) {
        if op.type == "PenDown", mode == "draw" {
            let penDownOp = op as! PenDown
            penState = .down
            activeColor = penDownOp.color
            shapeList.append(Shape(type: "Line", id: currentId))
            currentId += 1
        } else if op.type == "PenDown", mode == "pan" {
            shapeList.append(Shape(type: "Pan", id: currentId))
            currentId += 1
        } else if op.type == "Pan", mode == "pan" {
            let lastShape = shapeList[shapeList.count - 1]
            let panOp = op as! Pan
            lastShape.addPanPoint(point: panOp.point, timestamp: panOp.timestamp)
        } else if op.type == "Point", penState == .down {
            let lastShape = shapeList[shapeList.count - 1]
            let pointOp = op as! Point
            lastShape.addShapePoint(point: pointOp.point, timestamp: pointOp.timestamp, device: device, color: activeColor)
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
