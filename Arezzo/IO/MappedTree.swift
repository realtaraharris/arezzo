//
//  MappedTree.swift
//  streaming-octree
//
//  Created by Max Harris on 7/8/21.
//

import BinaryCoder
import Foundation
import simd

/*
 xxd /Users/max/Library/Containers/test.streaming-tree/Data/Documents/filename.bin; xxd /Users/max/Library/Containers/test.streaming-tree/Data/Documents/filename.idx; xxd /Users/max/Library/Containers/test.streaming-tree/Data/Documents/filename.tree
 */

//        tree file:
//        <[ids]><row occupancy UInt8s><[ids]><row occupancy UInt8s>
//        read id 0, then the row occupancy UInt8. that will tell you the next row's size: one id, and one row occupancy byte per bit set high

extension Data {
    var getInt64: Int64 {
        withUnsafeBytes { $0.load(as: Int64.self) }
    }
}

func getURL(_ filename: String, _ ext: String) -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let result = paths[0].appendingPathComponent(filename).appendingPathExtension(ext)
//    print("result:", result)
    return result
}

struct IndexRecord {
    var offset: Int64
    var size: UInt16
    var type: UInt8
}

struct TreeMetadata: BinaryCodable {
    var bounds: CodableCube
    var lastId: Int64
}

struct NodeRecord: BinaryCodable {
    var leafIds: [Int64] // TODO: allocate max bucket size so that nodes can be added without fragmentation
}

// for every id there will be an occupancy byte
struct TreeNode: BinaryCodable {
    var id: Int64
    var occupancy: UInt8
}

let RECORD_SIZE: Int = MemoryLayout<IndexRecord>.size
let TREEMETA_SIZE: Int = MemoryLayout<TreeMetadata>.size
let TREENODE_SIZE: Int = MemoryLayout<TreeNode>.size

func mapOpListFile(_ opListPath: URL) -> FileHandle? {
    do {
        if !FileManager.default.fileExists(atPath: opListPath.path) {
            FileManager.default.createFile(atPath: opListPath.path, contents: nil, attributes: nil)
        }

        return try FileHandle(forUpdating: opListPath.absoluteURL)
    } catch {
        print(error)
    }
    return nil
}

func encodeOp(_ op: DrawOperation) -> [UInt8]? {
    do {
        return try BinaryEncoder.encode(op)
    } catch {
        print(error)
    }
    return nil
}

func encodeNodeRecord(_ nr: NodeRecord) -> [UInt8]? {
    do {
        return try BinaryEncoder.encode(nr)
    } catch {
        print(error)
    }
    return nil
}

func encodeLeaf(_ leaf: DrawOperationEx) -> [UInt8]? {
    do {
        return try BinaryEncoder.encode(leaf)
    } catch {
        print(error)
    }
    return nil
}

func encodeTreeNode(_ treeNode: TreeNode) -> [UInt8]? {
    do {
        return try BinaryEncoder.encode(treeNode)
    } catch {
        print(error)
    }
    return nil
}

func unarchive(_ data: Data) -> (opOffset: UInt64, length: Int, type: Int) {
    let indexRecord = data.withUnsafeBytes { $0.load(as: IndexRecord.self) }
    return (UInt64(indexRecord.offset), Int(indexRecord.size), Int(indexRecord.type))
}

extension BinaryInteger {
    var binaryDescription: String {
        var binaryString = ""
        var internalNumber = self
        var counter = 0

        for _ in 1 ... self.bitWidth {
            binaryString.insert(contentsOf: "\(internalNumber & 1)", at: binaryString.startIndex)
            internalNumber >>= 1
            counter += 1
            if counter == 4 {
                binaryString.insert(contentsOf: "_", at: binaryString.startIndex)
            }
        }

        return "0b" + binaryString
    }
}

class MappedTree {
    var binFh: FileHandle?
    var indexFh: FileHandle?
    var treeFh: FileHandle?
    var metaTreeFh: FileHandle?

