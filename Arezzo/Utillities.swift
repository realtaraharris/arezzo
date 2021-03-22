//
//  Utillities.swift
//  Arezzo
//
//  Created by Max Harris on 8/19/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation

func getCurrentTimestamp() -> Double {
    CFAbsoluteTimeGetCurrent()
}

func veryRandomVect() -> [Float] { [Float.r(n: Float.random(in: -1.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0)),
                                    Float.r(n: Float.random(in: -1.0 ..< 1.0), tol: Float.random(in: -1.0 ..< 1.0))] }

public extension Float {
    static func r(n: Float, tol: Float) -> Float {
        let low = n - tol
        let high = n + tol
        return tol == 0 || low > high ? n : Float.random(in: low ..< high)
    }
}

struct Matrix4x4 {
    var X: SIMD4<Float>
    var Y: SIMD4<Float>
    var Z: SIMD4<Float>
    var W: SIMD4<Float>

    init() {
        self.X = SIMD4<Float>(x: 1, y: 0, z: 0, w: 0)
        self.Y = SIMD4<Float>(x: 0, y: 1, z: 0, w: 0)
        self.Z = SIMD4<Float>(x: 0, y: 0, z: 1, w: 0)
        self.W = SIMD4<Float>(x: 0, y: 0, z: 0, w: 1)
    }

    static func translate(x: Float, y: Float) -> Matrix4x4 {
        var mat: Matrix4x4 = Matrix4x4()

        mat.W.x = x
        mat.W.y = y

        return mat
    }
}

struct Uniforms {
    let width: Float
    let height: Float
    let modelViewMatrix: Matrix4x4
}
