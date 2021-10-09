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

        recording.addOp(op: PenDown(color: [1.0, 0.0, 1.0, 1.0], lineWidth: DEFAULT_LINE_WIDTH, timestamp: CFAbsoluteTimeGetCurrent(), mode: .draw, portalName: ""), position: PointInTime(
            x: 0, y: 1, t: CFAbsoluteTimeGetCurrent()
        ))
        recording.addOp(op: Point(point: [2, 3], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 2, y: 3, t: CFAbsoluteTimeGetCurrent()
        ))
        recording.addOp(op: PenUp(timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 4, y: 5, t: CFAbsoluteTimeGetCurrent()
        ))

        recording.serialize(filename: filename)
//        recording.mapping.printTree(recording.tree, "recording")
        recording.close()

        let recording2 = Recording(name: filename)
        recording2.deserialize(filename: filename)
//        recording2.mapping.printTree(recording2.tree, "recording2, after loading")

        recording2.addOp(op: PenDown(color: [1.0, 0.0, 1.0, 1.0], lineWidth: DEFAULT_LINE_WIDTH, timestamp: CFAbsoluteTimeGetCurrent(), mode: .draw, portalName: ""), position: PointInTime(
            x: 6, y: 7, t: CFAbsoluteTimeGetCurrent()
        ))
        recording2.addOp(op: Point(point: [8, 9], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 8, y: 9, t: CFAbsoluteTimeGetCurrent()
        ))
        recording2.addOp(op: PenUp(timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 10, y: 11, t: CFAbsoluteTimeGetCurrent()
        ))

        // write to disk again
        recording2.serialize(filename: filename)
//        recording2.mapping.printTree(recording2.tree, "recording2")
        recording2.close()

        // now make sure we can read it back
        let recording3 = Recording(name: filename)
        recording3.deserialize(filename: filename)

//        recording3.mapping.printTree(recording3.tree, "recording3")

        XCTAssertEqual(recording3.opList.count, 6)
        XCTAssertEqual(recording3.shapeList.count, 2)
        XCTAssertEqual(recording3.timestamps.count, 6)

        recording3.addOp(op: PenDown(color: [1.0, 0.0, 1.0, 1.0], lineWidth: DEFAULT_LINE_WIDTH, timestamp: CFAbsoluteTimeGetCurrent(), mode: .draw, portalName: ""), position: PointInTime(
            x: 12, y: 13, t: CFAbsoluteTimeGetCurrent()
        ))
        recording3.addOp(op: Point(point: [14, 15], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 14, y: 15, t: CFAbsoluteTimeGetCurrent()
        ))
        recording3.addOp(op: Point(point: [16, 17], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 16, y: 17, t: CFAbsoluteTimeGetCurrent()
        ))
        recording3.addOp(op: Point(point: [18, 19], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 18, y: 19, t: CFAbsoluteTimeGetCurrent()
        ))
        recording3.addOp(op: Point(point: [20, 21], timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 20, y: 21, t: CFAbsoluteTimeGetCurrent()
        ))
        recording3.addOp(op: PenUp(timestamp: CFAbsoluteTimeGetCurrent()), position: PointInTime(
            x: 22, y: 23, t: CFAbsoluteTimeGetCurrent()
        ))

        recording3.serialize(filename: filename)
//        recording3.mapping.printTree(recording3.tree, "recording3")
        recording3.close()
        XCTAssertEqual(recording3.opList.count, 12)
        XCTAssertEqual(recording3.shapeList.count, 3)
        XCTAssertEqual(recording3.timestamps.count, 12)

        // now make sure we can read it back
        let recording4 = Recording(name: filename)
        recording4.deserialize(filename: filename)

