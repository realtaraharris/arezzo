//
//  DrawOperation.swift
//  streaming-octree
//
//  Created by Max Harris on 7/8/21.
//

import BinaryCoder
import Foundation

enum NodeType: UInt8, BinaryCodable {
    case nodeRecord, leaf, line, pan, point, penDown, penUp, audioStart, audioClip, audioStop, portal, viewport, undo, redo
}

struct DrawOperationEx: BinaryCodable {
    var leafData: UInt64
    var position: PointInTime
    var id: Int64
}

/*
protocol DrawOperation: BinaryCodable {
    var type: NodeType { get }
}

struct Viewport: DrawOperation {
    var type: NodeType
    var bounds: [Float]

    init(bounds: [Float]) {
        self.type = NodeType.viewport
        self.bounds = bounds
    }
}

struct Line: DrawOperation {
    var type: NodeType
    var start: [Float]
    var end: [Float]

    init(start: [Float], end: [Float]) {
        self.type = NodeType.line
        self.start = start
        self.end = end
    }
}

struct Pan: DrawOperation {
    var type: NodeType
    var point: [Float]
    var oldestVisibleTimestamp: Double

    init(point: [Float], oldestVisibleTimestamp: Double) {
        self.type = NodeType.pan
        self.point = point
        self.oldestVisibleTimestamp = oldestVisibleTimestamp
    }
}

struct Point: DrawOperation {
    var type: NodeType
    var point: [Float]

    init(point: [Float]) {
        self.type = NodeType.point
        self.point = point
    }
}
*/
