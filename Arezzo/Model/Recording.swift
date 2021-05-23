//
//  DrawOperationCollector.swift
//  Arezzo
//
//  Created by Max Harris on 9/3/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import BinaryCoder
import CoreGraphics
import Foundation
import Metal

enum PenState {
    case down, up
}

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

class Recording {
    var opList: [DrawOperation] = []
    var shapeList: [Shape] = []
    var provisionalShapeIndex = 0
    var provisionalOpIndex = 0
    var provisionalTimestampIndex = 0
    var activeColor: [Float] = []
    var currentLineWidth = DEFAULT_LINE_WIDTH

    var penState: PenState = .down
    var timestamps: [Double] = [] // TODO: remove
    var name: String = ""
    var recordingIndex: RecordingIndex
    var undoLevel: Int = 0
    var undoable: Bool = false
    var redoable: Bool = false

    init(name: String, recordingIndex: RecordingIndex) {
        self.name = name
        self.recordingIndex = recordingIndex
    }

    func getTimestamp(position: Double) -> Double {
        let first = self.timestamps.first!
        let last = self.timestamps.last!

        let total = last - first
        let targetTimestamp = (total * position) + first
        let targetTimestampIndex = self.timestamps.firstIndex(where: { $0 >= targetTimestamp })!
        return self.timestamps[targetTimestampIndex]
    }

    // TODO: remove?
    func getTimestampIndices(startPosition: Double, endPosition: Double) -> (startIndex: Int, endIndex: Int) {
        let first = self.timestamps.first!
        let last = self.timestamps.last!

        let total = last - first
        let targetTimestampStart = (total * startPosition) + first
        let targetTimestampEnd = (total * endPosition) + first

        let startIndex = self.timestamps.firstIndex(where: { $0 >= targetTimestampStart })!
        let endIndex = self.timestamps.firstIndex(where: { $0 >= targetTimestampEnd })!

        return (startIndex, endIndex)
    }

    // TODO: remove?
    func getTimestampIterator(startIndex: Int, endIndex: Int) -> TimestampIterator {
        Timestamps(timestamps: Array(self.timestamps[startIndex ..< endIndex])).makeIterator()
    }

    func addOp(op: DrawOperation) {
        self.opList.append(op)
        self.timestamps.append(op.timestamp)

        if op.type == .penDown {
            let penDownOp = op as! PenDown
            self.penState = .down

            if penDownOp.mode == PenDownMode.draw {
                if self.shapeList.count > 0 {
                    let lastShape = self.shapeList[self.shapeList.count - 1]
                    if lastShape.type == .undo || lastShape.type == .redo {
                        self.undoable = false
                        self.redoable = self.undoLevel > 0
                    }
                }
                self.activeColor = penDownOp.color
                self.currentLineWidth = penDownOp.lineWidth
                self.shapeList.append(Shape(type: DrawOperationType.line))
            } else if penDownOp.mode == PenDownMode.pan {
                self.shapeList.append(Shape(type: DrawOperationType.pan))
            } else if penDownOp.mode == PenDownMode.portal {
                self.activeColor = penDownOp.color
                self.currentLineWidth = penDownOp.lineWidth
                let newShape = Shape(type: DrawOperationType.portal)
                newShape.name = penDownOp.portalName
                self.shapeList.append(newShape)
            } else {
                print("unhandled mode:", penDownOp.mode)
            }
        } else if op.type == .pan {
            let lastShape = self.shapeList[self.shapeList.count - 1]
            let panOp = op as! Pan
            lastShape.addShapePoint(point: panOp.point, timestamp: panOp.timestamp, color: [0.8, 0.7, 0.6, 1.0], lineWidth: DEFAULT_LINE_WIDTH)
        } else if op.type == .point, self.penState == .down {
            let lastShape = self.shapeList[self.shapeList.count - 1]
            let pointOp = op as! Point
            lastShape.addShapePoint(point: pointOp.point, timestamp: pointOp.timestamp, color: self.activeColor, lineWidth: self.currentLineWidth)
        } else if op.type == .portal {
            let lastShape = self.shapeList[self.shapeList.count - 1]
            let portalOp = op as! Portal
            lastShape.addShapePoint(point: portalOp.point, timestamp: portalOp.timestamp, color: self.activeColor, lineWidth: self.currentLineWidth)
        } else if op.type == .penUp {
            self.penState = .up
            self.undoable = true
            self.redoable = self.undoLevel > 0
        } else if op.type == .audioClip {
        } else if op.type == .undo {
            self.undoLevel += 1
            let undoShape = Shape(type: DrawOperationType.undo)
            undoShape.timestamp.append(op.timestamp)
            self.shapeList.append(undoShape)
        } else if op.type == .redo {
            self.undoLevel -= 1
            let redoShape = Shape(type: DrawOperationType.redo)
            redoShape.timestamp.append(op.timestamp)
            self.shapeList.append(redoShape)
        } else {
            print("unhandled op type:", op.type.rawValue)
        }
    }

    func beginProvisionalOps() {
        self.provisionalShapeIndex = self.shapeList.count
        self.provisionalOpIndex = self.opList.count
        self.provisionalTimestampIndex = self.timestamps.count
    }

    func commitProvisionalOps() {
        self.provisionalShapeIndex = self.shapeList.count
        self.provisionalOpIndex = self.opList.count
        self.provisionalTimestampIndex = self.timestamps.count
    }

    func cancelProvisionalOps() {
        self.shapeList.removeSubrange(self.provisionalShapeIndex ..< self.shapeList.count)
        self.opList.removeSubrange(self.provisionalOpIndex ..< self.opList.count)
        self.timestamps.removeSubrange(self.provisionalTimestampIndex ..< self.timestamps.count)
    }

    func clear() {
        self.shapeList = []
        self.opList = []
        self.timestamps = []

        self.provisionalShapeIndex = 0
        self.provisionalOpIndex = 0
        self.provisionalTimestampIndex = 0
    }

    func serialize(filename: String) {
        let wrappedItems: [DrawOperationWrapper] = self.opList.map { DrawOperationWrapper(drawOperation: $0) }
        let path = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("bin")

        do {
            let binaryData: [UInt8] = try BinaryEncoder.encode(wrappedItems)
            FileManager.default.createFile(atPath: path.path, contents: Data(binaryData))
        } catch {
            print(error)
        }
    }

    func deserialize(filename: String, _ progressCallback: @escaping (_ current: Int, _ total: Int) -> Void) {
        let path = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("bin")

        do {
            let savedData = try Data(contentsOf: path)
            let decoder = BinaryDecoder(data: [UInt8](savedData), progressCallback: progressCallback, steps: 100)
            let decoded = try decoder.decode([DrawOperationWrapper].self)

            self.opList = decoded.map {
                self.addOp(op: $0.drawOperation)
                return $0.drawOperation
            }
        } catch {
            print(error)
        }
    }

    func serializeJson(filename: String) {
        let wrappedItems: [DrawOperationWrapper] = self.opList.map { DrawOperationWrapper(drawOperation: $0) }
        let path = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("json")

        do {
            let jsonData = try JSONEncoder().encode(wrappedItems)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            try jsonString.write(to: path, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print(error)
        }
    }

    func deserializeJson(filename: String) {
        let path = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("json")

        do {
            let jsonString = try String(contentsOf: path, encoding: .utf8)
            let decoded = try JSONDecoder().decode([DrawOperationWrapper].self, from: jsonString.data(using: .utf8)!)

            self.opList = decoded.map {
                self.addOp(op: $0.drawOperation)
                return $0.drawOperation
            }
        } catch {
            print(error)
        }
    }
}
