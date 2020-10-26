//
//  BareMetalUITests.swift
//  BareMetalUITests
//
//  Created by Max Harris on 10/23/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Dynamic
import XCTest

class BareMetalUITests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDrawing() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // print(XCUIApplication().debugDescription)
        let record = app.buttons["Record"]

        _ = record.waitForExistence(timeout: 10)
        record.tap()

        // TODO: could use XCPointerEventPath + https://github.com/mhdhejazi/Dynamic to stroke through multiple points
        let window = app.windows.firstMatch

        let firstPoint = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 200, dy: 200))
        let secondPoint = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 400, dy: 400))
        let thirdPoint = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 600, dy: 200))

        firstPoint.press(forDuration: 0.1, thenDragTo: secondPoint)
        secondPoint.press(forDuration: 0.1, thenDragTo: thirdPoint)

        let fullScreenshot = XCUIScreen.main.screenshot()
        let screenshot = XCTAttachment(screenshot: fullScreenshot)
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

//    func testLaunchPerformance() throws {
//        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
//            // This measures how long it takes to launch your application.
//            measure(metrics: [XCTApplicationLaunchMetric()]) {
//                XCUIApplication().launch()
//            }
//        }
//    }
}
