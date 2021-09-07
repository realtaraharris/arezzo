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
import GameKit
import Metal

enum PenState {
    case down, up
}

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

struct WritableItem {
    var offsetSize: UInt64
    var binaryRepresentation: [UInt8]
    var type: DrawOperationType
}

struct IndexFile: BinaryCodable {
    var opCount: UInt64
    var startTimestamp: Double
    var endTimestamp: Double
    var opListOffsets: [UInt64]
    var audioOpIndexes: [Int]
    var audioControlOpIndexes: [Int]
    var drawOpIndexes: [Int] // TODO: run-length encoding to save space
    var timestamps: [Double] = []
}

let PAGE_SIZE: Int64 = 2048
let CLOSE_ENOUGH: Int64 = 128
let WINDOW_SIZE: UInt64 = 128

struct RecordingStateEx {
    var undoable: Bool = false
    var redoable: Bool = false
    var undoLevel: Int = 0
    var penState: PenState = .up
    var activeColor: [Float] = []
    var currentLineWidth: Float = 0
    var tree: GKQuadtree = GKQuadtree(boundingQuad: GKQuad(quadMin: SIMD2<Float>(0.0, 0.0), quadMax: SIMD2<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)), minimumCellSize: 100.0)
}

func addOpToShapeList(op: DrawOperation, rs: inout RecordingStateEx, shapeList: inout [Shape]) {
    if op.type == .penDown {
        let penDownOp = op as! PenDown
        rs.penState = .down

        if penDownOp.mode == PenDownMode.draw {
            if shapeList.count > 0 {
                let lastShape = shapeList[shapeList.count - 1]
                if lastShape.type == .undo || lastShape.type == .redo {
                    rs.undoable = false
                    rs.redoable = rs.undoLevel > 0
                }
            }
            rs.activeColor = penDownOp.color
            rs.currentLineWidth = penDownOp.lineWidth
            shapeList.append(Shape(type: DrawOperationType.line))
        } else if penDownOp.mode == PenDownMode.pan {
            shapeList.append(Shape(type: DrawOperationType.pan))
        } else if penDownOp.mode == PenDownMode.portal {
            rs.activeColor = penDownOp.color
            rs.currentLineWidth = penDownOp.lineWidth
            let newShape = Shape(type: DrawOperationType.portal)
            newShape.name = penDownOp.portalName
            shapeList.append(newShape)
        } else {
            print("unhandled mode:", penDownOp.mode)
        }
    } else if op.type == .pan {
        let lastShape = shapeList[shapeList.count - 1]
        let panOp = op as! Pan
        lastShape.addShapePoint(point: panOp.point, timestamp: panOp.timestamp, color: [0.8, 0.7, 0.6, 1.0], lineWidth: DEFAULT_LINE_WIDTH)
        rs.tree.add(op.timestamp as NSObject, at: SIMD2<Float>(panOp.point[0], panOp.point[1]))
    } else if op.type == .point, rs.penState == .down {
        let lastShape = shapeList[shapeList.count - 1]
        let pointOp = op as! Point
        lastShape.addShapePoint(point: pointOp.point, timestamp: pointOp.timestamp, color: rs.activeColor, lineWidth: rs.currentLineWidth)
        rs.tree.add(op.timestamp as NSObject, at: SIMD2<Float>(pointOp.point[0], pointOp.point[1]))
    } else if op.type == .portal {
        let lastShape = shapeList[shapeList.count - 1]
        let portalOp = op as! Portal
        lastShape.addShapePoint(point: portalOp.point, timestamp: portalOp.timestamp, color: rs.activeColor, lineWidth: rs.currentLineWidth)
        rs.tree.add(op.timestamp as NSObject, at: SIMD2<Float>(portalOp.point[0], portalOp.point[1]))
    } else if op.type == .penUp {
        rs.penState = .up
        rs.undoable = true
        rs.redoable = rs.undoLevel > 0
    } else if op.type == .audioClip {
    } else if op.type == .undo {
        rs.undoLevel += 1
        let undoShape = Shape(type: DrawOperationType.undo)
        undoShape.timestamp.append(op.timestamp)
        shapeList.append(undoShape)
    } else if op.type == .redo {
        rs.undoLevel -= 1
        let redoShape = Shape(type: DrawOperationType.redo)
        redoShape.timestamp.append(op.timestamp)
        shapeList.append(redoShape)
    } else {
        print("unhandled op type:", op.type.rawValue)
    }
}

