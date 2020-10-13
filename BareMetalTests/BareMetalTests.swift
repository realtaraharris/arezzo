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

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

//        PenDown(type: "PenDown", color: [0.0, 0.0, 0.0, 0.0], lineWidth: 5.0, timestamp: 1602408785964, id: 0)
//        Point(type: "Point", point: [513.87476, 343.04993], timestamp: 1602408785976, id: 1)
//        Point(type: "Point", point: [517.7709, 343.04993], timestamp: 1602408786160, id: 2)
//        Point(type: "Point", point: [522.0779, 342.015], timestamp: 1602408786177, id: 3)
//        Point(type: "Point", point: [526.7654, 341.54828], timestamp: 1602408786193, id: 4)
//        Point(type: "Point", point: [531.5544, 341.54828], timestamp: 1602408787213, id: 5)
//        Point(type: "Point", point: [556.4631, 342.81653], timestamp: 1602408787221, id: 6)
//        PenUp(type: "PenUp", timestamp: 1602408787221, id: 7)

        let f = Shape()
        f.addShape(point: [513.87476, 343.04993], timestamp: 1_602_408_785_976)
        f.addShape(point: [517.7709, 343.04993], timestamp: 1_602_408_786_160)
        f.addShape(point: [522.0779, 342.015], timestamp: 1_602_408_786_177)
        f.addShape(point: [526.7654, 341.54828], timestamp: 1_602_408_786_193)
        f.addShape(point: [531.5544, 341.54828], timestamp: 1_602_408_787_213)
        f.addShape(point: [556.4631, 342.81653], timestamp: 1_602_408_787_221)

        XCTAssert(f.getIndex(timestamp: 1_602_408_787_221) == 5)
        XCTAssert(f.getIndex(timestamp: -1) == -1)
        XCTAssert(f.getIndex(timestamp: 1_602_408_786_194) == 3)
//        XCTAssert(f.getIndex(timestamp: 18) == 3)
//        XCTAssert(f.getIndex(timestamp: 33) == 4)
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
}
