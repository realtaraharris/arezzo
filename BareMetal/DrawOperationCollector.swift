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
    var opList: [DrawOperation] = []
    var shapeList: [Shape] = []
    var provisionalShapeIndex = 0
    var device: MTLDevice
    var activeColor: [Float] = []
    var currentLineWidth = DEFAULT_LINE_WIDTH
    var currentId: Int = 0

    var penState: PenState = .down

    init(device: MTLDevice) {
        self.device = device
    }

    func addOp(op: DrawOperation, mode: String) {
        self.opList.append(op)

        if op.type == .penDown, mode == "draw" {
            let penDownOp = op as! PenDown
            self.penState = .down
            self.activeColor = penDownOp.color
            self.currentLineWidth = penDownOp.lineWidth
            self.shapeList.append(Shape(type: "Line", id: self.currentId))
            self.currentId += 1
        } else if op.type == .penDown, mode == "pan" {
            self.shapeList.append(Shape(type: "Pan", id: self.currentId))
            self.currentId += 1
        } else if op.type == .pan, mode == "pan" {
            let lastShape = self.shapeList[self.shapeList.count - 1]
            let panOp = op as! Pan
            lastShape.addPanPoint(point: panOp.point, timestamp: panOp.timestamp)
        } else if op.type == .point, self.penState == .down {
            let lastShape = self.shapeList[self.shapeList.count - 1]
            let pointOp = op as! Point
            lastShape.addShapePoint(point: pointOp.point, timestamp: pointOp.timestamp, device: self.device, color: self.activeColor, lineWidth: self.currentLineWidth)
        } else if op.type == .penUp {
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

    func serialize() {
        let wrappedItems: [DrawOperationWrapper] = self.opList.map { DrawOperationWrapper(drawOperation: $0) }
        let jsonData = try! JSONEncoder().encode(wrappedItems)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        print(jsonString)
    }
}
