//
//  DrawOperation.swift
//  BareMetal
//
//  Created by Max Harris on 8/13/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation

protocol DrawOperation: Codable {
    var type: DrawOperationType { get }
    var timestamp: Double { get }
    var id: Int64 { get }
}

struct Line: DrawOperation {
    var type: DrawOperationType
    var start: [Float]
    var end: [Float]
    var timestamp: Double = 0
    var id: Int64

    init(start: [Float], end: [Float], timestamp _: Int64, id: Int64) {
        self.type = DrawOperationType.line
        self.start = start
        self.end = end
        self.id = id
    }
}

struct Pan: DrawOperation {
    var type: DrawOperationType
    var point: [Float]
    var timestamp: Double
    var id: Int64

    init(point: [Float], timestamp: Double, id: Int64) {
        self.type = DrawOperationType.pan
        self.point = point
        self.timestamp = timestamp
        self.id = id
    }
}

struct Point: DrawOperation {
    var type: DrawOperationType
    var point: [Float]
    var timestamp: Double
    var id: Int64

    init(point: [Float], timestamp: Double, id: Int64) {
        self.type = DrawOperationType.point
        self.point = point
        self.timestamp = timestamp
        self.id = id
    }
}

struct PenDown: DrawOperation {
    var type: DrawOperationType
    var color: [Float]
    var lineWidth: Float
    var timestamp: Double
    var mode: String
    var id: Int64

    init(color: [Float], lineWidth: Float, timestamp: Double, mode: String, id: Int64) {
        self.type = DrawOperationType.penDown
        self.color = color
        self.lineWidth = lineWidth
        self.timestamp = timestamp
        self.mode = mode
        self.id = id
    }
}

struct PenUp: DrawOperation {
    var type: DrawOperationType
    var timestamp: Double = 0
    var id: Int64

    init(timestamp: Double, id: Int64) {
        self.type = DrawOperationType.penUp
        self.timestamp = timestamp
        self.id = id
    }
}

struct AudioClip: DrawOperation {
    var type: DrawOperationType
    var timestamp: Double
    var id: Int64
    var audioSamples: [Int16]

    init(timestamp: Double, id: Int64, audioSamples: [Int16]) {
        self.type = DrawOperationType.audioClip
        self.timestamp = timestamp
        self.id = id
        self.audioSamples = audioSamples
    }
}

enum DrawOperationType: String, Codable {
    case line, pan, point, penDown, penUp, audioClip

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
        }
    }
}

struct DrawOperationWrapper {
    var drawOperation: DrawOperation
}

extension DrawOperationWrapper: Codable {
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
