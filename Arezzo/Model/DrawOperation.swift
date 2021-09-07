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

enum DrawOperationType: UInt8, BinaryCodable {
    case line, pan, point, penDown, penUp, audioStart, audioClip, audioStop, portal, viewport, undo, redo

    var metatype: DrawOperation.Type {
        switch self {
        case .line:
            return Line.self
        case .pan:
            return Pan.self
        case .point:
            return Point.self
        case .penDown:
            return PenDown.self
        case .penUp:
            return PenUp.self
        case .audioStart:
            return AudioStart.self
        case .audioClip:
            return AudioClip.self
        case .audioStop:
            return AudioStop.self
        case .portal:
            return Portal.self
        case .viewport:
            return Viewport.self
        case .undo:
            return Undo.self
        case .redo:
            return Redo.self
        }
    }
}

struct DrawOperationWrapper {
    var drawOperation: DrawOperation
}

extension DrawOperationWrapper: BinaryCodable {
    private enum CodingKeys: CodingKey {
        case type, drawOperation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(DrawOperationType.self, forKey: .type)
        self.drawOperation = try type.metatype.init(from: container.superDecoder(forKey: .drawOperation))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.drawOperation.type, forKey: .type)
        try self.drawOperation.encode(to: container.superEncoder(forKey: .drawOperation))
    }
}