    init(_ filename: String) {
        self.binFh = mapOpListFile(getURL(filename, "bin")) // stores the binary serialized NodeRecords and draw ops: [nr, nr, nr, op, op, op, ...]
        self.indexFh = mapOpListFile(getURL(filename, "idx")) // stores IndexRecords: [0: (offset: Int64, size: UInt16, type: UInt8), 1: (offset: ...)]
        self.treeFh = mapOpListFile(getURL(filename, "tree")) // stores the tree ids: [0, 1, 2, 3...]
        self.metaTreeFh = mapOpListFile(getURL(filename, "mth")) // struct contains tree bounds: x, y, t
//        print("opening url: getURL(filename, 'mth')", getURL(filename, "mth"))
    }

    func readMetaTree() -> TreeMetadata? {
        do {
            guard let fh = self.metaTreeFh else {
                print("meta tree file handle unexpectedly unavailable")
                return nil
            }
            try fh.seek(toOffset: 0)
            let cc = [UInt8](fh.readData(ofLength: TREEMETA_SIZE))
            return try BinaryDecoder(data: cc).decode(TreeMetadata.self)
        } catch {
            print(error)
        }
        return nil
    }

    func writeMetaTree(_ cube: CodableCube, _ id: Int64) {
        do {
            guard let fh = self.metaTreeFh else {
                print("meta tree file handle unexpectedly unavailable")
                return
            }
            let cd = try BinaryEncoder.encode(TreeMetadata(bounds: cube, lastId: id))
            try fh.seek(toOffset: 0)
            fh.write(Data(cd))
        } catch {
            print(error)
        }
        return
    }

    func readOp(_ offset: UInt64, _ length: Int) -> [UInt8]? {
        do {
            guard let fh = self.binFh else {
                print("bin file handle unexpectedly unavailable")
                return nil
            }
            try fh.seek(toOffset: offset)
            return [UInt8](fh.readData(ofLength: length))
        } catch {
            print(error)
        }
        return nil
    }

    func writeOp(_ op: [UInt8]) -> UInt64? {
        guard let fh = self.binFh else {
            print("bin file handle unexpectedly unavailable")
            return nil
        }

        do {
            try fh.seekToEnd()
        } catch {
            print(error)
        }

        let offset = fh.offsetInFile
        fh.write(Data(op))

        return offset
    }

    func writeIndex(_ id: Int64, _ indexRecord: IndexRecord) {
        // TODO: check bounds

        do {
            guard let fh = self.indexFh else {
                print("index file handle unexpectedly unavailable")
                return
            }

            let offset = UInt64(id) * UInt64(RECORD_SIZE)
            try fh.seek(toOffset: offset)

            var ir = indexRecord
            let data = Data(bytes: &ir, count: RECORD_SIZE)
            fh.write(data)
        } catch {
            print(error)
        }
    }

    func readIndex(_ id: Int64) -> (opOffset: UInt64, length: Int, type: Int)? {
        do {
            guard let fh = self.indexFh else {
                print("index file handle unexpectedly unavailable")
                return nil
            }

            try fh.seek(toOffset: UInt64(id) * UInt64(RECORD_SIZE))
            guard let indexRecordBytes: Data = try fh.read(upToCount: RECORD_SIZE) else {
                return nil
            }
            return unarchive(indexRecordBytes)
        } catch {
            print(error)
        }

        return nil
    }

//    func writeTreeId(_ id: Int64) {
//        do {
//            guard let fh = self.treeFh else {
//                print("tree file handle unexpectedly unavailable")
//                return
//            }
//
//            try fh.seekToEnd()
//            fh.write(withUnsafeBytes(of: id) { Data($0) })
//        } catch {
//            print(error)
//        }
//    }

    func writeTreeEntry(_ treeNode: TreeNode) {
//        print("writing tree entry for id:", treeNode.id)

        guard let fh = self.treeFh else {
            print("tree file handle unexpectedly unavailable")
            return
        }

        guard let treeNodeBin = encodeTreeNode(treeNode) else { return }
        fh.write(Data(treeNodeBin))
    }

