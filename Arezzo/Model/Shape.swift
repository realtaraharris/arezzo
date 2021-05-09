//
//  Shape.swift
//  Arezzo
//
//  Created by Max Harris on 10/20/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation

class Shape {
    var geometry: [Float] = []
    var timestamp: [Double] = []
    var color: [Float] = []
    var lineWidth: Float = DEFAULT_LINE_WIDTH
    var type: DrawOperationType
    var name: String!

    init(type: DrawOperationType) {
        self.type = type
    }

    func addShapePoint(point: [Float], timestamp: Double, color: [Float], lineWidth: Float) {
        self.color = color
        self.lineWidth = lineWidth
        self.timestamp.append(timestamp)
        self.geometry.append(contentsOf: point)
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

    func getBoundingRect(endTimestamp: Double) -> [Float]? {
        if self.timestamp.count == 0 { return nil }
        let start = 0
        let end = self.getIndex(timestamp: endTimestamp)
        let startX = self.geometry[start + 0]
        let startY = self.geometry[start + 1]
        let endX = self.geometry[end - 2]
        let endY = self.geometry[end - 1]
        let width = endX - startX
        let height = endY - startY

        return [startX, startY, width, height]
    }
}
