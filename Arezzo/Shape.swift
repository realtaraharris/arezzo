//
//  Shape.swift
//  Arezzo
//
//  Created by Max Harris on 10/20/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation
import Metal

class Shape {
    var geometry: [Float] = []
    var timestamp: [Double] = []
    var geometryBuffer: MTLBuffer!
    var colorBuffer: MTLBuffer!
    var widthBuffer: MTLBuffer!
    var type: String

    init(type: String) {
        self.type = type
    }

    func addShapePoint(point: [Float], timestamp: Double, device: MTLDevice, color: [Float], lineWidth: Float) {
        let geometryCount = self.geometry.count
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
        }

        self.timestamp.append(timestamp)

        self.geometry.append(contentsOf: point)
        self.geometryBuffer = device.makeBuffer(length: self.geometry.count * 4, options: MTLResourceOptions.cpuCacheModeWriteCombined)
    }

    func getIndex(timestamp: Double) -> Int {
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