    func readTreeEntry(_ treeOffset: Int64, length: Int) -> TreeNode? {
        do {
            guard let fh = self.treeFh else {
                print("tree file handle unexpectedly unavailable")
                return nil
            }

            try fh.seek(toOffset: UInt64(treeOffset))
            let f = [UInt8](fh.readData(ofLength: length))
            return try BinaryDecoder(data: f).decode(TreeNode.self)
        } catch {
            print(error)
        }

        return nil
    }

    func readTreeId(_ treeOffset: Int64) -> Int64? {
        do {
            guard let fh = self.treeFh else {
                print("tree file handle unexpectedly unavailable")
                return nil
            }

            try fh.seek(toOffset: UInt64(treeOffset))
            let f = fh.readData(ofLength: 8)
            return f.getInt64
        } catch {
            print(error)
        }

        return 0
    }

    func indentString(_ indent: Int) -> String {
        var scratch = ""
        for _ in 0 ..< indent {
            scratch += "    "
        }

        return scratch
    }

    func printObjects(_ indent: Int, _ objects: [DrawOperationEx]) {
        for object in objects {
            print(
                "\(self.indentString(indent))    offset: \(object.leafData), position: (\(object.position.x), \(object.position.y), \(object.position.t))"
            )
        }
    }

    func printTree(_ tree: Octree, _ treeName: String) {
        print("v=====================v")
        print(" > tree name:", treeName)
        self.printTreeRecursive(0, tree)
        print("^=====================^")
    }

    func printTreeRecursive(_ indent: Int, _ tree: Octree) {
        let occupancy = tree.encodeChildOccupancy()
        print("\(self.indentString(indent))\(tree.id) \(occupancy.binaryDescription) \(occupancy == 0b0000_0000 ? String(tree.leaves.count) : "")")

        if occupancy == 0b0000_0000 { self.printObjects(indent, tree.leaves) }

        for i in 0 ..< 8 {
            guard let subtree = tree.subtrees[i] else { continue }
            self.printTreeRecursive(indent + 1, subtree)
        }
    }

    func serializeTree(_ tree: Octree) {
        do {
            try self.treeFh?.seek(toOffset: 0)
        } catch {
            print(error)
        }
        var queue = Queue<Octree?>(arrayLiteral: tree)
        var currentDepth: Int64 = 0
        var row: [TreeNode] = []

        while queue.count > 0 {
            guard let node = queue.pop() else { continue }

            if node.encodeChildOccupancy() == 0b0000_0000 { // we are on a leaf node; serialize all children
                // write a block of ids to go from leaf -> DrawOperationEx
                let leafIds = node.leaves.map { (DrawOperationEx) -> Int64 in DrawOperationEx.id }
                guard let nr = encodeNodeRecord(NodeRecord(leafIds: leafIds)), let nrOffset = self.writeOp(nr) else { continue }
                let ir1 = IndexRecord(offset: Int64(nrOffset), size: UInt16(nr.count), type: NodeType.nodeRecord.rawValue)

                self.writeIndex(node.id, ir1)

                // now write the objects themselves
                for existingObject in node.leaves {
                    guard let objectBinRep = encodeLeaf(existingObject), let objectOffset = self.writeOp(objectBinRep) else { continue }
                    let ir = IndexRecord(offset: Int64(objectOffset), size: UInt16(objectBinRep.count), type: NodeType.leaf.rawValue)

                    self.writeIndex(existingObject.id, ir)
                }
            }

            row.append(TreeNode(id: node.id, occupancy: node.encodeChildOccupancy()))

            if node.depth > currentDepth {
                for item in row { // write the row to the .tree file
                    self.writeTreeEntry(item)
                }
                row = [] // clear the row
                currentDepth = node.depth
            }

            for i in 0 ..< 8 {
                guard let subtree = node.subtrees[i] else { continue }
                queue.push(value: subtree)
            }
        }

        for item in row { // write the row to the .tree file
            self.writeTreeEntry(item)
        }
    }

