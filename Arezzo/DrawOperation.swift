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
    var type: DrawOperationType { get }
    var timestamp: Double { get }
}

struct Viewport: DrawOperation {
    var type: DrawOperationType
    var bounds: [Float]
    var timestamp: Double

    init(bounds: [Float], timestamp: Double) {
        self.type = DrawOperationType.viewport
        self.bounds = bounds
        self.timestamp = timestamp
    }
}

struct Line: DrawOperation {
    var type: DrawOperationType
    var start: [Float]
    var end: [Float]
    var timestamp: Double = 0

    init(start: [Float], end: [Float], timestamp _: Int64) { // TODO: use timestamp
        self.type = DrawOperationType.line
        self.start = start
        self.end = end
    }
}

struct Pan: DrawOperation {
    var type: DrawOperationType
    var point: [Float]
    var timestamp: Double

    init(point: [Float], timestamp: Double) {
        self.type = DrawOperationType.pan
        self.point = point
        self.timestamp = timestamp
    }
}

struct Point: DrawOperation {
    var type: DrawOperationType
    var point: [Float]
    var timestamp: Double

    init(point: [Float], timestamp: Double) {
        self.type = DrawOperationType.point
        self.point = point
        self.timestamp = timestamp
    }
}

enum PenDownMode: String, BinaryCodable {
    case draw, pan, portal
}

struct PenDown: DrawOperation {
    var type: DrawOperationType
    var color: [Float]
    var lineWidth: Float
    var timestamp: Double
    var mode: PenDownMode

    init(color: [Float], lineWidth: Float, timestamp: Double, mode: PenDownMode) {
        self.type = DrawOperationType.penDown
        self.color = color
        self.lineWidth = lineWidth
        self.timestamp = timestamp
        self.mode = mode
    }
}

struct PenUp: DrawOperation {
    var type: DrawOperationType
    var timestamp: Double = 0

    init(timestamp: Double) {
        self.type = DrawOperationType.penUp
        self.timestamp = timestamp
    }
}

struct AudioClip: DrawOperation {
    var type: DrawOperationType
    var timestamp: Double
    var audioSamples: [Int16]

    init(timestamp: Double, audioSamples: [Int16]) {
        self.type = DrawOperationType.audioClip
        self.timestamp = timestamp
        self.audioSamples = audioSamples
    }
}

struct Portal: DrawOperation {
    var type: DrawOperationType
    var point: [Float]
    var timestamp: Double
    var url: String

    init(point: [Float], timestamp: Double, url: String) {
        self.type = DrawOperationType.portal
        self.point = point
        self.timestamp = timestamp
        self.url = url
    }
}

struct UpdatePortal: DrawOperation {
    var type: DrawOperationType
    var timestamp: Double

    init(timestamp: Double) {
        self.type = DrawOperationType.updatePortal
        self.timestamp = timestamp
    }
}

enum DrawOperationType: String, BinaryCodable {
    case line, pan, point, penDown, penUp, audioClip, portal, viewport, updatePortal

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
        case .audioClip:
            return AudioClip.self
        case .portal:
            return Portal.self
        case .viewport:
            return Viewport.self
        case .updatePortal:
            return UpdatePortal.self
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
