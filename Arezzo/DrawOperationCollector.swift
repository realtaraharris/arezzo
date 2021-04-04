//
//  DrawOperationCollector.swift
//  Arezzo
//
//  Created by Max Harris on 9/3/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import BinaryCoder
import Foundation
import Metal

enum PenState {
    case down, up
}

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

extension BinaryDecoder {}

class DrawOperationCollector {
    var opList: [DrawOperation] = []
    var shapeList: [Shape] = []
    var provisionalShapeIndex = 0
    var provisionalOpIndex = 0
    var provisionalTimestampIndex = 0
    var device: MTLDevice
    var activeColor: [Float] = []
    var currentLineWidth = DEFAULT_LINE_WIDTH

    var penState: PenState = .down
    var audioData: [Int16] = []
    var timestamps: [Double] = []
    var filename: URL

    init(device: MTLDevice) {
        self.device = device
        self.filename = getDocumentsDirectory().appendingPathComponent("ArezzoOutput.bin")
    }

    func getTimestamp(position: Double) -> Double {
        let first = self.timestamps.first!
        let last = self.timestamps.last!

        let total = last - first
        let targetTimestamp = (total * position) + first
        let targetTimestampIndex = self.timestamps.firstIndex(where: { $0 >= targetTimestamp })!
        return self.timestamps[targetTimestampIndex]
    }

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

    func getTimestampIterator(startIndex: Int, endIndex: Int) -> TimestampIterator {
        Timestamps(timestamps: Array(self.timestamps[startIndex ..< endIndex])).makeIterator()
    }

    func addOp(op: DrawOperation) {
        self.opList.append(op)
        self.timestamps.append(op.timestamp)

        if op.type == .penDown {
            let penDownOp = op as! PenDown
            self.penState = .down

            if penDownOp.mode == "draw" {
                self.activeColor = penDownOp.color
                self.currentLineWidth = penDownOp.lineWidth
                self.shapeList.append(Shape(type: "Line"))
            } else if penDownOp.mode == "pan" {
                self.shapeList.append(Shape(type: "Pan"))
            }
        } else if op.type == .pan {
            let lastShape = self.shapeList[self.shapeList.count - 1]
            let panOp = op as! Pan
            lastShape.addShapePoint(point: panOp.point, timestamp: panOp.timestamp, device: self.device, color: [0.8, 0.7, 0.6, 1.0], lineWidth: DEFAULT_LINE_WIDTH)
        } else if op.type == .point, self.penState == .down {
            let lastShape = self.shapeList[self.shapeList.count - 1]
            let pointOp = op as! Point
            lastShape.addShapePoint(point: pointOp.point, timestamp: pointOp.timestamp, device: self.device, color: self.activeColor, lineWidth: self.currentLineWidth)
        } else if op.type == .penUp {
            self.penState = .up
        } else if op.type == .audioClip {
            let audioClipOp = op as! AudioClip
            self.audioData.append(contentsOf: audioClipOp.audioSamples)
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

        self.audioData = []

        self.provisionalShapeIndex = 0
        self.provisionalOpIndex = 0
        self.provisionalTimestampIndex = 0
    }

    func serialize() {
        let wrappedItems: [DrawOperationWrapper] = self.opList.map { DrawOperationWrapper(drawOperation: $0) }

        do {
            let binaryData: [UInt8] = try BinaryEncoder.encode(wrappedItems)
            FileManager.default.createFile(atPath: self.filename.path, contents: Data(binaryData))
        } catch {
            print(error)
        }
    }

    func deserialize(_ progressCallback: @escaping (_ current: Int, _ total: Int) -> Void) {
        do {
            let savedData = try Data(contentsOf: self.filename)
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

    func serializeJson() {
        let wrappedItems: [DrawOperationWrapper] = self.opList.map { DrawOperationWrapper(drawOperation: $0) }

        do {
            let jsonData = try JSONEncoder().encode(wrappedItems)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            try jsonString.write(to: self.filename, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print(error)
        }
    }

    func deserializeJson() {
        do {
            let jsonString = try String(contentsOf: self.filename, encoding: .utf8)
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