//        recording4.mapping.printTree(recording4.tree, "recording4")
        XCTAssertEqual(recording4.opList.count, 12)
        XCTAssertEqual(recording4.shapeList.count, 3)
        XCTAssertEqual(recording4.timestamps.count, 12)
    }

    func testHarder() {
//        recording.mapping.printTree(recording.tree, "recording")
        let first: [(DrawOperation, PointInTime)] = [
            (op: Viewport(bounds: [1309.0, 804.0], timestamp: 655_146_515.532137), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_515.532137)),
            (op: PenDown(color: [-0.35856336, 0.7281812, -0.13782531, 1.0], lineWidth: 0.01, timestamp: 655_146_518.304565, mode: PenDownMode.draw, portalName: ""), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_518.304565)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.304565), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.304565)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.337495), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.337495)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.349168), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.349168)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.365835), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.365835)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.382826), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.382826)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.399497), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.399497)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.416128), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.416128)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.432892), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.432892)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.44952), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.44952)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.466216), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.466216)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.483049), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.483049)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.499803), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.499803)),
            (op: Point(point: [-0.8362001, 0.6299557], timestamp: 655_146_518.516143), position: PointInTime(x: -0.8362001, y: 0.6299557, t: 655_146_518.516143)),
            (op: Point(point: [-0.8362001, 0.6293824], timestamp: 655_146_518.532751), position: PointInTime(x: -0.8362001, y: 0.6293824, t: 655_146_518.532751)),
            (op: Point(point: [-0.8362001, 0.626409], timestamp: 655_146_518.549677), position: PointInTime(x: -0.8362001, y: 0.626409, t: 655_146_518.549677)),
            (op: Point(point: [-0.8362001, 0.62357163], timestamp: 655_146_518.56625), position: PointInTime(x: -0.8362001, y: 0.62357163, t: 655_146_518.56625)),
            (op: Point(point: [-0.8362001, 0.6155162], timestamp: 655_146_518.583207), position: PointInTime(x: -0.8362001, y: 0.6155162, t: 655_146_518.583207)),
            (op: Point(point: [-0.8366835, 0.610852], timestamp: 655_146_518.599637), position: PointInTime(x: -0.8366835, y: 0.610852, t: 655_146_518.599637)),
            (op: Point(point: [-0.8366835, 0.60512865], timestamp: 655_146_518.616265), position: PointInTime(x: -0.8366835, y: 0.60512865, t: 655_146_518.616265)),
            (op: Point(point: [-0.8366835, 0.60046446], timestamp: 655_146_518.632934), position: PointInTime(x: -0.8366835, y: 0.60046446, t: 655_146_518.632934)),
            (op: Point(point: [-0.8366835, 0.5958003], timestamp: 655_146_518.649614), position: PointInTime(x: -0.8366835, y: 0.5958003, t: 655_146_518.649614)),
            (op: Point(point: [-0.8366835, 0.59204954], timestamp: 655_146_518.66649), position: PointInTime(x: -0.8366835, y: 0.59204954, t: 655_146_518.66649)),
            (op: Point(point: [-0.8366835, 0.5892122], timestamp: 655_146_518.682968), position: PointInTime(x: -0.8366835, y: 0.5892122, t: 655_146_518.682968)),
            (op: Point(point: [-0.8366835, 0.58637476], timestamp: 655_146_518.69972), position: PointInTime(x: -0.8366835, y: 0.58637476, t: 655_146_518.69972)),
            (op: Point(point: [-0.83628964, 0.5850921], timestamp: 655_146_518.716466), position: PointInTime(x: -0.83628964, y: 0.5850921, t: 655_146_518.716466)),
            (op: Point(point: [-0.8350303, 0.5837512], timestamp: 655_146_518.73293), position: PointInTime(x: -0.8350303, y: 0.5837512, t: 655_146_518.73293)),
            (op: Point(point: [-0.83272654, 0.5822645], timestamp: 655_146_518.749492), position: PointInTime(x: -0.83272654, y: 0.5822645, t: 655_146_518.749492)),
            (op: Point(point: [-0.82986176, 0.58070976], timestamp: 655_146_518.766289), position: PointInTime(x: -0.82986176, y: 0.58070976, t: 655_146_518.766289)),
            (op: Point(point: [-0.8263524, 0.5799421], timestamp: 655_146_518.783017), position: PointInTime(x: -0.8263524, y: 0.5799421, t: 655_146_518.783017)),
            (op: Point(point: [-0.82145244, 0.5799421], timestamp: 655_146_518.799629), position: PointInTime(x: -0.82145244, y: 0.5799421, t: 655_146_518.799629)),
            (op: Point(point: [-0.81581837, 0.5799421], timestamp: 655_146_518.816412), position: PointInTime(x: -0.81581837, y: 0.5799421, t: 655_146_518.816412)),
            (op: Point(point: [-0.8101843, 0.5799421], timestamp: 655_146_518.83314), position: PointInTime(x: -0.8101843, y: 0.5799421, t: 655_146_518.83314)),
            (op: Point(point: [-0.8029149, 0.5799421], timestamp: 655_146_518.849776), position: PointInTime(x: -0.8029149, y: 0.5799421, t: 655_146_518.849776)),
            (op: Point(point: [-0.7944698, 0.58270174], timestamp: 655_146_518.866151), position: PointInTime(x: -0.7944698, y: 0.58270174, t: 655_146_518.866151)),
            (op: Point(point: [-0.79031587, 0.58524764], timestamp: 655_146_518.882869), position: PointInTime(x: -0.79031587, y: 0.58524764, t: 655_146_518.882869)),
            (op: Point(point: [-0.78615, 0.58864856], timestamp: 655_146_518.899479), position: PointInTime(x: -0.78615, y: 0.58864856, t: 655_146_518.899479)),
            (op: Point(point: [-0.7838462, 0.5916414], timestamp: 655_146_518.916404), position: PointInTime(x: -0.7838462, y: 0.5916414, t: 655_146_518.916404)),
            (op: Point(point: [-0.7814112, 0.5956254], timestamp: 655_146_518.932931), position: PointInTime(x: -0.7814112, y: 0.5956254, t: 655_146_518.932931)),
            (op: Point(point: [-0.7795848, 0.59939563], timestamp: 655_146_518.949543), position: PointInTime(x: -0.7795848, y: 0.59939563, t: 655_146_518.949543)),
            (op: Point(point: [-0.77827775, 0.6022524], timestamp: 655_146_518.966337), position: PointInTime(x: -0.77827775, y: 0.6022524, t: 655_146_518.966337)),
            (op: Point(point: [-0.7763679, 0.60693604], timestamp: 655_146_518.982787), position: PointInTime(x: -0.7763679, y: 0.60693604, t: 655_146_518.982787)),
            (op: Point(point: [-0.7753712, 0.61267877], timestamp: 655_146_518.999657), position: PointInTime(x: -0.7753712, y: 0.61267877, t: 655_146_518.999657)),
            (op: Point(point: [-0.7743805, 0.6184021], timestamp: 655_146_519.016245), position: PointInTime(x: -0.7743805, y: 0.6184021, t: 655_146_519.016245)),
            (op: Point(point: [-0.7733838, 0.6241449], timestamp: 655_146_519.032929), position: PointInTime(x: -0.7733838, y: 0.6241449, t: 655_146_519.032929)),
            (op: Point(point: [-0.7729063, 0.6288285], timestamp: 655_146_519.049648), position: PointInTime(x: -0.7729063, y: 0.6288285, t: 655_146_519.049648)),
            (op: Point(point: [-0.7729063, 0.63351214], timestamp: 655_146_519.066301), position: PointInTime(x: -0.7729063, y: 0.63351214, t: 655_146_519.066301)),
            (op: Point(point: [-0.7729063, 0.6372824], timestamp: 655_146_519.082897), position: PointInTime(x: -0.7729063, y: 0.6372824, t: 655_146_519.082897)),
            (op: Point(point: [-0.7729063, 0.641966], timestamp: 655_146_519.099607), position: PointInTime(x: -0.7729063, y: 0.641966, t: 655_146_519.099607)),
            (op: Point(point: [-0.7729063, 0.64807796], timestamp: 655_146_519.116345), position: PointInTime(x: -0.7729063, y: 0.64807796, t: 655_146_519.116345)),
            (op: Point(point: [-0.7738254, 0.6518385], timestamp: 655_146_519.133046), position: PointInTime(x: -0.7738254, y: 0.6518385, t: 655_146_519.133046)),
            (op: Point(point: [-0.77514446, 0.6546953], timestamp: 655_146_519.14989), position: PointInTime(x: -0.77514446, y: 0.6546953, t: 655_146_519.14989)),
            (op: Point(point: [-0.77598596, 0.65677476], timestamp: 655_146_519.166317), position: PointInTime(x: -0.77598596, y: 0.65677476, t: 655_146_519.166317)),
            (op: Point(point: [-0.7777406, 0.6589222], timestamp: 655_146_519.183039), position: PointInTime(x: -0.7777406, y: 0.6589222, t: 655_146_519.183039)),
            (op: Point(point: [-0.7794953, 0.66106963], timestamp: 655_146_519.199639), position: PointInTime(x: -0.7794953, y: 0.66106963, t: 655_146_519.199639)),
            (op: Point(point: [-0.782372, 0.6641985], timestamp: 655_146_519.216284), position: PointInTime(x: -0.782372, y: 0.6641985, t: 655_146_519.216284)),
            (op: Point(point: [-0.78524876, 0.6673274], timestamp: 655_146_519.232987), position: PointInTime(x: -0.78524876, y: 0.6673274, t: 655_146_519.232987)),
            (op: Point(point: [-0.78812546, 0.6704563], timestamp: 655_146_519.249777), position: PointInTime(x: -0.78812546, y: 0.6704563, t: 655_146_519.249777)),
            (op: Point(point: [-0.79100215, 0.67203045], timestamp: 655_146_519.266467), position: PointInTime(x: -0.79100215, y: 0.67203045, t: 655_146_519.266467)),
            (op: Point(point: [-0.79331195, 0.6735269], timestamp: 655_146_519.283118), position: PointInTime(x: -0.79331195, y: 0.6735269, t: 655_146_519.283118)),
            (op: Point(point: [-0.79618865, 0.67510104], timestamp: 655_146_519.299886), position: PointInTime(x: -0.79618865, y: 0.67510104, t: 655_146_519.299886)),
            (op: Point(point: [-0.79850435, 0.6758882], timestamp: 655_146_519.316366), position: PointInTime(x: -0.79850435, y: 0.6758882, t: 655_146_519.316366)),
            (op: Point(point: [-0.80082005, 0.6766752], timestamp: 655_146_519.333028), position: PointInTime(x: -0.80082005, y: 0.6766752, t: 655_146_519.333028)),
            (op: Point(point: [-0.80313575, 0.6766752], timestamp: 655_146_519.349657), position: PointInTime(x: -0.80313575, y: 0.6766752, t: 655_146_519.349657)),
            (op: Point(point: [-0.8048904, 0.6773943], timestamp: 655_146_519.366369), position: PointInTime(x: -0.8048904, y: 0.6773943, t: 655_146_519.366369)),
            (op: Point(point: [-0.8066451, 0.6773943], timestamp: 655_146_519.3828), position: PointInTime(x: -0.8066451, y: 0.6773943, t: 655_146_519.3828)),
            (op: Point(point: [-0.8079223, 0.6773943], timestamp: 655_146_519.399648), position: PointInTime(x: -0.8079223, y: 0.6773943, t: 655_146_519.399648)),
            (op: Point(point: [-0.81007683, 0.6773943], timestamp: 655_146_519.416565), position: PointInTime(x: -0.81007683, y: 0.6773943, t: 655_146_519.416565)),
            (op: Point(point: [-0.8113541, 0.6773943], timestamp: 655_146_519.433014), position: PointInTime(x: -0.8113541, y: 0.6773943, t: 655_146_519.433014)),
            (op: Point(point: [-0.8126313, 0.6773943], timestamp: 655_146_519.449878), position: PointInTime(x: -0.8126313, y: 0.6773943, t: 655_146_519.449878)),
            (op: Point(point: [-0.813431, 0.6773943], timestamp: 655_146_519.466064), position: PointInTime(x: -0.813431, y: 0.6773943, t: 655_146_519.466064)),
            (op: Point(point: [-0.81470823, 0.6767529], timestamp: 655_146_519.482941), position: PointInTime(x: -0.81470823, y: 0.6767529, t: 655_146_519.482941)),
            (op: Point(point: [-0.8159795, 0.675412], timestamp: 655_146_519.499609), position: PointInTime(x: -0.8159795, y: 0.675412, t: 655_146_519.499609)),
            (op: Point(point: [-0.81725675, 0.6740613], timestamp: 655_146_519.516354), position: PointInTime(x: -0.81725675, y: 0.6740613, t: 655_146_519.516354)),
            (op: Point(point: [-0.81853396, 0.67271066], timestamp: 655_146_519.53306), position: PointInTime(x: -0.81853396, y: 0.67271066, t: 655_146_519.53306)),
            (op: Point(point: [-0.8198052, 0.67136973], timestamp: 655_146_519.549722), position: PointInTime(x: -0.8198052, y: 0.67136973, t: 655_146_519.549722)),
            (op: Point(point: [-0.82155985, 0.66924167], timestamp: 655_146_519.566472), position: PointInTime(x: -0.82155985, y: 0.66924167, t: 655_146_519.566472)),
            (op: Point(point: [-0.8228311, 0.66790074], timestamp: 655_146_519.583241), position: PointInTime(x: -0.8228311, y: 0.66790074, t: 655_146_519.583241)),
            (op: Point(point: [-0.82410836, 0.66584074], timestamp: 655_146_519.600139), position: PointInTime(x: -0.82410836, y: 0.66584074, t: 655_146_519.600139)),
            (op: Point(point: [-0.8254273, 0.6637127], timestamp: 655_146_519.616635), position: PointInTime(x: -0.8254273, y: 0.6637127, t: 655_146_519.616635)),
            (op: Point(point: [-0.82669854, 0.66237175], timestamp: 655_146_519.633207), position: PointInTime(x: -0.82669854, y: 0.66237175, t: 655_146_519.633207)),
            (op: Point(point: [-0.8275401, 0.6603117], timestamp: 655_146_519.649884), position: PointInTime(x: -0.8275401, y: 0.6603117, t: 655_146_519.649884)),
            (op: Point(point: [-0.82838166, 0.65825176], timestamp: 655_146_519.666455), position: PointInTime(x: -0.82838166, y: 0.65825176, t: 655_146_519.666455)),
            (op: Point(point: [-0.82965887, 0.6561917], timestamp: 655_146_519.683077), position: PointInTime(x: -0.82965887, y: 0.6561917, t: 655_146_519.683077)),
            (op: Point(point: [-0.83090025, 0.65349036], timestamp: 655_146_519.699986), position: PointInTime(x: -0.83090025, y: 0.65349036, t: 655_146_519.699986)),
            (op: Point(point: [-0.83178353, 0.650653], timestamp: 655_146_519.716341), position: PointInTime(x: -0.83178353, y: 0.650653, t: 655_146_519.716341)),
            (op: Point(point: [-0.8331026, 0.648525], timestamp: 655_146_519.732951), position: PointInTime(x: -0.8331026, y: 0.648525, t: 655_146_519.732951)),
            (op: Point(point: [-0.8339381, 0.64647466], timestamp: 655_146_519.749565), position: PointInTime(x: -0.8339381, y: 0.64647466, t: 655_146_519.749565)),
            (op: Point(point: [-0.8347796, 0.64441466], timestamp: 655_146_519.766368), position: PointInTime(x: -0.8347796, y: 0.64441466, t: 655_146_519.766368)),
            (op: Point(point: [-0.83566296, 0.64157724], timestamp: 655_146_519.782995), position: PointInTime(x: -0.83566296, y: 0.64157724, t: 655_146_519.782995)),
            (op: Point(point: [-0.83650446, 0.6395173], timestamp: 655_146_519.799712), position: PointInTime(x: -0.83650446, y: 0.6395173, t: 655_146_519.799712)),
            (op: Point(point: [-0.8369461, 0.63745725], timestamp: 655_146_519.816329), position: PointInTime(x: -0.8369461, y: 0.63745725, t: 655_146_519.816329)),
            (op: Point(point: [-0.8373878, 0.63539726], timestamp: 655_146_519.832857), position: PointInTime(x: -0.8373878, y: 0.63539726, t: 655_146_519.832857)),
            (op: Point(point: [-0.8378295, 0.63333726], timestamp: 655_146_519.849628), position: PointInTime(x: -0.8378295, y: 0.63333726, t: 655_146_519.849628)),
            (op: Point(point: [-0.8378295, 0.6312772], timestamp: 655_146_519.866428), position: PointInTime(x: -0.8378295, y: 0.6312772, t: 655_146_519.866428)),
            (op: Point(point: [-0.8378295, 0.6298585], timestamp: 655_146_519.881024), position: PointInTime(x: -0.8378295, y: 0.6298585, t: 655_146_519.881024)),
            (op: PenUp(timestamp: 655_146_519.882041), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_519.882041)),
            (op: PenDown(color: [-0.35856336, 0.7281812, -0.13782531, 1.0], lineWidth: 0.01, timestamp: 655_146_520.605101, mode: PenDownMode.draw, portalName: ""), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_520.605101)),
            (op: Point(point: [-0.7579975, 0.59025186], timestamp: 655_146_520.605101), position: PointInTime(x: -0.7579975, y: 0.59025186, t: 655_146_520.605101)),
            (op: Point(point: [-0.7579975, 0.5908543], timestamp: 655_146_520.606809), position: PointInTime(x: -0.7579975, y: 0.5908543, t: 655_146_520.606809)),
            (op: Point(point: [-0.7579975, 0.5908543], timestamp: 655_146_520.616084), position: PointInTime(x: -0.7579975, y: 0.5908543, t: 655_146_520.616084)),
            (op: Point(point: [-0.7579975, 0.5908543], timestamp: 655_146_520.632537), position: PointInTime(x: -0.7579975, y: 0.5908543, t: 655_146_520.632537)),
            (op: Point(point: [-0.7579975, 0.5908543], timestamp: 655_146_520.6496), position: PointInTime(x: -0.7579975, y: 0.5908543, t: 655_146_520.6496)),
            (op: Point(point: [-0.7579975, 0.5908543], timestamp: 655_146_520.666409), position: PointInTime(x: -0.7579975, y: 0.5908543, t: 655_146_520.666409)),
            (op: Point(point: [-0.7579975, 0.5908543], timestamp: 655_146_520.681685), position: PointInTime(x: -0.7579975, y: 0.5908543, t: 655_146_520.681685)),
            (op: PenUp(timestamp: 655_146_520.683474), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_520.683474)),
        ]
        let second: [(DrawOperation, PointInTime)] = [
            (op: Viewport(bounds: [1309.0, 804.0], timestamp: 655_146_600.460454), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_600.460454)),
            (op: PenDown(color: [1.0698243, 0.51609313, -0.22119743, 1.0], lineWidth: 0.01, timestamp: 655_146_601.750639, mode: PenDownMode.draw, portalName: ""), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_601.750639)),
            (op: Point(point: [-0.5888858, 0.66615164], timestamp: 655_146_601.750639), position: PointInTime(x: -0.5888858, y: 0.66615164, t: 655_146_601.750639)),
            (op: Point(point: [-0.5888858, 0.66615164], timestamp: 655_146_601.766074), position: PointInTime(x: -0.5888858, y: 0.66615164, t: 655_146_601.766074)),
            (op: Point(point: [-0.5888858, 0.66615164], timestamp: 655_146_601.787352), position: PointInTime(x: -0.5888858, y: 0.66615164, t: 655_146_601.787352)),
            (op: Point(point: [-0.5888858, 0.66615164], timestamp: 655_146_601.799171), position: PointInTime(x: -0.5888858, y: 0.66615164, t: 655_146_601.799171)),
            (op: Point(point: [-0.5888858, 0.66615164], timestamp: 655_146_601.815984), position: PointInTime(x: -0.5888858, y: 0.66615164, t: 655_146_601.815984)),
            (op: Point(point: [-0.5888858, 0.66615164], timestamp: 655_146_601.832684), position: PointInTime(x: -0.5888858, y: 0.66615164, t: 655_146_601.832684)),
            (op: Point(point: [-0.5888858, 0.66615164], timestamp: 655_146_601.849706), position: PointInTime(x: -0.5888858, y: 0.66615164, t: 655_146_601.849706)),
            (op: Point(point: [-0.5888858, 0.66615164], timestamp: 655_146_601.866524), position: PointInTime(x: -0.5888858, y: 0.66615164, t: 655_146_601.866524)),
            (op: Point(point: [-0.5888858, 0.66615164], timestamp: 655_146_601.882891), position: PointInTime(x: -0.5888858, y: 0.66615164, t: 655_146_601.882891)),
            (op: Point(point: [-0.5888858, 0.66615164], timestamp: 655_146_601.899661), position: PointInTime(x: -0.5888858, y: 0.66615164, t: 655_146_601.899661)),
            (op: Point(point: [-0.5881398, 0.66615164], timestamp: 655_146_601.916554), position: PointInTime(x: -0.5881398, y: 0.66615164, t: 655_146_601.916554)),
            (op: Point(point: [-0.58397985, 0.66615164], timestamp: 655_146_601.932999), position: PointInTime(x: -0.58397985, y: 0.66615164, t: 655_146_601.932999)),
            (op: Point(point: [-0.5702707, 0.67151546], timestamp: 655_146_601.949919), position: PointInTime(x: -0.5702707, y: 0.67151546, t: 655_146_601.949919)),
            (op: Point(point: [-0.5626612, 0.67772466], timestamp: 655_146_601.966347), position: PointInTime(x: -0.5626612, y: 0.67772466, t: 655_146_601.966347)),
            (op: Point(point: [-0.5543115, 0.68407965], timestamp: 655_146_601.983061), position: PointInTime(x: -0.5543115, y: 0.68407965, t: 655_146_601.983061)),
            (op: Point(point: [-0.5483372, 0.69001675], timestamp: 655_146_601.999702), position: PointInTime(x: -0.5483372, y: 0.69001675, t: 655_146_601.999702)),
            (op: Point(point: [-0.5446488, 0.6943408], timestamp: 655_146_602.016436), position: PointInTime(x: -0.5446488, y: 0.6943408, t: 655_146_602.016436)),
            (op: Point(point: [-0.54334176, 0.6971976], timestamp: 655_146_602.033028), position: PointInTime(x: -0.54334176, y: 0.6971976, t: 655_146_602.033028)),
            (op: Point(point: [-0.5425599, 0.6978389], timestamp: 655_146_602.049718), position: PointInTime(x: -0.5425599, y: 0.6978389, t: 655_146_602.049718)),
            (op: Point(point: [-0.542166, 0.699141], timestamp: 655_146_602.066625), position: PointInTime(x: -0.542166, y: 0.699141, t: 655_146_602.066625)),
            (op: Point(point: [-0.542166, 0.699792], timestamp: 655_146_602.083064), position: PointInTime(x: -0.542166, y: 0.699792, t: 655_146_602.083064)),
            (op: Point(point: [-0.542166, 0.699792], timestamp: 655_146_602.099689), position: PointInTime(x: -0.542166, y: 0.699792, t: 655_146_602.099689)),
            (op: Point(point: [-0.542166, 0.699792], timestamp: 655_146_602.116485), position: PointInTime(x: -0.542166, y: 0.699792, t: 655_146_602.116485)),
            (op: Point(point: [-0.542166, 0.699792], timestamp: 655_146_602.133109), position: PointInTime(x: -0.542166, y: 0.699792, t: 655_146_602.133109)),
            (op: Point(point: [-0.54253006, 0.69861627], timestamp: 655_146_602.149771), position: PointInTime(x: -0.54253006, y: 0.69861627, t: 655_146_602.149771)),
            (op: Point(point: [-0.5434551, 0.6948655], timestamp: 655_146_602.166508), position: PointInTime(x: -0.5434551, y: 0.6948655, t: 655_146_602.166508)),
            (op: Point(point: [-0.54442203, 0.69020134], timestamp: 655_146_602.183365), position: PointInTime(x: -0.54442203, y: 0.69020134, t: 655_146_602.183365)),
            (op: Point(point: [-0.54590213, 0.6844877], timestamp: 655_146_602.200074), position: PointInTime(x: -0.54590213, y: 0.6844877, t: 655_146_602.200074)),
            (op: Point(point: [-0.54831934, 0.6666667], timestamp: 655_146_602.216561), position: PointInTime(x: -0.54831934, y: 0.6666667, t: 655_146_602.216561)),
            (op: Point(point: [-0.5503008, 0.6504489], timestamp: 655_146_602.233001), position: PointInTime(x: -0.5503008, y: 0.6504489, t: 655_146_602.233001)),
            (op: Point(point: [-0.55168545, 0.63243353], timestamp: 655_146_602.249648), position: PointInTime(x: -0.55168545, y: 0.63243353, t: 655_146_602.249648)),
            (op: Point(point: [-0.5531178, 0.6126691], timestamp: 655_146_602.266749), position: PointInTime(x: -0.5531178, y: 0.6126691, t: 655_146_602.266749)),
            (op: Point(point: [-0.5538579, 0.597355], timestamp: 655_146_602.283003), position: PointInTime(x: -0.5538579, y: 0.597355, t: 655_146_602.283003)),
            (op: Point(point: [-0.55450845, 0.5840719], timestamp: 655_146_602.299934), position: PointInTime(x: -0.55450845, y: 0.5840719, t: 655_146_602.299934)),
            (op: Point(point: [-0.5551172, 0.5736066], timestamp: 655_146_602.316682), position: PointInTime(x: -0.5551172, y: 0.5736066, t: 655_146_602.316682)),
            (op: Point(point: [-0.5556424, 0.5668241], timestamp: 655_146_602.333011), position: PointInTime(x: -0.5556424, y: 0.5668241, t: 655_146_602.333011)),
            (op: Point(point: [-0.5556424, 0.5621599], timestamp: 655_146_602.349781), position: PointInTime(x: -0.5556424, y: 0.5621599, t: 655_146_602.349781)),
            (op: Point(point: [-0.5556424, 0.55932254], timestamp: 655_146_602.366339), position: PointInTime(x: -0.5556424, y: 0.55932254, t: 655_146_602.366339)),
            (op: Point(point: [-0.55608404, 0.55726254], timestamp: 655_146_602.383313), position: PointInTime(x: -0.55608404, y: 0.55726254, t: 655_146_602.383313)),
            (op: Point(point: [-0.55608404, 0.55597985], timestamp: 655_146_602.399781), position: PointInTime(x: -0.55608404, y: 0.55597985, t: 655_146_602.399781)),
            (op: Point(point: [-0.55608404, 0.55597985], timestamp: 655_146_602.413792), position: PointInTime(x: -0.55608404, y: 0.55597985, t: 655_146_602.413792)),
            (op: PenUp(timestamp: 655_146_602.41482), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_602.41482)),
            (op: PenDown(color: [1.0698243, 0.51609313, -0.22119743, 1.0], lineWidth: 0.01, timestamp: 655_146_602.802706, mode: PenDownMode.draw, portalName: ""), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_602.802706)),
            (op: Point(point: [-0.522966, 0.57268345], timestamp: 655_146_602.802706), position: PointInTime(x: -0.522966, y: 0.57268345, t: 655_146_602.802706)),
            (op: Point(point: [-0.522966, 0.57268345], timestamp: 655_146_602.81601), position: PointInTime(x: -0.522966, y: 0.57268345, t: 655_146_602.81601)),
            (op: Point(point: [-0.522966, 0.57268345], timestamp: 655_146_602.832727), position: PointInTime(x: -0.522966, y: 0.57268345, t: 655_146_602.832727)),
            (op: Point(point: [-0.522966, 0.57268345], timestamp: 655_146_602.849658), position: PointInTime(x: -0.522966, y: 0.57268345, t: 655_146_602.849658)),
            (op: Point(point: [-0.522966, 0.57268345], timestamp: 655_146_602.866145), position: PointInTime(x: -0.522966, y: 0.57268345, t: 655_146_602.866145)),
            (op: PenUp(timestamp: 655_146_602.874949), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_602.874949)),
        ]
        let third: [(DrawOperation, PointInTime)] = [
            (op: Viewport(bounds: [1309.0, 804.0], timestamp: 655_146_703.376378), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_703.376378)),
            (op: PenDown(color: [1.0, 0.18573886, 0.573395, 1.0], lineWidth: 0.01, timestamp: 655_146_706.572619, mode: PenDownMode.draw, portalName: ""), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_706.572619)),
            (op: Point(point: [-0.38642925, 0.68455577], timestamp: 655_146_706.572619), position: PointInTime(x: -0.38642925, y: 0.68455577, t: 655_146_706.572619)),
            (op: Point(point: [-0.38642925, 0.68455577], timestamp: 655_146_706.582761), position: PointInTime(x: -0.38642925, y: 0.68455577, t: 655_146_706.582761)),
            (op: Point(point: [-0.38642925, 0.68455577], timestamp: 655_146_706.601182), position: PointInTime(x: -0.38642925, y: 0.68455577, t: 655_146_706.601182)),
            (op: Point(point: [-0.38642925, 0.68455577], timestamp: 655_146_706.616162), position: PointInTime(x: -0.38642925, y: 0.68455577, t: 655_146_706.616162)),
            (op: Point(point: [-0.38642925, 0.68455577], timestamp: 655_146_706.632789), position: PointInTime(x: -0.38642925, y: 0.68455577, t: 655_146_706.632789)),
            (op: Point(point: [-0.38642925, 0.68455577], timestamp: 655_146_706.649678), position: PointInTime(x: -0.38642925, y: 0.68455577, t: 655_146_706.649678)),
            (op: Point(point: [-0.38642925, 0.68455577], timestamp: 655_146_706.666193), position: PointInTime(x: -0.38642925, y: 0.68455577, t: 655_146_706.666193)),
            (op: Point(point: [-0.38642925, 0.68455577], timestamp: 655_146_706.683052), position: PointInTime(x: -0.38642925, y: 0.68455577, t: 655_146_706.683052)),
            (op: Point(point: [-0.38642925, 0.68455577], timestamp: 655_146_706.699855), position: PointInTime(x: -0.38642925, y: 0.68455577, t: 655_146_706.699855)),
            (op: Point(point: [-0.38642925, 0.68455577], timestamp: 655_146_706.716505), position: PointInTime(x: -0.38642925, y: 0.68455577, t: 655_146_706.716505)),
            (op: Point(point: [-0.38484764, 0.68455577], timestamp: 655_146_706.733406), position: PointInTime(x: -0.38484764, y: 0.68455577, t: 655_146_706.733406)),
            (op: Point(point: [-0.38115925, 0.68455577], timestamp: 655_146_706.750145), position: PointInTime(x: -0.38115925, y: 0.68455577, t: 655_146_706.750145)),
            (op: Point(point: [-0.37625927, 0.68455577], timestamp: 655_146_706.766601), position: PointInTime(x: -0.37625927, y: 0.68455577, t: 655_146_706.766601)),
            (op: Point(point: [-0.37119222, 0.68455577], timestamp: 655_146_706.783165), position: PointInTime(x: -0.37119222, y: 0.68455577, t: 655_146_706.783165)),
            (op: Point(point: [-0.3647405, 0.68455577], timestamp: 655_146_706.799843), position: PointInTime(x: -0.3647405, y: 0.68455577, t: 655_146_706.799843)),
            (op: Point(point: [-0.35902286, 0.68455577], timestamp: 655_146_706.816594), position: PointInTime(x: -0.35902286, y: 0.68455577, t: 655_146_706.816594)),
            (op: Point(point: [-0.3533888, 0.68455577], timestamp: 655_146_706.833067), position: PointInTime(x: -0.3533888, y: 0.68455577, t: 655_146_706.833067)),
            (op: Point(point: [-0.34775472, 0.68455577], timestamp: 655_146_706.849776), position: PointInTime(x: -0.34775472, y: 0.68455577, t: 655_146_706.849776)),
            (op: Point(point: [-0.34324265, 0.6790559], timestamp: 655_146_706.866386), position: PointInTime(x: -0.34324265, y: 0.6790559, t: 655_146_706.866386)),
            (op: Point(point: [-0.33988255, 0.6717584], timestamp: 655_146_706.883067), position: PointInTime(x: -0.33988255, y: 0.6717584, t: 655_146_706.883067)),
            (op: Point(point: [-0.3363791, 0.66216767], timestamp: 655_146_706.89976), position: PointInTime(x: -0.3363791, y: 0.66216767, t: 655_146_706.89976)),
            (op: Point(point: [-0.33404553, 0.64694107], timestamp: 655_146_706.916515), position: PointInTime(x: -0.33404553, y: 0.64694107, t: 655_146_706.916515)),
            (op: Point(point: [-0.33331144, 0.63279307], timestamp: 655_146_706.933048), position: PointInTime(x: -0.33331144, y: 0.63279307, t: 655_146_706.933048)),
            (op: Point(point: [-0.33331144, 0.62095773], timestamp: 655_146_706.949969), position: PointInTime(x: -0.33331144, y: 0.62095773, t: 655_146_706.949969)),
            (op: Point(point: [-0.33331144, 0.60859764], timestamp: 655_146_706.966356), position: PointInTime(x: -0.33331144, y: 0.60859764, t: 655_146_706.966356)),
            (op: Point(point: [-0.33599716, 0.5936723], timestamp: 655_146_706.983221), position: PointInTime(x: -0.33599716, y: 0.5936723, t: 655_146_706.983221)),
            (op: Point(point: [-0.34041965, 0.5814191], timestamp: 655_146_707.000045), position: PointInTime(x: -0.34041965, y: 0.5814191, t: 655_146_707.000045)),
            (op: Point(point: [-0.34691316, 0.56980723], timestamp: 655_146_707.016825), position: PointInTime(x: -0.34691316, y: 0.56980723, t: 655_146_707.016825)),
            (op: Point(point: [-0.35224885, 0.5628401], timestamp: 655_146_707.03358), position: PointInTime(x: -0.35224885, y: 0.5628401, t: 655_146_707.03358)),
            (op: Point(point: [-0.35895717, 0.5548333], timestamp: 655_146_707.050039), position: PointInTime(x: -0.35895717, y: 0.5548333, t: 655_146_707.050039)),
            (op: Point(point: [-0.36542088, 0.55004275], timestamp: 655_146_707.066425), position: PointInTime(x: -0.36542088, y: 0.55004275, t: 655_146_707.066425)),
            (op: Point(point: [-0.37188452, 0.5471568], timestamp: 655_146_707.083207), position: PointInTime(x: -0.37188452, y: 0.5471568, t: 655_146_707.083207)),
            (op: Point(point: [-0.3760504, 0.54632115], timestamp: 655_146_707.099855), position: PointInTime(x: -0.3760504, y: 0.54632115, t: 655_146_707.099855)),
            (op: Point(point: [-0.37957764, 0.54632115], timestamp: 655_146_707.116316), position: PointInTime(x: -0.37957764, y: 0.54632115, t: 655_146_707.116316)),
            (op: Point(point: [-0.3808549, 0.54697216], timestamp: 655_146_707.133436), position: PointInTime(x: -0.3808549, y: 0.54697216, t: 655_146_707.133436)),
            (op: Point(point: [-0.38133234, 0.5516461], timestamp: 655_146_707.149828), position: PointInTime(x: -0.38133234, y: 0.5516461, t: 655_146_707.149828)),
            (op: Point(point: [-0.38133234, 0.5563297], timestamp: 655_146_707.166681), position: PointInTime(x: -0.38133234, y: 0.5563297, t: 655_146_707.166681)),
            (op: Point(point: [-0.38046098, 0.5615283], timestamp: 655_146_707.183248), position: PointInTime(x: -0.38046098, y: 0.5615283, t: 655_146_707.183248)),
            (op: Point(point: [-0.37816316, 0.56302476], timestamp: 655_146_707.200307), position: PointInTime(x: -0.37816316, y: 0.56302476, t: 655_146_707.200307)),
            (op: Point(point: [-0.37585944, 0.56453085], timestamp: 655_146_707.216484), position: PointInTime(x: -0.37585944, y: 0.56453085, t: 655_146_707.216484)),
            (op: Point(point: [-0.37234408, 0.56538594], timestamp: 655_146_707.233442), position: PointInTime(x: -0.37234408, y: 0.56538594, t: 655_146_707.233442)),
            (op: Point(point: [-0.36882877, 0.56538594], timestamp: 655_146_707.250103), position: PointInTime(x: -0.36882877, y: 0.56538594, t: 655_146_707.250103)),
            (op: Point(point: [-0.3639288, 0.56538594], timestamp: 655_146_707.266426), position: PointInTime(x: -0.3639288, y: 0.56538594, t: 655_146_707.266426)),
            (op: Point(point: [-0.35829473, 0.56538594], timestamp: 655_146_707.283107), position: PointInTime(x: -0.35829473, y: 0.56538594, t: 655_146_707.283107)),
            (op: Point(point: [-0.35266066, 0.56538594], timestamp: 655_146_707.300329), position: PointInTime(x: -0.35266066, y: 0.56538594, t: 655_146_707.300329)),
            (op: Point(point: [-0.34776664, 0.5636952], timestamp: 655_146_707.316377), position: PointInTime(x: -0.34776664, y: 0.5636952, t: 655_146_707.316377)),
            (op: Point(point: [-0.34343964, 0.55926424], timestamp: 655_146_707.333162), position: PointInTime(x: -0.34343964, y: 0.55926424, t: 655_146_707.333162)),
            (op: Point(point: [-0.34113586, 0.55629086], timestamp: 655_146_707.349803), position: PointInTime(x: -0.34113586, y: 0.55629086, t: 655_146_707.349803)),
            (op: Point(point: [-0.33874857, 0.55240405], timestamp: 655_146_707.366407), position: PointInTime(x: -0.33874857, y: 0.55240405, t: 655_146_707.366407)),
            (op: Point(point: [-0.33791894, 0.550344], timestamp: 655_146_707.383078), position: PointInTime(x: -0.33791894, y: 0.550344, t: 655_146_707.383078)),
            (op: Point(point: [-0.33665365, 0.54899335], timestamp: 655_146_707.399839), position: PointInTime(x: -0.33665365, y: 0.54899335, t: 655_146_707.399839)),
            (op: Point(point: [-0.33587182, 0.54772043], timestamp: 655_146_707.416535), position: PointInTime(x: -0.33587182, y: 0.54772043, t: 655_146_707.416535)),
            (op: Point(point: [-0.33547795, 0.5470791], timestamp: 655_146_707.429303), position: PointInTime(x: -0.33547795, y: 0.5470791, t: 655_146_707.429303)),
            (op: PenUp(timestamp: 655_146_707.430148), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_707.430148)),
            (op: PenDown(color: [1.0, 0.18573886, 0.573395, 1.0], lineWidth: 0.01, timestamp: 655_146_707.817853, mode: PenDownMode.draw, portalName: ""), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_707.817853)),
            (op: Point(point: [-0.2930075, 0.57147855], timestamp: 655_146_707.817853), position: PointInTime(x: -0.2930075, y: 0.57147855, t: 655_146_707.817853)),
            (op: Point(point: [-0.2930075, 0.57147855], timestamp: 655_146_707.833116), position: PointInTime(x: -0.2930075, y: 0.57147855, t: 655_146_707.833116)),
            (op: Point(point: [-0.2930075, 0.57147855], timestamp: 655_146_707.849587), position: PointInTime(x: -0.2930075, y: 0.57147855, t: 655_146_707.849587)),
            (op: Point(point: [-0.2930075, 0.57147855], timestamp: 655_146_707.866663), position: PointInTime(x: -0.2930075, y: 0.57147855, t: 655_146_707.866663)),
            (op: Point(point: [-0.2930075, 0.57147855], timestamp: 655_146_707.883204), position: PointInTime(x: -0.2930075, y: 0.57147855, t: 655_146_707.883204)),
            (op: PenUp(timestamp: 655_146_707.892707), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_707.892707)),
        ]
        let fourth: [(DrawOperation, PointInTime)] = [
            (op: Viewport(bounds: [1309.0, 804.0], timestamp: 655_146_762.666182), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_762.666182)),
            (op: PenDown(color: [0.9544073, 0.8622802, -0.3009252, 1.0], lineWidth: 0.01, timestamp: 655_146_765.026588, mode: PenDownMode.draw, portalName: ""), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_765.026588)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.026588), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.026588)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.032862), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.032862)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.051233), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.051233)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.066212), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.066212)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.082885), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.082885)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.099871), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.099871)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.116518), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.116518)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.133108), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.133108)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.149791), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.149791)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.166576), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.166576)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.183292), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.183292)),
            (op: Point(point: [-0.18471873, 0.68205845], timestamp: 655_146_765.199878), position: PointInTime(x: -0.18471873, y: 0.68205845, t: 655_146_765.199878)),
            (op: Point(point: [-0.1825403, 0.68205845], timestamp: 655_146_765.216614), position: PointInTime(x: -0.1825403, y: 0.68205845, t: 655_146_765.216614)),
            (op: Point(point: [-0.18023658, 0.68205845], timestamp: 655_146_765.233123), position: PointInTime(x: -0.18023658, y: 0.68205845, t: 655_146_765.233123)),
            (op: Point(point: [-0.17793876, 0.68205845], timestamp: 655_146_765.24989), position: PointInTime(x: -0.17793876, y: 0.68205845, t: 655_146_765.24989)),
            (op: Point(point: [-0.17564094, 0.68205845], timestamp: 655_146_765.266558), position: PointInTime(x: -0.17564094, y: 0.68205845, t: 655_146_765.266558)),
            (op: Point(point: [-0.17277616, 0.68205845], timestamp: 655_146_765.283245), position: PointInTime(x: -0.17277616, y: 0.68205845, t: 655_146_765.283245)),
            (op: Point(point: [-0.16991138, 0.68205845], timestamp: 655_146_765.299991), position: PointInTime(x: -0.16991138, y: 0.68205845, t: 655_146_765.299991)),
            (op: Point(point: [-0.1680851, 0.68205845], timestamp: 655_146_765.316603), position: PointInTime(x: -0.1680851, y: 0.68205845, t: 655_146_765.316603)),
            (op: Point(point: [-0.16522032, 0.6805037], timestamp: 655_146_765.333334), position: PointInTime(x: -0.16522032, y: 0.6805037, t: 655_146_765.333334)),
            (op: Point(point: [-0.16291654, 0.6775303], timestamp: 655_146_765.350268), position: PointInTime(x: -0.16291654, y: 0.6775303, t: 655_146_765.350268)),
            (op: Point(point: [-0.16117382, 0.674693], timestamp: 655_146_765.366544), position: PointInTime(x: -0.16117382, y: 0.674693, t: 655_146_765.366544)),
            (op: Point(point: [-0.1594311, 0.67185557], timestamp: 655_146_765.3833), position: PointInTime(x: -0.1594311, y: 0.67185557, t: 655_146_765.3833)),
            (op: Point(point: [-0.15855968, 0.6690182], timestamp: 655_146_765.400166), position: PointInTime(x: -0.15855968, y: 0.6690182, t: 655_146_765.400166)),
            (op: Point(point: [-0.15764654, 0.6652674], timestamp: 655_146_765.416619), position: PointInTime(x: -0.15764654, y: 0.6652674, t: 655_146_765.416619)),
            (op: Point(point: [-0.1567334, 0.66151667], timestamp: 655_146_765.433442), position: PointInTime(x: -0.1567334, y: 0.66151667, t: 655_146_765.433442)),
            (op: Point(point: [-0.1563037, 0.658689], timestamp: 655_146_765.450183), position: PointInTime(x: -0.1563037, y: 0.658689, t: 655_146_765.450183)),
            (op: Point(point: [-0.1563037, 0.6558516], timestamp: 655_146_765.466566), position: PointInTime(x: -0.1563037, y: 0.6558516, t: 655_146_765.466566)),
            (op: Point(point: [-0.1563037, 0.6511874], timestamp: 655_146_765.483258), position: PointInTime(x: -0.1563037, y: 0.6511874, t: 655_146_765.483258)),
            (op: Point(point: [-0.15678114, 0.6431806], timestamp: 655_146_765.500155), position: PointInTime(x: -0.15678114, y: 0.6431806, t: 655_146_765.500155)),
            (op: Point(point: [-0.15952063, 0.63611627], timestamp: 655_146_765.516733), position: PointInTime(x: -0.15952063, y: 0.63611627, t: 655_146_765.516733)),
            (op: Point(point: [-0.16277927, 0.62990713], timestamp: 655_146_765.53313), position: PointInTime(x: -0.16277927, y: 0.62990713, t: 655_146_765.53313)),
            (op: Point(point: [-0.16603202, 0.62370765], timestamp: 655_146_765.549936), position: PointInTime(x: -0.16603202, y: 0.62370765, t: 655_146_765.549936)),
            (op: Point(point: [-0.16917133, 0.6186159], timestamp: 655_146_765.566578), position: PointInTime(x: -0.16917133, y: 0.6186159, t: 655_146_765.566578)),
            (op: Point(point: [-0.17287171, 0.6143113], timestamp: 655_146_765.583387), position: PointInTime(x: -0.17287171, y: 0.6143113, t: 655_146_765.583387)),
            (op: Point(point: [-0.17518741, 0.61133784], timestamp: 655_146_765.600087), position: PointInTime(x: -0.17518741, y: 0.61133784, t: 655_146_765.600087)),
            (op: Point(point: [-0.17805815, 0.60901546], timestamp: 655_146_765.616617), position: PointInTime(x: -0.17805815, y: 0.60901546, t: 655_146_765.616617)),
            (op: Point(point: [-0.17981279, 0.60688746], timestamp: 655_146_765.633529), position: PointInTime(x: -0.17981279, y: 0.60688746, t: 655_146_765.633529)),
            (op: Point(point: [-0.18156749, 0.60546875], timestamp: 655_146_765.65007), position: PointInTime(x: -0.18156749, y: 0.60546875, t: 655_146_765.65007)),
            (op: Point(point: [-0.18236125, 0.6048372], timestamp: 655_146_765.667078), position: PointInTime(x: -0.18236125, y: 0.6048372, t: 655_146_765.667078)),
            (op: Point(point: [-0.18363851, 0.60412776], timestamp: 655_146_765.683559), position: PointInTime(x: -0.18363851, y: 0.60412776, t: 655_146_765.683559)),
            (op: Point(point: [-0.1840145, 0.60412776], timestamp: 655_146_765.700022), position: PointInTime(x: -0.1840145, y: 0.60412776, t: 655_146_765.700022)),
            (op: Point(point: [-0.18439049, 0.60412776], timestamp: 655_146_765.716717), position: PointInTime(x: -0.18439049, y: 0.60412776, t: 655_146_765.716717)),
            (op: Point(point: [-0.18439049, 0.60412776], timestamp: 655_146_765.7334), position: PointInTime(x: -0.18439049, y: 0.60412776, t: 655_146_765.7334)),
            (op: Point(point: [-0.18439049, 0.6075871], timestamp: 655_146_765.750109), position: PointInTime(x: -0.18439049, y: 0.6075871, t: 655_146_765.750109)),
            (op: Point(point: [-0.18395483, 0.6104439], timestamp: 655_146_765.766445), position: PointInTime(x: -0.18395483, y: 0.6104439, t: 655_146_765.766445)),
            (op: Point(point: [-0.18221205, 0.6125914], timestamp: 655_146_765.783223), position: PointInTime(x: -0.18221205, y: 0.6125914, t: 655_146_765.783223)),
            (op: Point(point: [-0.18046933, 0.61402947], timestamp: 655_146_765.799886), position: PointInTime(x: -0.18046933, y: 0.61402947, t: 655_146_765.799886)),
            (op: Point(point: [-0.17760456, 0.6156036], timestamp: 655_146_765.816485), position: PointInTime(x: -0.17760456, y: 0.6156036, t: 655_146_765.816485)),
            (op: Point(point: [-0.17465025, 0.6163227], timestamp: 655_146_765.833307), position: PointInTime(x: -0.17465025, y: 0.6163227, t: 655_146_765.833307)),
            (op: Point(point: [-0.17113489, 0.61796486], timestamp: 655_146_765.85024), position: PointInTime(x: -0.17113489, y: 0.61796486, t: 655_146_765.85024)),
            (op: Point(point: [-0.16550082, 0.618888], timestamp: 655_146_765.866537), position: PointInTime(x: -0.16550082, y: 0.618888, t: 655_146_765.866537)),
            (op: Point(point: [-0.1590491, 0.6198791], timestamp: 655_146_765.883346), position: PointInTime(x: -0.1590491, y: 0.6198791, t: 655_146_765.883346)),
            (op: Point(point: [-0.15341502, 0.6208023], timestamp: 655_146_765.900013), position: PointInTime(x: -0.15341502, y: 0.6208023, t: 655_146_765.900013)),
            (op: Point(point: [-0.14614564, 0.6208023], timestamp: 655_146_765.916607), position: PointInTime(x: -0.14614564, y: 0.6208023, t: 655_146_765.916607)),
            (op: Point(point: [-0.14051753, 0.6208023], timestamp: 655_146_765.93323), position: PointInTime(x: -0.14051753, y: 0.6208023, t: 655_146_765.93323)),
            (op: Point(point: [-0.13635164, 0.6208023], timestamp: 655_146_765.950212), position: PointInTime(x: -0.13635164, y: 0.6208023, t: 655_146_765.950212)),
            (op: Point(point: [-0.13348687, 0.6208023], timestamp: 655_146_765.966619), position: PointInTime(x: -0.13348687, y: 0.6208023, t: 655_146_765.966619)),
            (op: Point(point: [-0.13174415, 0.6208023], timestamp: 655_146_765.983263), position: PointInTime(x: -0.13174415, y: 0.6208023, t: 655_146_765.983263)),
            (op: Point(point: [-0.13047886, 0.6208023], timestamp: 655_146_765.999873), position: PointInTime(x: -0.13047886, y: 0.6208023, t: 655_146_765.999873)),
            (op: Point(point: [-0.12969106, 0.6208023], timestamp: 655_146_766.016897), position: PointInTime(x: -0.12969106, y: 0.6208023, t: 655_146_766.016897)),
            (op: Point(point: [-0.12929714, 0.6195293], timestamp: 655_146_766.033316), position: PointInTime(x: -0.12929714, y: 0.6195293, t: 655_146_766.033316)),
            (op: Point(point: [-0.12929714, 0.61761504], timestamp: 655_146_766.050042), position: PointInTime(x: -0.12929714, y: 0.61761504, t: 655_146_766.050042)),
            (op: Point(point: [-0.12929714, 0.6163324], timestamp: 655_146_766.066655), position: PointInTime(x: -0.12929714, y: 0.6163324, t: 655_146_766.066655)),
            (op: Point(point: [-0.12929714, 0.61427236], timestamp: 655_146_766.083209), position: PointInTime(x: -0.12929714, y: 0.61427236, t: 655_146_766.083209)),
            (op: Point(point: [-0.12929714, 0.61143506], timestamp: 655_146_766.099948), position: PointInTime(x: -0.12929714, y: 0.61143506, t: 655_146_766.099948)),
            (op: Point(point: [-0.12929714, 0.60860735], timestamp: 655_146_766.116661), position: PointInTime(x: -0.12929714, y: 0.60860735, t: 655_146_766.116661)),
            (op: Point(point: [-0.12929714, 0.60394317], timestamp: 655_146_766.133517), position: PointInTime(x: -0.12929714, y: 0.60394317, t: 655_146_766.133517)),
            (op: Point(point: [-0.12929714, 0.59927905], timestamp: 655_146_766.149926), position: PointInTime(x: -0.12929714, y: 0.59927905, t: 655_146_766.149926)),
            (op: Point(point: [-0.12978059, 0.59461486], timestamp: 655_146_766.166932), position: PointInTime(x: -0.12978059, y: 0.59461486, t: 655_146_766.166932)),
            (op: Point(point: [-0.13074744, 0.5899507], timestamp: 655_146_766.183695), position: PointInTime(x: -0.13074744, y: 0.5899507, t: 655_146_766.183695)),
            (op: Point(point: [-0.13227534, 0.5842273], timestamp: 655_146_766.199924), position: PointInTime(x: -0.13227534, y: 0.5842273, t: 655_146_766.199924)),
            (op: Point(point: [-0.13371968, 0.57956314], timestamp: 655_146_766.216775), position: PointInTime(x: -0.13371968, y: 0.57956314, t: 655_146_766.216775)),
            (op: Point(point: [-0.13555789, 0.57581234], timestamp: 655_146_766.233426), position: PointInTime(x: -0.13555789, y: 0.57581234, t: 655_146_766.233426)),
            (op: Point(point: [-0.13738418, 0.57208097], timestamp: 655_146_766.24992), position: PointInTime(x: -0.13738418, y: 0.57208097, t: 655_146_766.24992)),
            (op: Point(point: [-0.13968796, 0.5698947], timestamp: 655_146_766.266712), position: PointInTime(x: -0.13968796, y: 0.5698947, t: 655_146_766.266712)),
            (op: Point(point: [-0.14200366, 0.56763065], timestamp: 655_146_766.283375), position: PointInTime(x: -0.14200366, y: 0.56763065, t: 655_146_766.283375)),
            (op: Point(point: [-0.14550704, 0.5651819], timestamp: 655_146_766.300008), position: PointInTime(x: -0.14550704, y: 0.5651819, t: 655_146_766.300008)),
            (op: Point(point: [-0.14968485, 0.56180036], timestamp: 655_146_766.316718), position: PointInTime(x: -0.14968485, y: 0.56180036, t: 655_146_766.316718)),
            (op: Point(point: [-0.15383875, 0.56011933], timestamp: 655_146_766.333387), position: PointInTime(x: -0.15383875, y: 0.56011933, t: 655_146_766.333387)),
            (op: Point(point: [-0.16014129, 0.55760264], timestamp: 655_146_766.349734), position: PointInTime(x: -0.16014129, y: 0.55760264, t: 655_146_766.349734)),
            (op: Point(point: [-0.16301805, 0.5560479], timestamp: 655_146_766.36609), position: PointInTime(x: -0.16301805, y: 0.5560479, t: 655_146_766.36609)),
            (op: Point(point: [-0.16653931, 0.5560479], timestamp: 655_146_766.382818), position: PointInTime(x: -0.16653931, y: 0.5560479, t: 655_146_766.382818)),
            (op: Point(point: [-0.16941601, 0.55527055], timestamp: 655_146_766.399352), position: PointInTime(x: -0.16941601, y: 0.55527055, t: 655_146_766.399352)),
            (op: Point(point: [-0.1729433, 0.55527055], timestamp: 655_146_766.416054), position: PointInTime(x: -0.1729433, y: 0.55527055, t: 655_146_766.416054)),
            (op: Point(point: [-0.17582, 0.55527055], timestamp: 655_146_766.432858), position: PointInTime(x: -0.17582, y: 0.55527055, t: 655_146_766.432858)),
            (op: Point(point: [-0.17869675, 0.55527055], timestamp: 655_146_766.449581), position: PointInTime(x: -0.17869675, y: 0.55527055, t: 655_146_766.449581)),
            (op: Point(point: [-0.1804514, 0.557418], timestamp: 655_146_766.466142), position: PointInTime(x: -0.1804514, y: 0.557418, t: 655_146_766.466142)),
            (op: Point(point: [-0.1828984, 0.56140196], timestamp: 655_146_766.483339), position: PointInTime(x: -0.1828984, y: 0.56140196, t: 655_146_766.483339)),
            (op: Point(point: [-0.18459344, 0.56599814], timestamp: 655_146_766.4982), position: PointInTime(x: -0.18459344, y: 0.56599814, t: 655_146_766.4982)),
            (op: PenUp(timestamp: 655_146_766.499632), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_766.499632)),
            (op: PenDown(color: [0.9544073, 0.8622802, -0.3009252, 1.0], lineWidth: 0.01, timestamp: 655_146_767.027286, mode: PenDownMode.draw, portalName: ""), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_767.027286)),
            (op: Point(point: [-0.08776975, 0.55558145], timestamp: 655_146_767.027286), position: PointInTime(x: -0.08776975, y: 0.55558145, t: 655_146_767.027286)),
            (op: Point(point: [-0.088157654, 0.55558145], timestamp: 655_146_767.029546), position: PointInTime(x: -0.088157654, y: 0.55558145, t: 655_146_767.029546)),
            (op: Point(point: [-0.088157654, 0.55558145], timestamp: 655_146_767.032808), position: PointInTime(x: -0.088157654, y: 0.55558145, t: 655_146_767.032808)),
            (op: Point(point: [-0.088157654, 0.55558145], timestamp: 655_146_767.049389), position: PointInTime(x: -0.088157654, y: 0.55558145, t: 655_146_767.049389)),
            (op: Point(point: [-0.088157654, 0.55558145], timestamp: 655_146_767.066241), position: PointInTime(x: -0.088157654, y: 0.55558145, t: 655_146_767.066241)),
            (op: Point(point: [-0.088157654, 0.55558145], timestamp: 655_146_767.083329), position: PointInTime(x: -0.088157654, y: 0.55558145, t: 655_146_767.083329)),
            (op: Point(point: [-0.088157654, 0.55558145], timestamp: 655_146_767.100041), position: PointInTime(x: -0.088157654, y: 0.55558145, t: 655_146_767.100041)),
            (op: Point(point: [-0.088157654, 0.55558145], timestamp: 655_146_767.116663), position: PointInTime(x: -0.088157654, y: 0.55558145, t: 655_146_767.116663)),
            (op: PenUp(timestamp: 655_146_767.126176), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_767.126176)),
        ]
        XCTAssertEqual(first.count, 107)
        XCTAssertEqual(second.count, 51)
        XCTAssertEqual(third.count, 63)
        XCTAssertEqual(fourth.count, 103)

        let filename = "Harder"

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        let recording = Recording(name: filename)
        for (op, position) in first {
            recording.addOp(op: op, position: position)
        }
        recording.serialize(filename: filename)
        recording.close()

        let recording2 = Recording(name: filename)
        recording2.deserialize(filename: filename)
        let expectedOpCount2 = first.count
        XCTAssertEqual(recording2.opList.count, expectedOpCount2)
        XCTAssertEqual(recording2.shapeList.count, 2)
        XCTAssertEqual(recording2.timestamps.count, expectedOpCount2)
        for (op, position) in second {
            recording2.addOp(op: op, position: position)
        }
        recording2.serialize(filename: filename)
        recording2.close()

        let recording3 = Recording(name: filename)
        recording3.deserialize(filename: filename)
        let expectedOpCount3 = first.count + second.count
        XCTAssertEqual(recording3.opList.count, expectedOpCount3)
        XCTAssertEqual(recording3.shapeList.count, 4)
        XCTAssertEqual(recording3.timestamps.count, expectedOpCount3)
        for (op, position) in third {
            recording3.addOp(op: op, position: position)
        }
        recording3.serialize(filename: filename)
        recording3.close()

        let recording4 = Recording(name: filename)
        recording4.deserialize(filename: filename)
        let expectedOpCount4 = first.count + second.count + third.count
        XCTAssertEqual(recording4.opList.count, expectedOpCount4)
        XCTAssertEqual(recording4.shapeList.count, 6)
        XCTAssertEqual(recording4.timestamps.count, expectedOpCount4)
        for (op, position) in fourth {
            recording4.addOp(op: op, position: position)
        }
        recording4.serialize(filename: filename)
        recording4.close()

        let recording5 = Recording(name: filename)
        recording5.deserialize(filename: filename)
        let expectedOpCount5 = first.count + second.count + third.count + fourth.count
        XCTAssertEqual(recording5.opList.count, expectedOpCount5)
        XCTAssertEqual(recording5.shapeList.count, 8)
        XCTAssertEqual(recording5.timestamps.count, expectedOpCount5)
        recording5.close()
    }

    func testBigBucket() {
        let first: [(DrawOperation, PointInTime)] = [
            (op: PenDown(color: [0.9544073, 0.8622802, -0.3009252, 1.0], lineWidth: 0.01, timestamp: 655_146_765.026588, mode: PenDownMode.draw, portalName: ""), position: PointInTime(x: 0.0, y: 0.0, t: 655_146_765.026588)),
        ]

        let filename = "Larder"

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        let recording = Recording(name: filename)
        for (op, position) in first {
            recording.addOp(op: op, position: position)
        }

        XCTAssertEqual(recording.opList.count, 1)
        XCTAssertEqual(recording.shapeList.count, 1)
        XCTAssertEqual(recording.timestamps.count, 1)
        recording.serialize(filename: filename)
        recording.close()

        let recording2 = Recording(name: filename)
        recording2.deserialize(filename: filename)
        XCTAssertEqual(recording2.opList.count, 1)
        XCTAssertEqual(recording2.shapeList.count, 1)
        XCTAssertEqual(recording2.timestamps.count, 1)
        recording2.serialize(filename: filename)
        recording2.close()
    }
}
