//
//  Geometry.swift
//  BareMetal
//
//  Created by Max Harris on 10/18/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation

func circleGeometry(edges: Int) -> [Float] {
    var position: [Float] = []
    for wedge in 0 ..< edges {
        let theta: Float = (2.0 * Float.pi * Float(wedge)) / Float(edges)
        position.append(0.5 * cos(theta))
        position.append(0.5 * sin(theta))
    }
    return position
}

func shapeIndices(edges: Int) -> [UInt32] {
    var indices: [UInt32] = []
    for n in zip(((edges / 2) ... edges - 1).reversed(), 0 ... (edges / 2) - 1) {
        indices.append(UInt32(n.0))
        indices.append(UInt32(n.1))
    }
    if edges % 2 != 0 {
        indices.append(UInt32(edges / 2))
    }

    return indices
}
