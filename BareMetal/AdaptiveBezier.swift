//
//  AdaptiveBezier.swift
//  BareMetal
//
//  Created by Max Harris on 7/20/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//
// Based on https://github.com/pelson/antigrain/blob/master/agg-2.4/src/agg_curves.cpp

import Foundation
import simd

struct BezierTesselationOptions {
    var curveAngleToleranceEpsilon: Float
    var mAngleTolerance: Float
    var mCuspLimit: Float
    var thickness: Float
    var miterLimit: Float
    var scale: Float

    init(curveAngleToleranceEpsilon: Float = 0.01, mAngleTolerance: Float = 0.01, mCuspLimit: Float = 0.0, thickness: Float = 0.025, miterLimit: Float = -1.0, scale: Float = 150) {
        self.curveAngleToleranceEpsilon = curveAngleToleranceEpsilon
        self.mAngleTolerance = mAngleTolerance
        self.mCuspLimit = mCuspLimit
        self.thickness = thickness
        self.miterLimit = miterLimit
        self.scale = scale
    }
}

/// quadraticBezier
func recursiveQuadraticBezier(x1: Float, y1: Float, x2: Float, y2: Float, x3: Float, y3: Float, level: Int, points: inout [[Float]]) {
    // TODO: camelCase these, then move into a settings object
    let curve_collinearity_epsilon: Float = 1e-30
    let curve_angle_tolerance_epsilon: Float = 0.01
    let curve_recursion_limit = 32
    let m_approximation_scale: Float = 100.0
    let m_angle_tolerance: Float = 0.0
    var m_distance_tolerance_square: Float = 0.5
    //    var curve_distance_epsilon: Float = 1e-30
    m_distance_tolerance_square = 0.5 / m_approximation_scale
    m_distance_tolerance_square *= m_distance_tolerance_square

    if level > curve_recursion_limit {
        return
    }

    // Calculate all the mid-points of the line segments
    // ----------------------
    let x12 = (x1 + x2) / 2
    let y12 = (y1 + y2) / 2
    let x23 = (x2 + x3) / 2
    let y23 = (y2 + y3) / 2
    let x123 = (x12 + x23) / 2
    let y123 = (y12 + y23) / 2

    let dx = x3 - x1
    let dy = y3 - y1
    var d = abs((x2 - x3) * dy - (y2 - y3) * dx)

    if d > curve_collinearity_epsilon {
        // Regular case
        // -----------------
        if d * d <= m_distance_tolerance_square * (dx * dx + dy * dy) {
            var da: Float

            // If the curvature doesn't exceed the distance_tolerance value
            // we tend to finish subdivisions.
            // ----------------------
            if m_angle_tolerance < curve_angle_tolerance_epsilon {
                points.append([x123, y123])
                return
            }

            // Angle & Cusp Condition
            // ----------------------
            da = abs(atan2(y3 - y2, x3 - x2) - atan2(y2 - y1, x2 - x1))
            if da >= Float.pi { da = 2 * Float.pi - da }

            if da < m_angle_tolerance {
                // Finally we can stop the recursion
                // ----------------------
                points.append([x123, y123])
                return
            }
        }
    } else {
        var da: Float

        // Collinear case
        // ------------------
        da = dx * dx + dy * dy
        if da == 0 {
            d = calculateSquareDistance(x1: x1, y1: y1, x2: x2, y2: y2)
        } else {
            d = ((x2 - x1) * dx + (y2 - y1) * dy) / da
            if d > 0, d < 1 {
                // Simple collinear case, 1---2---3
                // We can leave just two endpoints
                return
            }
            if d <= 0 { d = calculateSquareDistance(x1: x2, y1: y2, x2: x1, y2: y1) }
            else if d >= 1 { d = calculateSquareDistance(x1: x2, y1: y2, x2: x3, y2: y3) }
            else { d = calculateSquareDistance(x1: x2, y1: y2, x2: x1 + d * dx, y2: y1 + d * dy) }
        }
        if d < m_distance_tolerance_square {
            points.append([x2, y2])
            return
        }
    }

    // Continue subdivision
    // ----------------------
    recursiveQuadraticBezier(x1: x1, y1: y1, x2: x12, y2: y12, x3: x123, y3: y123, level: level + 1, points: &points)
    recursiveQuadraticBezier(x1: x123, y1: y123, x2: x23, y2: y23, x3: x3, y3: y3, level: level + 1, points: &points)
}

