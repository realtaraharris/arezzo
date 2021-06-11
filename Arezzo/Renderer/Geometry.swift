//
//  Geometry.swift
//  Arezzo
//
//  Created by Max Harris on 10/18/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation

func circleGeometry(edges: Int, lineScale: Float) -> [Float] {
    var position: [Float] = []
    for wedge in 0 ..< edges {
        let theta: Float = (2.0 * Float.pi * Float(wedge)) / Float(edges)
        position.append(0.5 / lineScale * cos(theta))
        position.append(0.5 / lineScale * sin(theta))
    }
    return position
}

func shapeIndices(edges: Int) -> [UInt32] {
    var indices: [UInt32] = []
    let middleEdgeIndex = edges / 2
    for n in zip((middleEdgeIndex ..< edges).reversed(), 0 ..< middleEdgeIndex) {
        indices.append(UInt32(n.0))
        indices.append(UInt32(n.1))
    }
    if edges % 2 != 0 {
        indices.append(UInt32(middleEdgeIndex))
    }
    return indices
}
