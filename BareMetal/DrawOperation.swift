//
//  DrawOperation.swift
//  BareMetal
//
//  Created by Max Harris on 8/13/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

protocol DrawOperation {
    var type: String { get }
    var timestamp: Int64 { get }
    var id: Int64 { get }
}

struct Line: DrawOperation {
    var type: String
    var start: [Float]
    var end: [Float]
    var timestamp: Int64 = 0
    var id: Int64

    init(start: [Float], end: [Float], timestamp _: Int64, id: Int64) {
        type = "Line"
        self.start = start
        self.end = end
        self.id = id
    }
}

struct CubicBezier: DrawOperation {
    var type: String
    var start: [Float]
    var end: [Float]
    var control1: [Float]
    var control2: [Float]
    var lineWidth: Float = 0.050
    var timestamp: Int64 = 0
    var id: Int64

    init(start: [Float], end: [Float], control1: [Float], control2: [Float], timestamp: Int64, id: Int64) {
        type = "CubicBezier"
        self.start = start
        self.end = end
        self.control1 = control1
        self.control2 = control2
        self.timestamp = timestamp
        self.id = id
    }
}

struct QuadraticBezier: DrawOperation {
    var type: String
    var start: [Float]
    var end: [Float]
    var control: [Float]
    var timestamp: Int64 = 0
    var id: Int64

    init(start: [Float], end: [Float], control: [Float], timestamp: Int64, id: Int64) {
        type = "QuadraticBezier"
        self.start = start
        self.end = end
        self.control = control
        self.timestamp = timestamp
        self.id = id
    }
}

struct Pan: DrawOperation {
    var type: String
    var start: [Float]
    var end: [Float]
    var timestamp: Int64
    var id: Int64

    init(start: [Float], end: [Float], timestamp: Int64, id: Int64) {
        type = "Pan"
        self.start = start
        self.end = end
        self.timestamp = timestamp
        self.id = id
    }
}

struct Point: DrawOperation {
    var type: String
    var point: [Float]
    var timestamp: Int64
    var id: Int64

    init(point: [Float], timestamp: Int64, id: Int64) {
        type = "Point"
        self.point = point
        self.timestamp = timestamp
        self.id = id
    }
}

struct PenDown: DrawOperation {
    var type: String
    var color: [Float]
    var lineWidth: Float = 0.050
    var timestamp: Int64 = 0
    var id: Int64

    init(color: [Float], lineWidth: Float, timestamp: Int64, id: Int64) {
        type = "PenDown"
        self.color = color
        self.lineWidth = lineWidth
        self.timestamp = timestamp
        self.id = id
    }
}

struct PenUp: DrawOperation {
    var type: String
    var timestamp: Int64 = 0
    var id: Int64

    init(timestamp: Int64, id: Int64) {
        type = "PenUp"
        self.timestamp = timestamp
        self.id = id
    }
}