func tesselateQuadraticBezier(start: [Float], control: [Float], end: [Float], points: inout [[Float]], options _: BezierTesselationOptions) {
    // TODO: dig further in here to solve at least one more path drawing bug
    // points.append([start[0], start[1]])
    recursiveQuadraticBezier(x1: start[0], y1: start[1], x2: control[0], y2: control[1], x3: end[0], y3: end[1], level: 0, points: &points)
    points.append([end[0], end[1]])
}

/// cubicBezier
func tesselateCubicBezier(
    start: [Float], control1: [Float], control2: [Float], end: [Float], points: inout [[Float]], options: BezierTesselationOptions
) {
    let PATH_DISTANCE_EPSILON: Float = 1.0
    var distanceTolerance = PATH_DISTANCE_EPSILON / options.scale
    distanceTolerance *= distanceTolerance

    // TODO: dig further in here to solve at least one more path drawing bug
    // points.append(start)
    recursiveCubicBezier(x1: start[0], y1: start[1], x2: control1[0], y2: control1[1], x3: control2[0], y3: control2[1], x4: end[0], y4: end[1], distanceTolerance: distanceTolerance, level: 0, points: &points)
    points.append(end)
}

func recursiveCubicBezier(x1: Float, y1: Float, x2: Float, y2: Float, x3: Float, y3: Float, x4: Float, y4: Float, distanceTolerance: Float, level: Int, points: inout [[Float]]) {
    let RECURSION_LIMIT: Int = 8
    let curveAngleToleranceEpsilon: Float = 0.3
    let mAngleTolerance: Float = 0.02
    let mCuspLimit: Float = 0.0

    if level > RECURSION_LIMIT {
        return
    }

    let pi = Float.pi

    // Calculate all the mid-points of the line segments
    let x12 = (x1 + x2) / 2
    let y12 = (y1 + y2) / 2
    let x23 = (x2 + x3) / 2
    let y23 = (y2 + y3) / 2
    let x34 = (x3 + x4) / 2
    let y34 = (y3 + y4) / 2
    let x123 = (x12 + x23) / 2
    let y123 = (y12 + y23) / 2
    let x234 = (x23 + x34) / 2
    let y234 = (y23 + y34) / 2
    let x1234 = (x123 + x234) / 2
    let y1234 = (y123 + y234) / 2

    if level > 0 { // Enforce subdivision first time
        // Try to approximate the full cubic curve by a single straight line
        var dx = x4 - x1
        var dy = y4 - y1

        let d2 = ((x2 - x4) * dy - (y2 - y4) * dx).magnitude
        let d3 = ((x3 - x4) * dy - (y3 - y4) * dx).magnitude

        var da1: Float, da2: Float

        if d2 > Float.ulpOfOne, d3 > Float.ulpOfOne {
            // Regular care
            if (d2 + d3) * (d2 + d3) <= distanceTolerance * (dx * dx + dy * dy) {
                // If the curvature doesn't exceed the distanceTolerance value
                // we tend to finish subdivisions.
                if mAngleTolerance < curveAngleToleranceEpsilon {
                    points.append([x1234, y1234])
                    return
                }

                // Angle & Cusp Condition
                let a23 = atan2(y3 - y2, x3 - x2)
                da1 = (a23 - atan2(y2 - y1, x2 - x1)).magnitude
                da2 = (atan2(y4 - y3, x4 - x3) - a23).magnitude
                if da1 >= pi { da1 = 2 * pi - da1 }
                if da2 >= pi { da2 = 2 * pi - da2 }

                if da1 + da2 < mAngleTolerance {
                    // Finally we can stop the recursion
                    points.append([x1234, y1234])
                    return
                }

                if mCuspLimit != 0.0 {
                    if da1 > mCuspLimit {
                        points.append([x2, y2])
                        return
                    }

                    if da2 > mCuspLimit {
                        points.append([x3, y3])
                        return
                    }
                }
            }
        } else {
            if d2 > Float.ulpOfOne {
                // p1,p3,p4 are collinear, p2 is considerable
                if d2 * d2 <= distanceTolerance * (dx * dx + dy * dy) {
                    if mAngleTolerance < curveAngleToleranceEpsilon {
                        points.append([x1234, y1234])
                        return
                    }

                    // Angle Condition
                    da1 = (atan2(y3 - y2, x3 - x2) - atan2(y2 - y1, x2 - x1)).magnitude
                    if da1 >= pi { da1 = 2 * pi - da1 }

                    if da1 < mAngleTolerance {
                        points.append([x2, y2])
                        points.append([x3, y3])
                        return
                    }

                    if mCuspLimit != 0.0 {
                        if da1 > mCuspLimit {
                            points.append([x2, y2])
                            return
                        }
                    }
                }
            } else if d3 > Float.ulpOfOne {
                // p1,p2,p4 are collinear, p3 is considerable
                if d3 * d3 <= distanceTolerance * (dx * dx + dy * dy) {
                    if mAngleTolerance < curveAngleToleranceEpsilon {
                        points.append([x1234, y1234])
                        return
                    }

                    // Angle Condition
                    da1 = (atan2(y4 - y3, x4 - x3) - atan2(y3 - y2, x3 - x2)).magnitude
                    if da1 >= pi { da1 = 2 * pi - da1 }

                    if da1 < mAngleTolerance {
                        points.append([x2, y2])
                        points.append([x3, y3])
                        return
                    }

                    if mCuspLimit != 0.0 {
                        if da1 > mCuspLimit {
                            points.append([x3, y3])
                            return
                        }
                    }
                }
            } else {
                // Collinear case
                dx = x1234 - (x1 + x4) / 2
                dy = y1234 - (y1 + y4) / 2
                if dx * dx + dy * dy <= distanceTolerance {
                    points.append([x1234, y1234])
                    return
                }
            }
        }
    }

    // Continue subdivision
    recursiveCubicBezier(x1: x1, y1: y1, x2: x12, y2: y12, x3: x123, y3: y123, x4: x1234, y4: y1234, distanceTolerance: distanceTolerance, level: level + 1, points: &points)
    recursiveCubicBezier(x1: x1234, y1: y1234, x2: x234, y2: y234, x3: x34, y3: y34, x4: x4, y4: y4, distanceTolerance: distanceTolerance, level: level + 1, points: &points)
}

