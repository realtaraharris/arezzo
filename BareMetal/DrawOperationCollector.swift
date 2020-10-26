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
