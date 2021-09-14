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

    private var boundingCube: CodableCube
    private var activeCube: CodableCube
    private var tree: Octree
    private var mapping: MappedTree
    private var monotonicId: Int64 = 1
    private var unwrittenSubtrees: [Octree] = []

    init(name: String, recordingIndex: RecordingIndex) {
        self.name = name
        self.recordingIndex = recordingIndex

        let now = CFAbsoluteTimeGetCurrent()
        let later = now + 9_999_999.0

        self.boundingCube = CodableCube(cubeMin: PointInTime(x: -100.0, y: -100.0, t: 0), cubeMax: PointInTime(x: 100.0, y: 100.0, t: later))

        self.activeCube = CodableCube(cubeMin: PointInTime(x: -1.0, y: -1.0, t: 0), cubeMax: PointInTime(x: 1.0, y: 1.0, t: later))

        self.tree = Octree(boundingCube: self.boundingCube, maxLeavesPerNode: 10, maximumDepth: INT64_MAX, id: 0)
        self.mapping = MappedTree(name)
    }

    func getMonotonicId() -> Int64 {
        let returnValue = self.monotonicId
        self.monotonicId += 1
        return returnValue
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

    func addOp(op: DrawOperation, position: PointInTime) {
        guard let encoded = encodeOp(op), let offset = self.mapping.writeOp(encoded) else { return }
        let id = self.getMonotonicId()
        print("adding id:", id, position)
        self.mapping.writeIndex(id, IndexRecord(offset: Int64(offset), size: UInt16(encoded.count), type: op.type.rawValue))
        self.tree.add(leafData: UInt64(id), position: position, &self.unwrittenSubtrees, self.getMonotonicId)

//        print("self.unwrittenSubtrees:", self.unwrittenSubtrees)

        self.opList.append(op)
        self.addToShapeList(op: op)
    }

    func addToShapeList(op: DrawOperation) {
//        self.timestamps.append(op.timestamp)

        // TODO: pass in current viewport
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
                self.shapeList.append(Shape(type: NodeType.line))
            } else if penDownOp.mode == PenDownMode.pan {
                self.shapeList.append(Shape(type: NodeType.pan))
            } else if penDownOp.mode == PenDownMode.portal {
                self.activeColor = penDownOp.color
                self.currentLineWidth = penDownOp.lineWidth
                let newShape = Shape(type: NodeType.portal)
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
            let undoShape = Shape(type: NodeType.undo)
            undoShape.timestamp.append(op.timestamp)
            self.shapeList.append(undoShape)
        } else if op.type == .redo {
            self.undoLevel -= 1
            let redoShape = Shape(type: NodeType.redo)
            redoShape.timestamp.append(op.timestamp)
            self.shapeList.append(redoShape)
        } else {
            print("unhandled op type:", op.type)
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

    func serialize(filename _: String) {
        self.mapping.printTree(self.tree)

        // query to see what the tree holds
        let elements = self.tree.elements(in: self.boundingCube)
        print("serialize, elements:", elements)

        for subtree in self.unwrittenSubtrees {
            print("serializing subtree:", subtree)
            self.mapping.serializeTree(subtree)
        }
        self.unwrittenSubtrees = []
    }

    func deserialize(filename: String) {
        print("in deserialize, filename:", filename)
        self.mapping.restore(self.boundingCube, &self.tree)

//        self.mapping.printTree(self.tree)
        let elements = self.tree.elements(in: self.boundingCube).sorted()

        do {
            for id in elements {
                guard let (opOffset, length, type) = self.mapping.readIndex(Int64(id)), let newOp = self.mapping.readOp(opOffset, length) else {
                    continue
                }

                var theOp: DrawOperation?
                if type == NodeType.line.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(Line.self)
                } else if type == NodeType.pan.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(Pan.self)
                } else if type == NodeType.point.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(Point.self)
                } else if type == NodeType.penDown.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(PenDown.self)
                } else if type == NodeType.penUp.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(PenUp.self)
                } else if type == NodeType.audioStart.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(AudioStart.self)
                } else if type == NodeType.audioClip.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(AudioClip.self)
                } else if type == NodeType.audioStop.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(AudioStop.self)
                } else if type == NodeType.portal.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(Portal.self)
                } else if type == NodeType.viewport.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(Viewport.self)
                } else if type == NodeType.undo.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(Undo.self)
                } else if type == NodeType.redo.rawValue {
                    theOp = try BinaryDecoder(data: newOp).decode(Redo.self)
                } else {
                    print("unhandled type:", type)
                }

                if theOp != nil {
                    self.opList.append(theOp!)
                    self.addToShapeList(op: theOp!)
                }
            }
        } catch {
            print(error)
        }

        print("self.opList:", self.opList)
    }
}