// common support functions
func calculateSquareDistance(x1: Float, y1: Float, x2: Float, y2: Float) -> Float {
    let dx = x2 - x1
    let dy = y2 - y1
    return dx * dx + dy * dy
}

// triangle strip
func dumpTriangleStrip(thickness: Float, miterLimit: Float, points: [[Float]]) -> [Float] {
    var output: [Float] = []

    if points.count < 2 { return [] }

    if points.count == 2 {
        let _p0 = points[0] // start of previous segment
        let _p1 = points[1] // end of previous segment, start of current segment
        let p0 = simd_float2(_p0[0], _p0[1])
        let p1 = simd_float2(_p1[0], _p1[1])

        toTriangleStripTwoPoints(thickness: thickness, miterLimit: miterLimit, p0: p0, p1: p1, output: &output)
        return output
    }

    if points.count == 3 {
        let _p0 = points[0] // start of previous segment
//            let _p1 = points[1] // end of previous segment, start of current segment
        let _p2 = points[2] // end of previous segment, start of current segment
        let p0 = simd_float2(_p0[0], _p0[1])
//            let p1 = simd_float2(_p1[0], _p1[1])
        let p2 = simd_float2(_p2[0], _p2[1])

        toTriangleStripTwoPoints(thickness: thickness, miterLimit: miterLimit, p0: p0, p1: p2, output: &output)
        return output
    }

    for index in 0 ... points.count - 4 {
        let _p0 = points[index + 0] // start of previous segment
        let _p1 = points[index + 1] // end of previous segment, start of current segment
        let _p2 = points[index + 2] // end of current segment, start of next segment
        let _p3 = points[index + 3] // end of next segment

        let p0 = simd_float2(_p0[0], _p0[1])
        let p1 = simd_float2(_p1[0], _p1[1])
        let p2 = simd_float2(_p2[0], _p2[1])
        let p3 = simd_float2(_p3[0], _p3[1])

        toTriangleStrip(isFirst: index == 0, isLast: index == points.count - 4, thickness: thickness, miterLimit: miterLimit, p0: p0, p1: p1, p2: p2, p3: p3, output: &output)
    }

    return output
}

