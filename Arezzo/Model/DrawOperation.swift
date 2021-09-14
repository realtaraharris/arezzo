//
//  DrawOperation.swift
//  Arezzo
//
//  Created by Max Harris on 8/13/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import BinaryCoder
import Foundation

protocol DrawOperation: BinaryCodable {
    var type: NodeType { get }
    var timestamp: Double { get }
}

struct Viewport: DrawOperation {
    var type: NodeType
    var bounds: [Float]
    var timestamp: Double

    init(bounds: [Float], timestamp: Double) {
        self.type = NodeType.viewport
        self.bounds = bounds
        self.timestamp = timestamp
    }
}

struct Line: DrawOperation {
    var type: NodeType
    var start: [Float]
    var end: [Float]
    var timestamp: Double = 0

    init(start: [Float], end: [Float], timestamp: Double) {
        self.type = NodeType.line
        self.start = start
        self.end = end
        self.timestamp = timestamp
    }
}

struct Pan: DrawOperation {
    var type: NodeType
    var point: [Float]
    var timestamp: Double

    init(point: [Float], timestamp: Double) {
        self.type = NodeType.pan
        self.point = point
        self.timestamp = timestamp
    }
}

struct Point: DrawOperation {
    var type: NodeType
    var point: [Float]
    var timestamp: Double

    init(point: [Float], timestamp: Double) {
        self.type = NodeType.point
        self.point = point
        self.timestamp = timestamp
    }
}

enum PenDownMode: String, BinaryCodable {
    case draw, pan, portal
}

struct PenDown: DrawOperation {
    var type: NodeType
    var color: [Float]
    var lineWidth: Float
    var timestamp: Double
    var mode: PenDownMode
    var portalName: String

    init(color: [Float], lineWidth: Float, timestamp: Double, mode: PenDownMode, portalName: String) {
        self.type = NodeType.penDown
        self.color = color
        self.lineWidth = lineWidth
        self.timestamp = timestamp
        self.mode = mode
        self.portalName = portalName
    }
}

struct PenUp: DrawOperation {
    var type: NodeType
    var timestamp: Double

    init(timestamp: Double) {
        self.type = NodeType.penUp
        self.timestamp = timestamp
    }
}

struct AudioStart: DrawOperation {
    var type: NodeType
    var timestamp: Double

    init(timestamp: Double) {
        self.type = NodeType.audioStart
        self.timestamp = timestamp
    }
}

struct AudioClip: DrawOperation {
    var type: NodeType
    var timestamp: Double
    var audioSamples: [Int16]

    init(timestamp: Double, audioSamples: [Int16]) {
        self.type = NodeType.audioClip
        self.timestamp = timestamp
        self.audioSamples = audioSamples
    }
}

struct AudioStop: DrawOperation {
    var type: NodeType
    var timestamp: Double

    init(timestamp: Double) {
        self.type = NodeType.audioStop
        self.timestamp = timestamp
    }
}

struct Portal: DrawOperation {
    var type: NodeType
    var point: [Float]
    var timestamp: Double

    init(point: [Float], timestamp: Double) {
        self.type = NodeType.portal
        self.point = point
        self.timestamp = timestamp
    }
}

struct Undo: DrawOperation {
    var type: NodeType
    var timestamp: Double

    init(timestamp: Double) {
        self.type = NodeType.undo
        self.timestamp = timestamp
    }
}

struct Redo: DrawOperation {
    var type: NodeType
    var timestamp: Double

    init(timestamp: Double) {
        self.type = NodeType.redo
        self.timestamp = timestamp
    }
}