class Recording {
    private var opList: [DrawOperation] = []
    var shapeList: [Shape] = []
    var provisionalShapeIndex = 0
    var provisionalOpIndex = 0
    var provisionalTimestampIndex = 0
    var activeColor: [Float] = []
    var currentLineWidth = DEFAULT_LINE_WIDTH

    var penState: PenState = .down
    var name: String = ""
    var recordingIndex: RecordingIndex
    var undoLevel: Int = 0
    var undoable: Bool = false
    var redoable: Bool = false
    var index: IndexFile?
    var writeQueue: Queue = Queue<WritableItem>()
    var unwrittenSize: UInt64 = 0
    var backingFile: FileHandle?

    var tree: GKQuadtree<NSObject>

    init(name: String, recordingIndex: RecordingIndex) {
        self.name = name
        self.recordingIndex = recordingIndex

        self.tree = GKQuadtree(boundingQuad: GKQuad(quadMin: SIMD2<Float>(0.0, 0.0), quadMax: SIMD2<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)), minimumCellSize: 100.0)

        self.index = IndexFile(opCount: 0, startTimestamp: 0, endTimestamp: 0, opListOffsets: [0],
                               audioOpIndexes: [], audioControlOpIndexes: [], drawOpIndexes: [])

        self.readIndexFile(filename: name)
        self.mapOpListFile(filename: name)

        self.readOps(startIndex: 0, endIndex: 3 * Int(WINDOW_SIZE))