func toTriangleStripTwoPoints(thickness: Float, miterLimit _: Float, p0: simd_float2, p1: simd_float2, output: inout [Float]) {
    // perform naive culling
//    let area = simd_float2(1.2, 1.2)
//    if p1.x < -area.x || p1.x > area.x { return }
//    if p1.y < -area.y || p1.y > area.y { return }

    // determine the direction of each of the 3 segments (previous, current, next)
    let v0 = normalize(p1 - p0)

    // determine the normal of each of the 3 segments (previous, current, next)
    let n0 = simd_float2(-v0.y, v0.x)

    // first point
    // if you want an end cap, this is where you'd emit it
    let tmp0 = (p0 + thickness * n0)
    output.append(tmp0.x)
    output.append(tmp0.y)
    output.append(0)

    let tmp1 = (p0 - thickness * n0)
    output.append(tmp1.x)
    output.append(tmp1.y)
    output.append(0)

//    let tmp2 = (p1 - thickness * n0)
//    output.append(tmp2.x)
//    output.append(tmp2.y)
//    output.append(0)
//
//    let tmp3 = (p1 + thickness * n0)
//    output.append(tmp3.x)
//    output.append(tmp3.y)
//    output.append(0)

    // last point
    // if you want an end cap, this is where you'd emit it
    let tmp4 = (p1 + thickness * n0)
    output.append(tmp4.x)
    output.append(tmp4.y)
    output.append(0)

    let tmp5 = (p1 - thickness * n0)
    output.append(tmp5.x)
    output.append(tmp5.y)
    output.append(0)
}

func toTriangleStripThreePoints(thickness: Float, miterLimit _: Float, p0: simd_float2, p1: simd_float2, p2: simd_float2, output: inout [Float]) {
    // perform naive culling
//    let area = simd_float2(1.2, 1.2)
//    if p1.x < -area.x || p1.x > area.x { return }
//    if p1.y < -area.y || p1.y > area.y { return }

    // determine the direction of each of the 3 segments (previous, current, next)
    let v0 = normalize(p1 - p0)
    let v1 = normalize(p2 - p1)

    // determine the normal of each of the 3 segments (previous, current, next)
    let n0 = simd_float2(-v0.y, v0.x)
    let n1 = simd_float2(-v1.y, v1.x)

    // determine miter lines by averaging the normals of the 2 segments
//    var miter_a = normalize(n0 + n1) // miter at start of current segment
//    var miter_b = normalize(n1 + n2) // miter at end of current segment

    // determine the length of the miter by projecting it onto normal and then inverse it
//    var length_a = thickness / dot(miter_a, n1)
//    var length_b = thickness / dot(miter_b, n1)

    // first point
    // if you want an end cap, this is where you'd emit it

    let tmp2 = (p0 + thickness * n0)
    output.append(tmp2.x)
    output.append(tmp2.y)
    output.append(0)

    let tmp0 = (p0 - thickness * n0)
    output.append(tmp0.x)
    output.append(tmp0.y)
    output.append(0)

//    let tmp1 = (p0 - thickness * n0)
//    output.append(tmp1.x)
//    output.append(tmp1.y)
//    output.append(0)
//
//    let tmp3 = (p0 - thickness * n1)
//    output.append(tmp3.x)
//    output.append(tmp3.y)
//    output.append(0)

    let tmp5 = (p1 + thickness * n1)
    output.append(tmp5.x)
    output.append(tmp5.y)
    output.append(0)

    // last point
    // if you want an end cap, this is where you'd emit it
    let tmp4 = (p1 - thickness * n1)
    output.append(tmp4.x)
    output.append(tmp4.y)
    output.append(0)
}

