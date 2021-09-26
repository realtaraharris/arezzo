//
//  ArezzoTests.swift
//  ArezzoTests
//
//  Created by Max Harris on 10/10/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import XCTest

class ArezzoTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // PenDown(type: "PenDown", color: [0.0, 0.0, 0.0, 0.0], lineWidth: 5.0, timestamp: 1602408785964, id: 0)
    // Point(type: "Point", point: [513.87476, 343.04993], timestamp: 1602408785976, id: 1)
    // Point(type: "Point", point: [517.7709, 343.04993], timestamp: 1602408786160, id: 2)
    // Point(type: "Point", point: [522.0779, 342.015], timestamp: 1602408786177, id: 3)
    // Point(type: "Point", point: [526.7654, 341.54828], timestamp: 1602408786193, id: 4)
    // Point(type: "Point", point: [531.5544, 341.54828], timestamp: 1602408787213, id: 5)
    // Point(type: "Point", point: [556.4631, 342.81653], timestamp: 1602408787221, id: 6)
    // PenUp(type: "PenUp", timestamp: 1602408787221, id: 7)

    func testShape() throws {
        let f = Shape(type: NodeType.line)
        let color: [Float] = [1.0, 0.0, 0.0, 1.0]
        let lineWidth: Float = 5
        f.addShapePoint(point: [513.87476, 343.04993], timestamp: 1_602_408_785_976, color: color, lineWidth: lineWidth)
        f.addShapePoint(point: [517.7709, 343.04993], timestamp: 1_602_408_786_160, color: color, lineWidth: lineWidth)
        f.addShapePoint(point: [522.0779, 342.015], timestamp: 1_602_408_786_177, color: color, lineWidth: lineWidth)
        f.addShapePoint(point: [526.7654, 341.54828], timestamp: 1_602_408_786_193, color: color, lineWidth: lineWidth)
        f.addShapePoint(point: [531.5544, 341.54828], timestamp: 1_602_408_787_213, color: color, lineWidth: lineWidth)
        f.addShapePoint(point: [556.4631, 342.81653], timestamp: 1_602_408_787_221, color: color, lineWidth: lineWidth)

        XCTAssertEqual(f.getIndex(timestamp: 1_602_408_787_221), 12)
        XCTAssertEqual(f.getIndex(timestamp: -1), 0)
        XCTAssertEqual(f.getIndex(timestamp: 1_602_408_786_194), 8)
    }

    func testCircle() {
        let capResolutionOdd = 7
        let capVerticesOdd: [Float] = circleGeometry(edges: capResolutionOdd)
        let capIndicesOdd: [UInt32] = shapeIndices(edges: capResolutionOdd)

        XCTAssertEqual(capVerticesOdd, [0.5, 0.0, 0.31174493, 0.39091572, -0.111260414, 0.48746398, -0.45048442, 0.21694191, -0.45048448, -0.21694177, -0.11126074, -0.4874639, 0.31174484, -0.3909158])
        XCTAssertEqual(capIndicesOdd, [6, 0, 5, 1, 4, 2, 3])

        let capResolutionEven = 8
        let capVerticesEven: [Float] = circleGeometry(edges: capResolutionEven)
        let capIndicesEven: [UInt32] = shapeIndices(edges: capResolutionEven)

        XCTAssertEqual(capVerticesEven, [0.5, 0.0, 0.3535534, 0.35355338, 3.774895e-08, 0.5, -0.35355338, 0.35355338, -0.5, 7.54979e-08, -0.3535535, -0.3535533, 5.9624403e-09, -0.5, 0.35355332, -0.35355344])
        XCTAssertEqual(capIndicesEven, [7, 0, 6, 1, 5, 2, 4, 3])
    }

    func testCollector() {
        let filename = "Root"

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        let recording = Recording(name: filename)
        XCTAssertEqual(recording.opList.count, 0)

//        recording.addOp(op: AudioClip(timestamp: CFAbsoluteTimeGetCurrent(), audioSamples: []), position: PointInTime(
//            x: 0, y: 1, t: CFAbsoluteTimeGetCurrent()
//        ))
        recording.addOp(op: PenDown(color: [1.0, 0.0, 1.0, 1.0], lineWidth: DEFAULT_LINE_WIDTH, timestamp: CFAbsoluteTimeGetCurrent(), mode: .draw, portalName: ""), position: PointInTime(
            x: 2, y: 3, t: CFAbsoluteTimeGetCurrent()
        ))
//        recording.addOp(op: Point(point: [800, 100], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
//            x: 4, y: 5, t: CFAbsoluteTimeGetCurrent()
//        ))
//        recording.addOp(op: PenUp(timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
//            x: 6, y: 7, t: CFAbsoluteTimeGetCurrent()
//        ))
//        recording.addOp(op: PenDown(color: [0.0, 0.0, 0.0, 0.0], lineWidth: DEFAULT_LINE_WIDTH, timestamp: CFAbsoluteTimeGetCurrent(), mode: .pan, portalName: ""), position: PointInTime(
//            x: 8, y: 9, t: CFAbsoluteTimeGetCurrent()
//        ))
//        recording.addOp(op: Pan(point: [100, 400], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
//            x: 10, y: 11, t: CFAbsoluteTimeGetCurrent()
//        ))
        recording.addOp(op: PenUp(timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 12, y: 13, t: CFAbsoluteTimeGetCurrent()
        ))

        recording.serialize(filename: filename)
        recording.mapping.printTree(recording.tree, "recording")
        recording.close()

        let recording2 = Recording(name: filename)
        recording2.deserialize(filename: filename)
        recording2.mapping.printTree(recording2.tree, "recording2, after loading")

//        XCTAssertEqual(recording2.opList.count, 7)
//        XCTAssertEqual(recording2.shapeList.count, 2)
//        XCTAssertEqual(recording2.timestamps.count, 7)

        recording2.addOp(op: PenDown(color: [1.0, 0.0, 1.0, 1.0], lineWidth: DEFAULT_LINE_WIDTH, timestamp: CFAbsoluteTimeGetCurrent(), mode: .draw, portalName: ""), position: PointInTime(
            x: 24, y: 25, t: CFAbsoluteTimeGetCurrent()
        ))
//        recording2.addOp(op: Point(point: [310, 645], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
//            x: 26, y: 27, t: CFAbsoluteTimeGetCurrent()
//        ))
//        recording2.addOp(op: Point(point: [284.791, 429.16245], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
//            x: 28, y: 29, t: CFAbsoluteTimeGetCurrent()
//        ))
//        recording2.addOp(op: Point(point: [800, 100], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
//            x: 30, y: 31, t: CFAbsoluteTimeGetCurrent()
//        ))
        recording2.addOp(op: PenUp(timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 32, y: 33, t: CFAbsoluteTimeGetCurrent()
        ))

//        XCTAssertEqual(recording2.opList.count, 12)
//        XCTAssertEqual(recording2.shapeList.count, 3)
//        XCTAssertEqual(recording2.timestamps.count, 12)

        // write to disk again
        print("vvvvvvvvvvvvvvvv")
        recording2.serialize(filename: filename)
        recording2.mapping.printTree(recording2.tree, "recording2")
        recording2.close()
        print("^^^^^^^^^^^^^^^^")

        // now make sure we can read it back
        let recording3 = Recording(name: filename)
        recording3.deserialize(filename: filename)

        recording3.mapping.printTree(recording3.tree, "recording3")

        XCTAssertEqual(recording3.opList.count, 4)
        XCTAssertEqual(recording3.shapeList.count, 2)
        XCTAssertEqual(recording3.timestamps.count, 4)
    }
}