        /*
                          |<-- f -->|<-- g -->|<-- h -->|
                          a         b         c         d
                          |xxxxxxxxx|---------|+++++++++|
            |------------------------------ h ------------------------------|
            start                                                           end

            let b_h = h - (start + a + WINDOW_SIZE)

            when playback crosses c, drop the range from a -> b
            then overwrite

         */
    }

    func getOp(_ index: Int) -> DrawOperation? {
//        if index >= self.a && index < self.b {
//            return self.opList[index - Int(self.a)]
//        } else if (index >= self.b && index < self.c) {
//            return self.opList[index - Int(self.b)]
//        } else if (index >= self.c && index < self.c + WINDOW_SIZE) {
//
//            DispatchQueue.main.async {
//            }
//
//            return self.opList[index - Int(self.c)]
//        }

        if index > self.opList.count - 1 { return nil }
        return self.opList[index]
    }

    func getOpCount() -> Int {
        self.opList.count
    }

    func getFirstOp() -> DrawOperation {
        self.opList.first!
    }

    func getLastOp() -> DrawOperation {
        self.opList.last!
    }

    func getLastPanOp() -> DrawOperation {
        self.opList.last { (op: DrawOperation) -> Bool in op.type == .pan }!
    }

    func getTimestamp(position: Double) -> Double {
        let first = self.index!.timestamps.first!
        let last = self.index!.timestamps.last!

        let total = last - first
        let targetTimestamp = (total * position) + first
        let targetTimestampIndex = self.index!.timestamps.firstIndex(where: { $0 >= targetTimestamp })!
        return self.index!.timestamps[targetTimestampIndex]
    }

    // TODO: remove?
    func getTimestampIndices(startPosition: Double, endPosition: Double) -> (startIndex: Int, endIndex: Int) {
        let first = self.index!.timestamps.first!
        let last = self.index!.timestamps.last!

        let total = last - first
        let targetTimestampStart = (total * startPosition) + first
        let targetTimestampEnd = (total * endPosition) + first

        let startIndex = self.index!.timestamps.firstIndex(where: { $0 >= targetTimestampStart })!
        let endIndex = self.index!.timestamps.firstIndex(where: { $0 >= targetTimestampEnd })!

        return (startIndex, endIndex)
    }

    // TODO: remove?
    func getTimestampIterator(startIndex: Int, endIndex: Int) -> TimestampIterator {
        Timestamps(timestamps: Array(self.index!.timestamps[startIndex ..< endIndex])).makeIterator()
    }

    func getOldestVisibleTimestamp(_ viewport: [Float]) -> Double {
        // each op has an oldestVisibleTimestamp that tells us how far back we need to go to render the frame.
        // the purpose of the quadTree is provide rapid access to the oldest timestamp required in the shapeList

        let output = self.tree.elements(in: GKQuad(quadMin: SIMD2<Float>([viewport[0], viewport[1]]), quadMax: SIMD2<Float>(viewport[2], viewport[3])))

        // TODO: if we kept this stuff in a 3D k-d tree, we could get rid of this loop entirely
        var oldestTimestamp: Double = .greatestFiniteMagnitude
        for ts in output {
            let timestamp = ts as! Double
            if timestamp < oldestTimestamp {
                oldestTimestamp = timestamp
            }
        }

        return oldestTimestamp
    }

    func writeRecordingState(rs: RecordingStateEx) {
        self.undoable = rs.undoable
        self.redoable = rs.redoable
        self.undoLevel = rs.undoLevel
        self.penState = rs.penState
        self.activeColor = rs.activeColor
        self.currentLineWidth = rs.currentLineWidth
        self.tree = rs.tree
    }

    func rebuildShapeList(inputOps: [DrawOperation]) {
        // request the op at the timestamp given
        // request all ops from the op's oldestVisibleTimestamp onward
        // addOpToShapeList() them into a new shapelist
        var rs = RecordingStateEx()
        var shapeList: [Shape] = []
        
        for op in inputOps {
            addOpToShapeList(op: op, rs: &rs, shapeList: &shapeList)
        }

        writeRecordingState(rs: rs)
    }

    func decodeOp(_ data: [UInt8]) throws -> DrawOperation? {
        let decoder = BinaryDecoder(data: data, progressCallback: progressCallback, steps: 1)
        let type = try decoder.decode(DrawOperationType.self).rawValue
        decoder.cursor = 0

        if type == "viewport" {
            return try decoder.decode(Viewport.self)
        } else if type == "point" {
            return try decoder.decode(Point.self)
        } else if type == "penDown" {
            return try decoder.decode(PenDown.self)
        }

        return nil
    }

    func readOps(startIndex: Int, endIndex: Int) {
        do {
            if startIndex > (self.index?.opListOffsets.count)! - 1 || endIndex > (self.index?.opListOffsets.count)! - 1 { return }

            let start = self.index?.opListOffsets[startIndex]
            let end = self.index?.opListOffsets[endIndex] // TODO: check against EOF?

            let offsets = self.index?.opListOffsets[startIndex ... endIndex]

            try self.backingFile?.seek(toOffset: start!)
            let length: Int = Int(end! - start!)
            let data: Data? = try self.backingFile?.read(upToCount: length)

            for (index, offset) in offsets!.enumerated() {
                if index >= offsets!.count - 1 { break }
                let sliceStart = Int(offset)
                let sliceEnd = Int(offsets![index + 1])
                if sliceStart == sliceEnd { break } // TODO: should be able to get rid of this
                let decodedOp = try decodeOp(Array([UInt8](data!)[sliceStart ..< sliceEnd]))
            }
        } catch {
            print("error:", error)
        }
    }

    func recordOp(op: DrawOperation) {
        self.index!.timestamps.append(op.timestamp)

        let index = self.opList.count
        if op.type == .audioStart {
            self.index!.audioControlOpIndexes.append(index)
        } else if op.type == .audioClip {
            self.index!.audioOpIndexes.append(index)
        } else if op.type == .audioStop {
            self.index!.audioControlOpIndexes.append(index)
        } else {
            self.index!.drawOpIndexes.append(index)
        }

        // TODO: pass in current viewport.
        let output = self.tree.elements(in: GKQuad(quadMin: SIMD2<Float>(0.0, 0.0), quadMax: SIMD2<Float>(1000.0, 1000.0)))

        do {
            let binaryData: [UInt8] = try BinaryEncoder.encode(op)
            let type: DrawOperationType = op.type

            let offsetSize = UInt64(binaryData.count)
//            print("offsetSize:", offsetSize)
            self.unwrittenSize += UInt64(offsetSize)
            let wi = WritableItem(offsetSize: offsetSize, binaryRepresentation: binaryData, type: type)
            self.writeQueue.enqueue(wi)
        } catch {
            print("error:", error)
        }

        if PAGE_SIZE - Int64(self.unwrittenSize) <= CLOSE_ENOUGH {
            while let unwrittenOp = self.writeQueue.dequeue() {
                do {
                    print("writing offset:", unwrittenOp.offsetSize)
                    let lastOffset = self.index?.opListOffsets.last ?? 0
                    try self.backingFile?.seek(toOffset: lastOffset)
                    try self.backingFile?.write(contentsOf: unwrittenOp.binaryRepresentation)
                    self.index?.opListOffsets.append(lastOffset + unwrittenOp.offsetSize)

                    self.writeIndexFile(filename: "Root")
                } catch {
                    print("error:", error)
                }
            }

            self.unwrittenSize = 0
        }
    }

    // fuck - need to put these in a queue. can't directly acccess shapeList or opList
    func beginProvisionalOps() {
        self.provisionalShapeIndex = self.shapeList.count
        self.provisionalOpIndex = self.opList.count
        self.provisionalTimestampIndex = self.index!.timestamps.count
    }

    func commitProvisionalOps() {
        self.provisionalShapeIndex = self.shapeList.count
        self.provisionalOpIndex = self.opList.count
        self.provisionalTimestampIndex = self.index!.timestamps.count
    }

    func cancelProvisionalOps() {
        self.shapeList.removeSubrange(self.provisionalShapeIndex ..< self.shapeList.count)
        self.opList.removeSubrange(self.provisionalOpIndex ..< self.opList.count)
        self.index!.timestamps.removeSubrange(self.provisionalTimestampIndex ..< self.index!.timestamps.count)
    }

    func clear() {
        self.shapeList = []
        self.opList = []
        self.index!.timestamps = []

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

    // TODO: do we still want this?
    func progressCallback(todoCount _: Int, todo _: Int) {}

    func readIndexFile(filename: String) {
        let indexPath = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("index")

        do {
            let indexData: Data = try Data(contentsOf: indexPath, options: .mappedIfSafe)
            let decoder = BinaryDecoder(data: [UInt8](indexData), progressCallback: progressCallback, steps: 1)
            self.index = try decoder.decode(IndexFile.self)
        } catch {
            print(error)
        }
    }

    func writeIndexFile(filename: String) {
        let indexPath = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("index")

        do {
            let binaryData: [UInt8] = try BinaryEncoder.encode(self.index!)
            FileManager.default.createFile(atPath: indexPath.path, contents: Data(binaryData))
        } catch {
            print(error)
        }
    }

    func mapOpListFile(filename: String) {
        let opListPath = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("bin")

        print("opListPath:", opListPath)

        do {
            if !FileManager.default.fileExists(atPath: opListPath.path) {
                FileManager.default.createFile(atPath: opListPath.path, contents: nil, attributes: nil)
            }

            self.backingFile = try FileHandle(forUpdating: opListPath.absoluteURL)
        } catch {
            print(error)
        }
    }

    func writeOpListFile() {}

    func deserialize(filename: String, _ progressCallback: @escaping (_ current: Int, _ total: Int) -> Void) {
        let path = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("bin")

        do {
            let savedData = try Data(contentsOf: path)
            let decoder = BinaryDecoder(data: [UInt8](savedData), progressCallback: progressCallback, steps: 100)
            let decoded = try decoder.decode([DrawOperationWrapper].self)

            self.opList = decoded.map {
                self.recordOp(op: $0.drawOperation)
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
                self.recordOp(op: $0.drawOperation)
                return $0.drawOperation
            }
        } catch {
            print(error)
        }
    }
}