    func restore(_ cube: CodableCube? = nil, _ octree: inout Octree) {
        // quit early if we're already loading out of bounds
        if cube != nil, !octree.cube.intersects(cube!) {
            print("quit early")
            return
        }

        var nextVisitOffset: Int64 = 0
        func onVisit(_ inc: Int64) -> Int64 {
            let scratch = nextVisitOffset
            nextVisitOffset += inc
            return scratch
        }

        var positionQueue = Queue<(subtreeSlot: Int, parent: Octree)>()

        func restoreInner(_ parent: Octree, _ subtreeSlot: Int) {
            guard let entry = self.readTreeEntry(onVisit(Int64(TREENODE_SIZE)), length: TREENODE_SIZE) else { return }
            if entry.occupancy > 0 { // add branches
                let newBranch = parent.split(entry.id, subtreeSlot)
                for position in highBitPositions(entry.occupancy) {
                    positionQueue.push(value: (subtreeSlot: position, parent: newBranch))
                }
            } else { // add leaf
                guard let (opOffset, length, _) = self.readIndex(Int64(entry.id)), let binOp = self.readOp(opOffset, length) else { return }

                let sibling = parent.split(entry.id, subtreeSlot)
                do {
                    // read the NodeRecord
                    let nr: NodeRecord = try BinaryDecoder(data: binOp).decode(NodeRecord.self)
                    for id in nr.leafIds {
                        // add multiple DrawOperationEx leaves
                        guard let (opOffset1, length1, _) = self.readIndex(Int64(id)), let binOp1 = self.readOp(opOffset1, length1) else { return }

                        let leaf1: DrawOperationEx = try BinaryDecoder(data: binOp1).decode(DrawOperationEx.self)
                        sibling.leaves.append(leaf1)
                    }
                } catch {
                    print(error)
                }
            }
        }

        // read the first id and occupancy byte
        guard let root = self.readTreeEntry(onVisit(Int64(TREENODE_SIZE)), length: TREENODE_SIZE) else { return }
        let childPositions = highBitPositions(root.occupancy) // local position of each child in an array: subtree slot # of each occupied subtree
        for subtreeSlot in childPositions {
            restoreInner(octree, subtreeSlot)
        }

        // load children of root if we have any
        do {
            guard let (opOffset, length, _) = self.readIndex(Int64(0)), let binOp = self.readOp(opOffset, length) else { return }
            if length > 0 {
                let nr: NodeRecord = try BinaryDecoder(data: binOp).decode(NodeRecord.self)

                for id in nr.leafIds {
                    // add multiple DrawOperationEx leaves
                    guard let (opOffset1, length1, _) = self.readIndex(Int64(id)), let binOp1 = self.readOp(opOffset1, length1) else { return }

                    let leaf1: DrawOperationEx = try BinaryDecoder(data: binOp1).decode(DrawOperationEx.self)
                    octree.leaves.append(leaf1)
                }
            }
        } catch {
            print("error loading leaves on root node:", error)
        }

        while positionQueue.count > 0 {
            let (subtreeSlot, parent) = positionQueue.pop()
            restoreInner(parent, subtreeSlot)
        }

        assert(positionQueue.count == 0)
    }

    func close() throws {
        try self.binFh?.close()
        try self.indexFh?.close()
        try self.treeFh?.close()
        try self.metaTreeFh?.close()
    }

    // TODO: throw this into an extension
    func dumpTree(count: Int) {
        for i in 0 ..< count {
            guard let id = self.readTreeId(Int64(i) * 8) else { continue }
            print("id:", id)
        }
    }

    func dumpIndex(count: Int) {
        for i in 0 ..< count {
            guard let (opOffset, length, type) = self.readIndex(Int64(i)) else { continue }
            print("opOffset, length, type:", opOffset, length, type)
        }
    }
}