/**
 Calculates thick line strip around input line loop
 :param thickness The thickness of the line in pixels
 :param miterLimit 1.0: always miter, -1.0: never miter, 0.75: default
 */
func toTriangleStrip(isFirst: Bool, isLast: Bool, thickness: Float, miterLimit: Float, p0: simd_float2, p1: simd_float2, p2: simd_float2, p3: simd_float2, output: inout [Float]) {
    // perform naive culling
    let area = simd_float2(1.2, 1.2)
    if p1.x < -area.x || p1.x > area.x { return }
    if p1.y < -area.y || p1.y > area.y { return }
    if p2.x < -area.x || p2.x > area.x { return }
    if p2.y < -area.y || p2.y > area.y { return }

    // determine the direction of each of the 3 segments (previous, current, next)
    let v0 = normalize(p1 - p0)
    let v1 = normalize(p2 - p1)
    let v2 = normalize(p3 - p2)

    // determine the normal of each of the 3 segments (previous, current, next)
    let n0 = simd_float2(-v0.y, v0.x)
    let n1 = simd_float2(-v1.y, v1.x)
    let n2 = simd_float2(-v2.y, v2.x)

    // determine miter lines by averaging the normals of the 2 segments
    var miter_a = normalize(n0 + n1) // miter at start of current segment
    var miter_b = normalize(n1 + n2) // miter at end of current segment

    // determine the length of the miter by projecting it onto normal and then inverse it
    var length_a = thickness / dot(miter_a, n1)
    var length_b = thickness / dot(miter_b, n1)

    if isFirst {
        // if you want an end cap, this is where you'd emit it

        let tmp0 = (p0 + thickness * n1)
        output.append(tmp0.x)
        output.append(tmp0.y)
        output.append(0)

        let tmp2 = (p1 + thickness * n1)
        output.append(tmp2.x)
        output.append(tmp2.y)
        output.append(0)

        let tmp1 = (p0 - thickness * n0)
        output.append(tmp1.x)
        output.append(tmp1.y)
        output.append(0)

        let tmp3 = (p1 - thickness * n1)
        output.append(tmp3.x)
        output.append(tmp3.y)
        output.append(0)
    }

    // prevent excessively long miters at sharp corners
    if dot(v0, v1) < -miterLimit {
        miter_a = n1
        length_a = thickness

        // close the gap
        if dot(v0, n1) > 0 {
            let tmp0 = (p1 + thickness * n0)
            output.append(tmp0.x)
            output.append(tmp0.y)
            output.append(0.0)

            let tmp1 = (p1 + thickness * n1)
            output.append(tmp1.x)
            output.append(tmp1.y)
            output.append(0.0)
        } else {
            let tmp0 = (p1 - thickness * n1)
            output.append(tmp0.x)
            output.append(tmp0.y)
            output.append(0.0)

            let tmp1 = (p1 - thickness * n0)
            output.append(tmp1.x)
            output.append(tmp1.y)
            output.append(0.0)
        }
    }

    if dot(v1, v2) < -miterLimit {
        miter_b = n1
        length_b = thickness
    }

    let tmp0 = (p1 + length_a * miter_a)
    output.append(tmp0.x)
    output.append(tmp0.y)
    output.append(0.0)

    let tmp1 = (p1 - length_a * miter_a)
    output.append(tmp1.x)
    output.append(tmp1.y)
    output.append(0.0)

    let tmp2 = (p2 + length_b * miter_b)
    output.append(tmp2.x)
    output.append(tmp2.y)
    output.append(0.0)

    let tmp3 = (p2 - length_b * miter_b)
    output.append(tmp3.x)
    output.append(tmp3.y)
    output.append(0.0)

    if isLast {
        // if you want an end cap, this is where you'd emit it
        let tmp0 = (p3 + thickness * n2)
        output.append(tmp0.x)
        output.append(tmp0.y)
        output.append(0)

        let tmp1 = (p3 - thickness * n2)
        output.append(tmp1.x)
        output.append(tmp1.y)
        output.append(0)
    }
}
