//
//  DataGenerator.swift
//  StreamingTreeTests
//
//  Created by Max Harris on 8/9/21.
//

import Foundation
import simd

func generateData(count: Int, _ boundingCube: CodableCube) -> [(elementNumber: Int, position: PointInTime, op: DrawOperation)] {
    // a 20x20x20 box, centered about (0, 0, 0).
    // the middle 2x2x2 box, centered about that same points we wish to retrieve

    var result = [(elementNumber: Int, position: PointInTime, op: DrawOperation)]()
    for elementNumber in 0 ..< count {
        let x = Float32.random(in: boundingCube.cubeMin.x ..< boundingCube.cubeMax.x)
        let y = Float32.random(in: boundingCube.cubeMin.y ..< boundingCube.cubeMax.y)
        let t = Double.random(in: boundingCube.cubeMin.t ..< boundingCube.cubeMax.t)

        result.append((
            elementNumber,
            PointInTime(x: x, y: y, t: t),
            Point(point: [x, y], timestamp: 0)
        ))
    }

    return result
}
