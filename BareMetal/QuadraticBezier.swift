//
//  QuadraticBezier.swift
//  BareMetal
//
//  Created by Max Harris on 8/17/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import simd

/// quadraticBezier
func recursiveQuadraticBezier(x1: Float, y1: Float, x2: Float, y2: Float, x3: Float, y3: Float, level: Int, points: inout [[Float]]) {
    // TODO: move into a settings object
    let curveCollinearityEpsilon: Float = 1e-30
    let curveAngleToleranceEpsilon: Float = 0.01
    let curveRecursionLimit = 32
    let mApproximationScale: Float = 0.01
    let mAngleTolerance: Float = 0.0
    var mDistanceToleranceSquare: Float = 0.5
    //    var curveDistanceEpsilon: Float = 1e-30
    mDistanceToleranceSquare = 0.5 / mApproximationScale
    mDistanceToleranceSquare *= mDistanceToleranceSquare

    if level > curveRecursionLimit {
        return
    }

    // calculate all the mid-points of the line segments
    let x12 = (x1 + x2) / 2
    let y12 = (y1 + y2) / 2
    let x23 = (x2 + x3) / 2
    let y23 = (y2 + y3) / 2
    let x123 = (x12 + x23) / 2
    let y123 = (y12 + y23) / 2

    let dx = x3 - x1
    let dy = y3 - y1
    var d = abs((x2 - x3) * dy - (y2 - y3) * dx)
//    print("d: \(d) d^2: \(d*d)")

    if d > curveCollinearityEpsilon {
        // regular case
        if d * d <= mDistanceToleranceSquare * (dx * dx + dy * dy) {
            var da: Float

            // if the curvature doesn't exceed the distance_tolerance value we tend to finish subdivisions
            if mAngleTolerance < curveAngleToleranceEpsilon {
                points.append([x123, y123])
                return
            }

            // angle & cusp condition
            da = abs(atan2(y3 - y2, x3 - x2) - atan2(y2 - y1, x2 - x1))
            if da >= Float.pi { da = 2 * Float.pi - da }

            if da < mAngleTolerance {
                // finally we can stop the recursion
                points.append([x123, y123])
                return
            }
        }
    } else {
        var da: Float

        // collinear case
        da = dx * dx + dy * dy
        if da == 0 {
            d = calculateSquareDistance(x1: x1, y1: y1, x2: x2, y2: y2)
        } else {
            d = ((x2 - x1) * dx + (y2 - y1) * dy) / da
            if d > 0, d < 1 {
                // simple collinear case: 1---2---3
                // we can leave just two endpoints
                return
            }
            if d <= 0 { d = calculateSquareDistance(x1: x2, y1: y2, x2: x1, y2: y1) }
            else if d >= 1 { d = calculateSquareDistance(x1: x2, y1: y2, x2: x3, y2: y3) }
            else { d = calculateSquareDistance(x1: x2, y1: y2, x2: x1 + d * dx, y2: y1 + d * dy) }
        }
        if d < mDistanceToleranceSquare {
            points.append([x2, y2])
            return
        }
    }

    // continue subdivision
    recursiveQuadraticBezier(x1: x1, y1: y1, x2: x12, y2: y12, x3: x123, y3: y123, level: level + 1, points: &points)
    recursiveQuadraticBezier(x1: x123, y1: y123, x2: x23, y2: y23, x3: x3, y3: y3, level: level + 1, points: &points)
}

func tesselateQuadraticBezier(start: [Float], control: [Float], end: [Float], points: inout [[Float]]) {
    // TODO: dig further in here to solve at least one more path drawing bug
    // points.append([start[0], start[1]])
    recursiveQuadraticBezier(x1: start[0], y1: start[1], x2: control[0], y2: control[1], x3: end[0], y3: end[1], level: 0, points: &points)
    points.append([end[0], end[1]])
}

func tesselateQuadraticBezierNew(start: [Float], control: [Float], end: [Float], scale: Float, points: inout [[Float]]) {
    let RECURSION_LIMIT = 8
    let FLT_EPSILON: Float = 1.19209290e-7
    let PATH_DISTANCE_EPSILON: Float = 1.0

    let curve_angle_tolerance_epsilon: Float = 0.01
    let m_angle_tolerance: Float = 0

    func begin(start: [Float], control: [Float], end: [Float], points: inout [[Float]], distanceTolerance: Float) {
        points.append(start)
        let x1 = start[0],
            y1 = start[1],
            x2 = control[0],
            y2 = control[1],
            x3 = end[0],
            y3 = end[1]
        recursive(x1: x1, y1: y1, x2: x2, y2: y2, x3: x3, y3: y3, points: &points, distanceTolerance: distanceTolerance, level: 0)
        points.append(end)
    }

    func recursive(x1: Float, y1: Float, x2: Float, y2: Float, x3: Float, y3: Float, points: inout [[Float]], distanceTolerance: Float, level: Int) {
        if level > RECURSION_LIMIT {
            return
        }

        let pi = Float.pi

        // Calculate all the mid-points of the line segments
        // ----------------------
        let x12 = (x1 + x2) / 2
        let y12 = (y1 + y2) / 2
        let x23 = (x2 + x3) / 2
        let y23 = (y2 + y3) / 2
        let x123 = (x12 + x23) / 2
        let y123 = (y12 + y23) / 2

        var dx = x3 - x1
        var dy = y3 - y1
        let d = abs((x2 - x3) * dy - (y2 - y3) * dx)

        if d > FLT_EPSILON {
            // Regular care
            // -----------------
            if d * d <= distanceTolerance * (dx * dx + dy * dy) {
                // If the curvature doesn't exceed the distance_tolerance value
                // we tend to finish subdivisions.
                // ----------------------
                if m_angle_tolerance < curve_angle_tolerance_epsilon {
                    points.append([x123, y123])
                    return
                }

                // Angle & Cusp Condition
                // ----------------------
                var da = abs(atan2(y3 - y2, x3 - x2) - atan2(y2 - y1, x2 - x1))
                if da >= pi { da = 2 * pi - da }

                if da < m_angle_tolerance {
                    // Finally we can stop the recursion
                    // ----------------------
                    points.append([x123, y123])
                    return
                }
            }
        } else {
            // Collinear case
            // -----------------
            dx = x123 - (x1 + x3) / 2
            dy = y123 - (y1 + y3) / 2
            if dx * dx + dy * dy <= distanceTolerance {
                points.append([x123, y123])

                return
            }
        }

        // Continue subdivision
        // ----------------------
        recursive(x1: x1, y1: y1, x2: x12, y2: y12, x3: x123, y3: y123, points: &points, distanceTolerance: distanceTolerance, level: level + 1)
        recursive(x1: x123, y1: y123, x2: x23, y2: y23, x3: x3, y3: y3, points: &points, distanceTolerance: distanceTolerance, level: level + 1)
    }

    //    return func quadraticCurve() {
    var distanceTolerance = PATH_DISTANCE_EPSILON / scale
    distanceTolerance *= distanceTolerance

    begin(start: start, control: control, end: end, points: &points, distanceTolerance: distanceTolerance)
    //    }

    ////// Based on:
    ////// https://github.com/pelson/antigrain/blob/master/agg-2.4/src/agg_curves.cpp
}
