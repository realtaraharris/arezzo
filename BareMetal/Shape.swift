//
//  Shape.swift
//  BareMetal
//
//  Created by Max Harris on 10/20/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation
import Metal

class Shape {
    var geometry: [Float] = []
    var timestamp: [Int64] = []
    var geometryBuffer: MTLBuffer!
    var colorBuffer: MTLBuffer!
    var widthBuffer: MTLBuffer!
    var type: String
    var panPoints: [Float] = [] // only used when type == "Pan"
    var id: Int

    init(type: String, id: Int) {
        self.type = type
        self.id = id
    }

    func addPanPoint(point: [Float], timestamp: Int64) {
        let panCount = self.panPoints.count
        if panCount == 0 {
            self.panPoints.append(contentsOf: point)
            self.timestamp.append(timestamp)
            return
        }

        assert(panCount % 2 == 0, "panCount should always be even")

        let lastPanX = self.panPoints[panCount - 2]
        let lastPanY = self.panPoints[panCount - 1]
//        print("panCount:", panCount, point)

        if lastPanX == point[0], lastPanY == point[1] {
//            print("skippedd!!!!!")
            return
        }

        self.panPoints.append(contentsOf: point)
        self.timestamp.append(timestamp)
    }

    func addShapePoint(point: [Float], timestamp: Int64, device: MTLDevice, color: [Float], lineWidth: Float) {
        // filter out duplicate points here so as to keep zero-length line segments out of the system
        let geometryCount = self.geometry.count
//        print("geometryCount:", geometryCount)
        if geometryCount == 0 {
            self.colorBuffer = device.makeBuffer(
                bytes: color,
                length: color.count * 4,
                options: .storageModeShared
            )
            self.widthBuffer = device.makeBuffer(
                bytes: [lineWidth],
                length: 4,
                options: .storageModeShared
            )
        } else if geometryCount >= 2,
            self.geometry[geometryCount - 2] == point[0],
            self.geometry[geometryCount - 1] == point[1] {
//            print("skippedd!!!!!")
            return
        }

        self.timestamp.append(timestamp)

        self.geometry.append(contentsOf: point)
        self.geometryBuffer = device.makeBuffer(
            bytes: self.geometry,
            length: self.geometry.count * 4,
            options: .storageModeShared
        )
    }

    func getIndex(timestamp: Int64) -> Int {
        let input = self.timestamp
        var lowerIndex = 0
        var upperIndex = input.count - 1

        while true {
            let currentIndex = (lowerIndex + upperIndex) / 2

            // return values are multiplied by 2 because there are two components for each point
            if input[currentIndex] == timestamp {
                return currentIndex * 2
            } else if lowerIndex > upperIndex {
                return upperIndex * 2
            } else {
                if input[currentIndex] > timestamp {
                    upperIndex = currentIndex - 1
                } else {
                    lowerIndex = currentIndex + 1
                }
            }
        }
    }
}
