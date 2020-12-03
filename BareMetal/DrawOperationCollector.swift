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
    var currentThickness = DEFAULT_STROKE_THICKNESS
    var currentId: Int = 0

    var penState: PenState = .down

    init(device: MTLDevice) {
        self.device = device
    }

    func addOp(op: DrawOperation, mode: String) {
        if op.type == "PenDown", mode == "draw" {
            let penDownOp = op as! PenDown
            self.penState = .down
            self.activeColor = penDownOp.color
            self.currentThickness = penDownOp.lineWidth
            self.shapeList.append(Shape(type: "Line", id: self.currentId))
            self.currentId += 1
        } else if op.type == "PenDown", mode == "pan" {
            self.shapeList.append(Shape(type: "Pan", id: self.currentId))
            self.currentId += 1
        } else if op.type == "Pan", mode == "pan" {
            let lastShape = self.shapeList[self.shapeList.count - 1]
            let panOp = op as! Pan
            lastShape.addPanPoint(point: panOp.point, timestamp: panOp.timestamp)
        } else if op.type == "Point", self.penState == .down {
            let lastShape = self.shapeList[self.shapeList.count - 1]
            let pointOp = op as! Point
            lastShape.addShapePoint(point: pointOp.point, timestamp: pointOp.timestamp, device: self.device, color: self.activeColor, thickness: self.currentThickness)
        } else if op.type == "PenUp" {
            self.penState = .up
        }
    }

    func beginProvisionalOps() {
        self.provisionalShapeIndex = self.shapeList.count
    }

    func commitProvisionalOps() {
        self.provisionalShapeIndex = self.shapeList.count
    }

    func cancelProvisionalOps() {
        self.shapeList.removeSubrange(self.provisionalShapeIndex ..< self.shapeList.count)
    }
}
