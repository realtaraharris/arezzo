//
//  DrawOperation.swift
//  BareMetal
//
//  Created by Max Harris on 8/13/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

protocol DrawOperation {
    var type: String { get }
    var timestamp: Double { get }
    var id: Int64 { get }
}

struct Line: DrawOperation {
    var type: String
    var start: [Float]
    var end: [Float]
    var timestamp: Double = 0
    var id: Int64

    init(start: [Float], end: [Float], timestamp _: Int64, id: Int64) {
        self.type = "Line"
        self.start = start
        self.end = end
        self.id = id
    }
}

struct Pan: DrawOperation {
    var type: String
    var point: [Float]
    var timestamp: Double
    var id: Int64

    init(point: [Float], timestamp: Double, id: Int64) {
        self.type = "Pan"
        self.point = point
        self.timestamp = timestamp
        self.id = id
    }
}

struct Point: DrawOperation {
    var type: String
    var point: [Float]
    var timestamp: Double
    var id: Int64

    init(point: [Float], timestamp: Double, id: Int64) {
        self.type = "Point"
        self.point = point
        self.timestamp = timestamp
        self.id = id
    }
}

struct PenDown: DrawOperation {
    var type: String
    var color: [Float]
    var lineWidth: Float
    var timestamp: Double
    var id: Int64

    init(color: [Float], lineWidth: Float, timestamp: Double, id: Int64) {
        self.type = "PenDown"
        self.color = color
        self.lineWidth = lineWidth
        self.timestamp = timestamp
        self.id = id
    }
}

struct PenUp: DrawOperation {
    var type: String
    var timestamp: Double = 0
    var id: Int64

    init(timestamp: Double, id: Int64) {
        self.type = "PenUp"
        self.timestamp = timestamp
        self.id = id
    }
}
