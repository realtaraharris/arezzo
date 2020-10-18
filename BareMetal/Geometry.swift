//
//  Geometry.swift
//  BareMetal
//
//  Created by Max Harris on 10/18/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation

func circleGeometry(resolution: Int) -> [Float] {
    var position: [Float] = []
    for wedge in 0 ..< resolution {
        let theta: Float = (2.0 * Float.pi * Float(wedge)) / Float(resolution)
        position.append(0.5 * cos(theta))
        position.append(0.5 * sin(theta))
    }
    return position
}

func shapeIndices(resolution: Int) -> [UInt32] {
    var indices: [UInt32] = []
    for n in zip(((resolution / 2) ... resolution - 1).reversed(), 0 ... (resolution / 2) - 1) {
        indices.append(UInt32(n.0))
        indices.append(UInt32(n.1))
    }
    if resolution % 2 != 0 {
        indices.append(UInt32(resolution / 2))
    }

    return indices
}
