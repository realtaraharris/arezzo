//
//  BareMetalTests.swift
//  BareMetalTests
//
//  Created by Max Harris on 10/10/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import XCTest

class BareMetalTests: XCTestCase {
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
        let device: MTLDevice = MTLCreateSystemDefaultDevice()!

        let f = Shape()
        f.addShape(point: [513.87476, 343.04993], timestamp: 1_602_408_785_976, device: device)
        f.addShape(point: [517.7709, 343.04993], timestamp: 1_602_408_786_160, device: device)
        f.addShape(point: [522.0779, 342.015], timestamp: 1_602_408_786_177, device: device)
        f.addShape(point: [526.7654, 341.54828], timestamp: 1_602_408_786_193, device: device)
        f.addShape(point: [531.5544, 341.54828], timestamp: 1_602_408_787_213, device: device)
        f.addShape(point: [556.4631, 342.81653], timestamp: 1_602_408_787_221, device: device)

        XCTAssert(f.getIndex(timestamp: 1_602_408_787_221) == 10)
        XCTAssert(f.getIndex(timestamp: -1) == -2)
        XCTAssert(f.getIndex(timestamp: 1_602_408_786_194) == 6)
    }

    func testCircle() {
        let capResolutionOdd = 7
        let capVerticesOdd: [Float] = circleGeometry(resolution: capResolutionOdd, SCALE: 50)
        let capIndicesOdd: [UInt32] = shapeIndices(resolution: capResolutionOdd)

        XCTAssertEqual(capVerticesOdd, [25.0, 0.0, 15.587246, 19.545786, -5.5630207, 24.3732, -22.524221, 10.8470955, -22.524223, -10.847089, -5.563037, -24.373194, 15.587242, -19.54579])
        XCTAssertEqual(capIndicesOdd, [6, 0, 5, 1, 4, 2, 3])

        let capResolutionEven = 8
        let capVerticesEven: [Float] = circleGeometry(resolution: capResolutionEven, SCALE: 50)
        let capIndicesEven: [UInt32] = shapeIndices(resolution: capResolutionEven)

        XCTAssertEqual(capVerticesEven, [25.0, 0.0, 17.677671, 17.67767, 1.8874475e-06, 25.0, -17.67767, 17.67767, -25.0, 3.774895e-06, -17.677675, -17.677666, 2.9812202e-07, -25.0, 17.677666, -17.677671])
        XCTAssertEqual(capIndicesEven, [7, 0, 6, 1, 5, 2, 4, 3])
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
}
