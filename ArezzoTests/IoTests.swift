//
//  streaming_treeTests.swift
//  streaming-treeTests
//
//  Created by Max Harris on 7/27/21.
//

import BinaryCoder
import simd
// @testable import StreamingTree
import XCTest

func del(_ filePath: URL) {
    do {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath.path) {
            try fileManager.removeItem(atPath: filePath.path)
        } else {
            print("file does not exist")
        }
    } catch {
        print(error)
    }
}

class streaming_treeTests: XCTestCase {
    func helpy(_ filename: String, _ ext: String) throws -> String {
        let digest = SHA256Digest()
        let url = getURL(filename, ext)
        try digest.update(url: url)
        let hash = digest.finalize().hexString
        return hash
    }

    func testEmpty() throws {
        let boundingCube = CodableCube(cubeMin: PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId())

        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [].sorted())
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_0000)
    }

    func testOne() throws {
        let boundingCube = CodableCube(cubeMin: PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId())
        tree.add(leafData: 0, position: PointInTime(x: 5.0, y: 5.0, t: 5.0), &unwrittenSubtrees, getMonotonicId)

        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [0].sorted())
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_0000)
    }

    func testTwo() throws {
        let boundingCube = CodableCube(cubeMin: PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

//        var unwrittenIds = Set<Int64>()
        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId())

        tree.add(leafData: 99, position: PointInTime(x: 9.0, y: 9.0, t: 9.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [99].sorted())
        XCTAssertEqual(tree.leaves.count, 1)
        XCTAssertEqual(tree.leaves[0].leafData, 99)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_0000)

        tree.add(leafData: 88, position: PointInTime(x: 1.0, y: 1.0, t: 1.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0001_0100)

        XCTAssertEqual(tree.subtrees[2]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[2]!.leaves[0].leafData, 88)
        XCTAssertEqual(tree.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[4]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[4]!.leaves[0].leafData, 99)
        XCTAssertEqual(tree.subtrees[4]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [88, 99].sorted())
    }

    func testThree() throws {
        let boundingCube = CodableCube(cubeMin: PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId())

        tree.add(leafData: 99, position: PointInTime(x: 9.0, y: 9.0, t: 9.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [99].sorted())
        XCTAssertEqual(tree.leaves.count, 1)
        XCTAssertEqual(tree.leaves[0].leafData, 99)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_0000)

        tree.add(leafData: 88, position: PointInTime(x: 1.0, y: 1.0, t: 1.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0001_0100)

        XCTAssertEqual(tree.subtrees[2]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[2]!.leaves[0].leafData, 88)
        XCTAssertEqual(tree.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[4]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[4]!.leaves[0].leafData, 99)
        XCTAssertEqual(tree.subtrees[4]!.encodeChildOccupancy(), 0b0000_0000)

        tree.add(leafData: 77, position: PointInTime(x: 9.0, y: 9.0, t: 1.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0001_0101)

        XCTAssertEqual(tree.subtrees[0]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[0]!.leaves[0].leafData, 77)
        XCTAssertEqual(tree.subtrees[0]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[2]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[2]!.leaves[0].leafData, 88)
        XCTAssertEqual(tree.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[4]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[4]!.leaves[0].leafData, 99)
        XCTAssertEqual(tree.subtrees[4]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [77, 88, 99].sorted())
    }

    func testFour() throws {
        let boundingCube = CodableCube(cubeMin: PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId())

        tree.add(leafData: 99, position: PointInTime(x: 9.0, y: 9.0, t: 9.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [99].sorted())
        XCTAssertEqual(tree.leaves.count, 1)
        XCTAssertEqual(tree.leaves[0].leafData, 99)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_0000)

        tree.add(leafData: 88, position: PointInTime(x: 1.0, y: 1.0, t: 1.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0001_0100)

        XCTAssertEqual(tree.subtrees[2]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[2]!.leaves[0].leafData, 88)
        XCTAssertEqual(tree.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[4]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[4]!.leaves[0].leafData, 99)
        XCTAssertEqual(tree.subtrees[4]!.encodeChildOccupancy(), 0b0000_0000)

        tree.add(leafData: 77, position: PointInTime(x: 9.0, y: 9.0, t: 1.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0001_0101)

        XCTAssertEqual(tree.subtrees[0]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[0]!.leaves[0].leafData, 77)
        XCTAssertEqual(tree.subtrees[0]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[2]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[2]!.leaves[0].leafData, 88)
        XCTAssertEqual(tree.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[4]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[4]!.leaves[0].leafData, 99)
        XCTAssertEqual(tree.subtrees[4]!.encodeChildOccupancy(), 0b0000_0000)

        tree.add(leafData: 66, position: PointInTime(x: 1.0, y: 1.0, t: 9.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0101_0101)

        XCTAssertEqual(tree.subtrees[0]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[0]!.leaves[0].leafData, 77)
        XCTAssertEqual(tree.subtrees[0]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[2]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[2]!.leaves[0].leafData, 88)
        XCTAssertEqual(tree.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[4]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[4]!.leaves[0].leafData, 99)
        XCTAssertEqual(tree.subtrees[4]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[6]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[6]!.leaves[0].leafData, 66)
        XCTAssertEqual(tree.subtrees[6]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [66, 77, 88, 99].sorted())
    }

    func testMaxLeaves3() throws {
        let boundingCube = CodableCube(cubeMin: PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 3, maximumDepth: INT64_MAX, id: getMonotonicId())

        tree.add(leafData: 99, position: PointInTime(x: 9.0, y: 9.0, t: 9.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [99].sorted())
        XCTAssertEqual(tree.leaves.count, 1)
        XCTAssertEqual(tree.leaves[0].leafData, 99)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_0000)

        tree.add(leafData: 88, position: PointInTime(x: 1.0, y: 1.0, t: 1.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [88, 99].sorted())
        XCTAssertEqual(tree.leaves.count, 2)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_0000)

        tree.add(leafData: 44, position: PointInTime(x: 0.5, y: 0.5, t: 0.5), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [44, 88, 99].sorted())
        XCTAssertEqual(tree.leaves.count, 3)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_0000)

        tree.add(leafData: 77, position: PointInTime(x: 9.0, y: 9.0, t: 1.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [44, 77, 88, 99].sorted())
        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0001_0101)

        XCTAssertEqual(tree.subtrees[0]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[0]!.leaves[0].leafData, 77)
        XCTAssertEqual(tree.subtrees[0]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[2]!.leaves.count, 2)
        XCTAssertEqual(tree.subtrees[2]!.leaves[0].leafData, 88)
        XCTAssertEqual(tree.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[4]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[4]!.leaves[0].leafData, 99)
        XCTAssertEqual(tree.subtrees[4]!.encodeChildOccupancy(), 0b0000_0000)
        tree.add(leafData: 66, position: PointInTime(x: 1.0, y: 1.0, t: 9.0), &unwrittenSubtrees, getMonotonicId)

        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [44, 66, 77, 88, 99].sorted())
    }

    func testUnk() {
        let boundingCube = CodableCube(cubeMin: PointInTime(x: -10.0, y: -10.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 20.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 2, maximumDepth: INT64_MAX, id: getMonotonicId())

        tree.add(leafData: 0, position: PointInTime(x: 2.791009, y: -2.105198, t: 12.061647420226365), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 1)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_0000)
        XCTAssertEqual(tree.elements(in: boundingCube), [0])

        // this next one gets lost
        tree.add(leafData: 1, position: PointInTime(x: 3.945531, y: -7.709396, t: 10.218332244975654), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 2)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_0000)
        XCTAssertEqual(tree.elements(in: boundingCube), [0, 1])

        tree.add(leafData: 5, position: PointInTime(x: -6.587713, y: 5.2082167, t: 14.221354951702283), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b1010_0000)

        XCTAssertEqual(tree.subtrees[7]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[7]!.leaves[0].leafData, 5)
        XCTAssertEqual(tree.subtrees[7]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[5]!.leaves.count, 2)
        XCTAssertEqual(tree.subtrees[5]!.leaves[0].leafData, 0)

        XCTAssertEqual(tree.subtrees[5]!.leaves[1].leafData, 1)
        XCTAssertEqual(tree.subtrees[5]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.elements(in: boundingCube), [0, 1, 5])

        tree.add(leafData: 32, position: PointInTime(x: 8.379137, y: -8.280867, t: 15.223665484713582), &unwrittenSubtrees, getMonotonicId)

        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b1010_0000)
        XCTAssertEqual(tree.elements(in: boundingCube), [1, 0, 32, 5])

        XCTAssertEqual(tree.subtrees[7]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[7]!.leaves[0].leafData, 5)
        XCTAssertEqual(tree.subtrees[7]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[5]!.leaves.count, 0)
        XCTAssertEqual(tree.subtrees[5]!.encodeChildOccupancy(), 0b0010_1100)

        XCTAssertEqual(tree.subtrees[5]!.subtrees[5]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[5]!.subtrees[5]!.leaves[0].leafData, 32)
        XCTAssertEqual(tree.subtrees[5]!.subtrees[5]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[5]!.subtrees[3]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[5]!.subtrees[3]!.leaves[0].leafData, 0)
        XCTAssertEqual(tree.subtrees[5]!.subtrees[3]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[5]!.subtrees[2]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[5]!.subtrees[2]!.leaves[0].leafData, 1)
        XCTAssertEqual(tree.subtrees[5]!.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.elements(in: boundingCube).count, 4)
    }

    func testBeep() throws {
        let filename = "unboundedDeserialization"

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        // write some stuff to disk
        let mt = MappedTree(filename)

        let boundingCube = CodableCube(cubeMin: PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId()) // monotonic id 0 is assigned in here

        // id 1 is used for the leaf, but is lost as the tree is instantly rebalanced
        // id 2, 3, 4, 5, 6, 7, 8, 9 are assigned for the eight subtree nodes
        tree.add(leafData: 9, position: PointInTime(x: 9.0, y: 0.0, t: 9.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 8, position: PointInTime(x: 8.0, y: 1.0, t: 8.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 7, position: PointInTime(x: 7.0, y: 2.0, t: 7.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 6, position: PointInTime(x: 6.0, y: 3.0, t: 6.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 5, position: PointInTime(x: 5.0, y: 4.0, t: 5.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 4, position: PointInTime(x: 4.0, y: 5.0, t: 4.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 3, position: PointInTime(x: 3.0, y: 6.0, t: 3.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 2, position: PointInTime(x: 2.0, y: 7.0, t: 2.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 1, position: PointInTime(x: 1.0, y: 1.0, t: 1.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 0, position: PointInTime(x: 5.0, y: 5.0, t: 5.0), &unwrittenSubtrees, getMonotonicId)

        // ids 10 and 11 are assigned to the leaves

//        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [0, 2, 3, 4, 5, 6, 7, 8, 9].sorted())
//        tree.add(1, at: PointInTime(x: 1.0, y: 1.0, t: 1.0), &unwrittenIds, getMonotonicId)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].sorted())

        mt.writeMetaTree(boundingCube)

        // so we need to write the treeIds to the .tree file
        // and let's keep another set of opIds for the leaves in the .bin file

        mt.serializeTree(tree)

//        tree file:
//        <[ids]><row occupancy UInt8s><[ids]><row occupancy UInt8s>
//        read id 0, then the row occupancy UInt8. that will tell you the next row's size: one id, and one row occupancy byte per bit set high

        try mt.close()

        // verify the results
        let bin = try helpy(filename, "bin")
        let idx = try helpy(filename, "idx")
        let treeIds = try helpy(filename, "tree")

//        XCTAssertEqual(bin, "cfe7dbe6b4764ad32d2362ccfaa1ddcd869ffeadfcec3962e50f087dff067dfe")
//        XCTAssertEqual(idx, "a1339479f7bfc2ccb7c01f0aea707d6bd97a299c337c99e4709e8d6592666258")
//        XCTAssertEqual(treeIds, "29f36fe84e7a30039dde5a976fddffeefbdbcb4317a752cc743d6e1952ec1a84")

        // now test deserialization
        let mt2 = MappedTree(filename)

        let treeMetadata = mt.readMetaTree()
        let boundingCube2 = CodableCube(cubeMin: treeMetadata!.cubeMin, cubeMax: treeMetadata!.cubeMax)
        var octree = Octree(boundingCube: boundingCube2, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: 0)
        mt2.restore(boundingCube, &octree)

        XCTAssertEqual(octree.elements(in: boundingCube).sorted(), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].sorted())

        // cleanup
        try mt2.close()
    }

    func testUnboundedDeserialization() throws {
        let filename = "unboundedDeserialization"

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        // write some stuff to disk
        let mt = MappedTree(filename)

        let boundingCube = CodableCube(cubeMin: PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId()) // monotonic id 0 is assigned in here

        tree.add(leafData: 9, position: PointInTime(x: 9.0, y: 0.0, t: 9.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 8, position: PointInTime(x: 8.0, y: 1.0, t: 8.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 7, position: PointInTime(x: 7.0, y: 2.0, t: 7.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 6, position: PointInTime(x: 6.0, y: 3.0, t: 6.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 5, position: PointInTime(x: 5.0, y: 4.0, t: 5.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 4, position: PointInTime(x: 4.0, y: 5.0, t: 4.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 3, position: PointInTime(x: 3.0, y: 6.0, t: 3.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 2, position: PointInTime(x: 2.0, y: 7.0, t: 2.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 1, position: PointInTime(x: 1.0, y: 1.0, t: 1.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 0, position: PointInTime(x: 5.0, y: 5.0, t: 5.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].sorted())

        mt.writeMetaTree(boundingCube)
        mt.serializeTree(tree)

        try mt.close()

        // verify the results
        let bin = try helpy(filename, "bin")
        let idx = try helpy(filename, "idx")
        let treeIds = try helpy(filename, "tree")

//        XCTAssertEqual(bin, "cfe7dbe6b4764ad32d2362ccfaa1ddcd869ffeadfcec3962e50f087dff067dfe")
//        XCTAssertEqual(idx, "a1339479f7bfc2ccb7c01f0aea707d6bd97a299c337c99e4709e8d6592666258")
//        XCTAssertEqual(treeIds, "29f36fe84e7a30039dde5a976fddffeefbdbcb4317a752cc743d6e1952ec1a84")

        // now test deserialization
        let mt2 = MappedTree(filename)

        let treeMetadata = mt.readMetaTree()
        let boundingCube2 = CodableCube(cubeMin: treeMetadata!.cubeMin, cubeMax: treeMetadata!.cubeMax)
        var octree = Octree(boundingCube: boundingCube2, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: 0)

        mt2.restore(boundingCube2, &octree)

        XCTAssertEqual(octree.elements(in: boundingCube).sorted(), [0, 5, 4, 2, 1, 3, 7, 6, 8, 9].sorted())

        // cleanup
        try mt2.close()
    }

    func testBoundedDeserialization() throws {
        let filename = "boundedDeserialization"

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        // write some stuff to disk
        let mt = MappedTree(filename)

        let boundingCube = CodableCube(cubeMin: PointInTime(x: -10.0, y: -10.0, t: -10.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }
        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId())

        tree.add(leafData: 1, position: PointInTime(x: 10.0, y: 10.0, t: 10.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 2, position: PointInTime(x: 9.0, y: 9.0, t: 9.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 3, position: PointInTime(x: 1.0, y: 1.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 4, position: PointInTime(x: 0.5, y: 0.5, t: 0.0), &unwrittenSubtrees, getMonotonicId)

        tree.add(leafData: 5, position: PointInTime(x: 10.0, y: -10.0, t: 10.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 6, position: PointInTime(x: 9.0, y: -9.0, t: 9.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 7, position: PointInTime(x: 1.0, y: -1.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 8, position: PointInTime(x: 0.5, y: -0.5, t: 0.0), &unwrittenSubtrees, getMonotonicId)

        tree.add(leafData: 9, position: PointInTime(x: -10.0, y: -10.0, t: -10.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 10, position: PointInTime(x: -9.0, y: -9.0, t: -9.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 11, position: PointInTime(x: -1.0, y: -1.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 12, position: PointInTime(x: -0.5, y: -0.5, t: 0.0), &unwrittenSubtrees, getMonotonicId)

        tree.add(leafData: 13, position: PointInTime(x: -10.0, y: 10.0, t: -10.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 14, position: PointInTime(x: -9.0, y: 9.0, t: -9.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 15, position: PointInTime(x: -1.0, y: 1.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 16, position: PointInTime(x: -0.5, y: 0.5, t: 0.0), &unwrittenSubtrees, getMonotonicId)

        XCTAssertEqual(tree.elements(in: boundingCube), [3, 4, 7, 8, 9, 10, 12, 11, 13, 14, 16, 15, 2, 1, 6, 5])

        mt.serializeTree(tree)
        mt.writeMetaTree(boundingCube)
        try mt.close()

        // verify the results
        let bin = try helpy(filename, "bin")
        let idx = try helpy(filename, "idx")
        let treeIds = try helpy(filename, "tree")

//        XCTAssertEqual(bin, "5411c53aca955f1f1a567c0680d39785f7044c8b34251b8a62607d41285cc940")
//        XCTAssertEqual(idx, "7275030237da1809d46de5bcd7426880adff6ddbb20b7dd42ba6a87f8bc7e6e6")
//        XCTAssertEqual(treeIds, "f8007145ca87cc0daa08e8e806f3b8f558ef773c7a38f03415d001d538b8a86d")

        // now test deserialization
        let mt2 = MappedTree(filename)

        let treeMetadata = mt.readMetaTree()
        let boundingCube2 = CodableCube(cubeMin: treeMetadata!.cubeMin, cubeMax: treeMetadata!.cubeMax)
        let smallCube = CodableCube(cubeMin: PointInTime(x: -1.0, y: -1.0, t: -1.0), cubeMax: PointInTime(x: 1.0, y: 1.0, t: 1.0))
        var octree = Octree(boundingCube: boundingCube2, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: 0) // getMonotonicId())

        mt2.restore(smallCube, &octree)

        XCTAssertEqual(octree.elements(in: smallCube), [3, 4, 7, 8, 12, 11, 16, 15])

        // cleanup
        try mt2.close()
    }

    func testPointAddition() throws {
        let filename = "pointAddition"

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        // write some stuff to disk
        let mt = MappedTree(filename)

        let boundingCube = CodableCube(cubeMin: PointInTime(x: -10.0, y: -10.0, t: -10.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var unwrittenIds = Set<Int64>()
        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }
        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId())
        unwrittenIds.insert(0)

        tree.add(leafData: 1, position: PointInTime(x: 10.0, y: 10.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 2, position: PointInTime(x: 9.0, y: 9.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 3, position: PointInTime(x: 1.0, y: 1.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 4, position: PointInTime(x: 0.5, y: 0.5, t: 0.0), &unwrittenSubtrees, getMonotonicId)

        tree.add(leafData: 5, position: PointInTime(x: 10.0, y: -10.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 6, position: PointInTime(x: 9.0, y: -9.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 7, position: PointInTime(x: 1.0, y: -1.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 8, position: PointInTime(x: 0.5, y: -0.5, t: 0.0), &unwrittenSubtrees, getMonotonicId)

        for subtree in unwrittenSubtrees {
            guard let parent = subtree.parent else { continue }
            mt.serializeTree(parent)
        }

        XCTAssertEqual(tree.elements(in: boundingCube), [1, 2, 3, 4, 5, 6, 7, 8])

        tree.add(leafData: 9, position: PointInTime(x: -10.0, y: -10.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 10, position: PointInTime(x: -9.0, y: -9.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 11, position: PointInTime(x: -1.0, y: -1.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 12, position: PointInTime(x: -0.5, y: -0.5, t: 0.0), &unwrittenSubtrees, getMonotonicId)

        tree.add(leafData: 13, position: PointInTime(x: -10.0, y: 10.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 14, position: PointInTime(x: -9.0, y: 9.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 15, position: PointInTime(x: -1.0, y: 1.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 16, position: PointInTime(x: -0.5, y: 0.5, t: 0.0), &unwrittenSubtrees, getMonotonicId)

        for subtree in unwrittenSubtrees {
            if subtree.parent != nil {
                mt.serializeTree(subtree.parent!)
            } else {
                mt.serializeTree(subtree)
            }
        }

        XCTAssertEqual(tree.elements(in: boundingCube), [1, 2, 3, 4, 5, 6, 7, 8, 12, 11, 10, 9, 16, 15, 14, 13])

        try mt.close()

        // verify the results
//        let bin = try helpy(filename, "bin")
//        let idx = try helpy(filename, "idx")
//        let treeIds = try helpy(filename, "tree")
//
//        XCTAssertEqual(bin, "13646ca7959754908088d190655f2df46e9f5cf989c3fa55e7b7736001db51b9")
//        XCTAssertEqual(idx, "bc77b27e4144d3edd9ea5d14c977464777a769a85008bb32634458e4995819ef")
//        XCTAssertEqual(treeIds, "cc69f1adb92f0134e9ac4863618caf4d6e03e06a57f5a3aec3f9eecfe1b0ac9b")

        // now test deserialization
        let mt2 = MappedTree(filename)

        let smallCube = CodableCube(cubeMin: PointInTime(x: -1.0, y: -1.0, t: -1.0), cubeMax: PointInTime(x: 1.0, y: 1.0, t: 1.0))
        var nt: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: 0)
        mt2.restore(boundingCube, &nt)

        XCTAssertEqual(nt.elements(in: smallCube), [3, 4, 7, 8, 12, 11, 16, 15])

        // cleanup
        try mt2.close()
    }

    func testOctree() {
        let boundingCube = CodableCube(cubeMin: PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }
        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId())

        tree.add(leafData: 1, position: PointInTime(x: 9.0, y: 9.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 2, position: PointInTime(x: 9.0, y: 1.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 3, position: PointInTime(x: 1.0, y: 1.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        tree.add(leafData: 4, position: PointInTime(x: 1.0, y: 9.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_1111)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [1, 2, 3, 4].sorted())

        XCTAssertEqual(tree.subtrees[0]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[0]!.leaves[0].leafData, 1)
        XCTAssertEqual(tree.subtrees[0]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[1]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[1]!.leaves[0].leafData, 2)
        XCTAssertEqual(tree.subtrees[1]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[2]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[2]!.leaves[0].leafData, 3)
        XCTAssertEqual(tree.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[3]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[3]!.leaves[0].leafData, 4)
        XCTAssertEqual(tree.subtrees[3]!.encodeChildOccupancy(), 0b0000_0000)

        tree.add(leafData: 5, position: PointInTime(x: 8.0, y: 8.0, t: 0.0), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.leaves.count, 0)
        XCTAssertEqual(tree.encodeChildOccupancy(), 0b0000_1111)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [1, 2, 3, 4, 5].sorted())

        XCTAssertEqual(tree.subtrees[0]!.leaves.count, 0)
        XCTAssertEqual(tree.subtrees[0]!.encodeChildOccupancy(), 0b0000_0001)

        XCTAssertEqual(tree.subtrees[0]!.subtrees[0]!.leaves.count, 0)
        XCTAssertEqual(tree.subtrees[0]!.subtrees[0]!.encodeChildOccupancy(), 0b0000_0101)

        XCTAssertEqual(tree.subtrees[0]!.subtrees[0]!.subtrees[0]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[0]!.subtrees[0]!.subtrees[0]!.leaves[0].leafData, 1)
        XCTAssertEqual(tree.subtrees[0]!.subtrees[0]!.subtrees[0]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[0]!.subtrees[0]!.subtrees[2]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[0]!.subtrees[0]!.subtrees[2]!.leaves[0].leafData, 5)
        XCTAssertEqual(tree.subtrees[0]!.subtrees[0]!.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[1]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[1]!.leaves[0].leafData, 2)
        XCTAssertEqual(tree.subtrees[1]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[2]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[2]!.leaves[0].leafData, 3)
        XCTAssertEqual(tree.subtrees[2]!.encodeChildOccupancy(), 0b0000_0000)

        XCTAssertEqual(tree.subtrees[3]!.leaves.count, 1)
        XCTAssertEqual(tree.subtrees[3]!.leaves[0].leafData, 4)
        XCTAssertEqual(tree.subtrees[3]!.encodeChildOccupancy(), 0b0000_0000)
    }

    func testOutOfBoundsAddition() throws {
        let filename = "outOfBoundsAddition"

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        // write some stuff to disk
        let mt = MappedTree(filename)

        let boundingCube = CodableCube(cubeMin: PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 10.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 100, maximumDepth: INT64_MAX, id: getMonotonicId())

        let disjointCube = CodableCube(cubeMin: PointInTime(x: -10.0, y: -10.0, t: 0.0), cubeMax: PointInTime(x: 0.0, y: 0.0, t: 10.0))
        let sampleData = generateData(count: 40, disjointCube) // NB: intentionally out of boundingCube range
        for (elementNumber, position, _) in sampleData {
            tree.add(leafData: UInt64(elementNumber), position: position, &unwrittenSubtrees, getMonotonicId)
        }
        XCTAssertEqual(tree.elements(in: boundingCube), [])
        mt.serializeTree(tree)
        try mt.close()

        // verify the results
//        let bin = try helpy(filename, "bin")
        let idx = try helpy(filename, "idx")
        let treeIds = try helpy(filename, "tree")

//        XCTAssertEqual(bin, "fc1987a027d5751b8cd176d8a5b44070f0da810052ea7f7371eba9a1d42ead71")
        XCTAssertEqual(idx, "7715d9fb1d8dcfb6d5b0771051156953a0c63796ad59a2b194bb3cda0133a821")
        XCTAssertEqual(treeIds, "3e7077fd2f66d689e0cee6a7cf5b37bf2dca7c979af356d0a31cbc5c85605c7d")

        // now test deserialization
        let mt2 = MappedTree(filename)
        var nt: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 100, maximumDepth: INT64_MAX, id: 0)
        mt2.restore(nil, &nt)
        XCTAssertEqual(nt.encodeChildOccupancy(), 0b0000_0000)

        // cleanup
        try mt2.close()
    }

    func testStress() throws {
        let filename = "stressTest"

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        // write some stuff to disk
        let mt = MappedTree(filename)

        let boundingCube = CodableCube(cubeMin: PointInTime(x: -10.0, y: -10.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 20.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let MAX_LEAVES_PER_NODE = 10

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: MAX_LEAVES_PER_NODE, maximumDepth: INT64_MAX, id: getMonotonicId())

        let POINT_COUNT = 2000
        let sampleData = generateData(count: POINT_COUNT, boundingCube)

        for (elementNumber, position, _) in sampleData {
            tree.add(leafData: UInt64(elementNumber), position: position, &unwrittenSubtrees, getMonotonicId)
        }

        mt.serializeTree(tree)
        try mt.close()

        // now test deserialization
        let mt2 = MappedTree(filename)
        var tree2: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: MAX_LEAVES_PER_NODE, maximumDepth: INT64_MAX, id: 0)

        mt2.restore(boundingCube, &tree2)

        XCTAssertEqual(tree2.elements(in: boundingCube).count, POINT_COUNT)

        // cleanup
        try mt2.close()
    }

    func testNonZeroBucketSize() throws {
        let filename = "nonZeroBucketSize"

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        // write some stuff to disk
        let mt = MappedTree(filename)

        let boundingCube = CodableCube(cubeMin: PointInTime(x: -10.0, y: -10.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 20.0))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let MAX_LEAVES_PER_NODE = 2

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: MAX_LEAVES_PER_NODE, maximumDepth: INT64_MAX, id: getMonotonicId())

        let POINT_COUNT = 3
        let sampleData = [
            (elementNumber: 0, position: PointInTime(x: 2.0972805, y: -6.823132, t: 0.22000450253976345)),
            (elementNumber: 1, position: PointInTime(x: -5.349231, y: 9.587854, t: 6.953131028316659)),
            (elementNumber: 2, position: PointInTime(x: -4.9593115, y: 0.3033867, t: 9.603878219516659)),
        ]

        for (elementNumber, position) in sampleData {
            tree.add(leafData: UInt64(elementNumber), position: position, &unwrittenSubtrees, getMonotonicId)
        }

        mt.serializeTree(tree)
        try mt.close()

        // now test deserialization
        let mt2 = MappedTree(filename)
        var tree2: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: MAX_LEAVES_PER_NODE, maximumDepth: INT64_MAX, id: 0)

        mt2.restore(boundingCube, &tree2)

        XCTAssertEqual(tree2.elements(in: boundingCube).count, POINT_COUNT)

        // cleanup
        try mt2.close()
    }

    func testOuter() throws {
        let filename = "outer"

        // this one has DrawOps
        // load up the tree
        // get a flat list of ids
        // load each DrawOp behind each id from the disk

        // delete any existing files
        del(getURL(filename, "bin"))
        del(getURL(filename, "idx"))
        del(getURL(filename, "tree"))

        // write some stuff to disk
        let mt = MappedTree(filename)

        let boundingCube = CodableCube(cubeMin: PointInTime(x: -10.0, y: -10.0, t: 0.0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 20.0))
        let POINT_COUNT = 60
        let sampleData = generateData(count: POINT_COUNT, boundingCube)

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let MAX_LEAVES_PER_NODE = 7

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: MAX_LEAVES_PER_NODE, maximumDepth: INT64_MAX, id: getMonotonicId())

        for (_, position, op) in sampleData {
            guard let encoded = encodeOp(op), let offset = mt.writeOp(encoded) else { continue }
            let id = getMonotonicId()
            mt.writeIndex(id, IndexRecord(offset: Int64(offset), size: UInt16(encoded.count), type: op.type.rawValue))

            tree.add(leafData: UInt64(id), position: position, &unwrittenSubtrees, getMonotonicId)
        }

        mt.serializeTree(tree)
        try mt.close()

        // now test deserialization
        let mt2 = MappedTree(filename)
        var tree2: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: MAX_LEAVES_PER_NODE, maximumDepth: INT64_MAX, id: 0)

        mt2.restore(boundingCube, &tree2)

        XCTAssertEqual(tree2.elements(in: boundingCube).count, POINT_COUNT)

        let elements = tree2.elements(in: boundingCube)
        var drawOps: [DrawOperation] = []
        for id in elements {
            guard let (opOffset, length, type) = mt2.readIndex(Int64(id)), let newOp = mt2.readOp(opOffset, length) else {
                XCTFail()
                continue
            }

            if type == NodeType.point.rawValue {
                let theOp = try BinaryDecoder(data: newOp).decode(Point.self)
                drawOps.append(theOp)
            } else {
                print("error, unexpected non-op of type: \(type), id: \(id)")
            }
        }

        XCTAssertEqual(drawOps.count, sampleData.count)

        // cleanup
        try mt2.close()
    }

    func testGo() {
        let mt = MappedTree("foo")

        let boundingCube = CodableCube(cubeMin: PointInTime(x: -10.0, y: -10.0, t: 0), cubeMax: PointInTime(x: 10.0, y: 10.0, t: 5000))

        var unwrittenSubtrees: [Octree] = []
        var _id: Int64 = 0
        func getMonotonicId() -> Int64 {
            let returnValue = _id
            _id += 1
            return returnValue
        }

        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 1, maximumDepth: INT64_MAX, id: getMonotonicId()) // monotonic id 0 is assigned in here

        tree.add(leafData: 1, position: PointInTime(x: 0.0, y: 0.0, t: 1.0), &unwrittenSubtrees, getMonotonicId)
        mt.printTree(tree)
        tree.add(leafData: 3, position: PointInTime(x: 0.0, y: 0.0, t: 2.0), &unwrittenSubtrees, getMonotonicId)
        mt.printTree(tree)
//        tree.add(leafData: 24, position: PointInTime(x: -0.47073144, y: 0.22030473, t: 653146429.107138), &unwrittenSubtrees, getMonotonicId)
//        mt.printTree(tree)
//        tree.add(leafData: 27, position: PointInTime(x: -0.47155505, y: 0.22097522, t: 653146429.112996), &unwrittenSubtrees, getMonotonicId)
//        mt.printTree(tree)
//        tree.add(leafData: 47, position: PointInTime(x: -0.47155505, y: 0.22097522, t: 653146429.120053), &unwrittenSubtrees, getMonotonicId)
//        mt.printTree(tree)
//        tree.add(leafData: 58, position: PointInTime(x: -0.47155505, y: 0.22097522, t: 653146429.136975), &unwrittenSubtrees, getMonotonicId)

//        tree.add(leafData: 1, position: PointInTime(x: 0.0, y: 0.0, t: 653146428.73627), &unwrittenSubtrees, getMonotonicId)
//        mt.printTree(tree)
//        tree.add(leafData: 3, position: PointInTime(x: 0.0, y: 0.0, t: 653146429.107138), &unwrittenSubtrees, getMonotonicId)
//        mt.printTree(tree)
//        tree.add(leafData: 24, position: PointInTime(x: -0.47073144, y: 0.22030473, t: 653146429.107138), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 27, position: PointInTime(x: -0.47155505, y: 0.22097522, t: 653146429.112996), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 47, position: PointInTime(x: -0.47155505, y: 0.22097522, t: 653146429.120053), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 58, position: PointInTime(x: -0.47155505, y: 0.22097522, t: 653146429.136975), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 69, position: PointInTime(x: -0.47155505, y: 0.22097522, t: 653146429.153345), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 80, position: PointInTime(x: -0.47120297, y: 0.22097522, t: 653146429.169986), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 91, position: PointInTime(x: -0.46548533, y: 0.22097522, t: 653146429.18679), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 102, position: PointInTime(x: -0.4552437, y: 0.22097522, t: 653146429.203961), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 113, position: PointInTime(x: -0.44087207, y: 0.22097522, t: 653146429.220664), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 124, position: PointInTime(x: -0.4185924, y: 0.22097522, t: 653146429.237143), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 135, position: PointInTime(x: -0.39739305, y: 0.2136097, t: 653146429.253921), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 146, position: PointInTime(x: -0.36400044, y: 0.16926116, t: 653146429.270621), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 157, position: PointInTime(x: -0.33391422, y: 0.07991296, t: 653146429.287469), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 169, position: PointInTime(x: -0.32022893, y: 0.011155188, t: 653146429.303783), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 180, position: PointInTime(x: -0.31622422, y: -0.031279087, t: 653146429.320785), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 183, position: PointInTime(x: -0.31415915, y: -0.065590024, t: 653146429.337219), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 203, position: PointInTime(x: -0.31261933, y: -0.09131098, t: 653146429.353748), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 214, position: PointInTime(x: -0.30717623, y: -0.10922921, t: 653146429.370465), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 225, position: PointInTime(x: -0.28506374, y: -0.10613918, t: 653146429.387198), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 236, position: PointInTime(x: -0.23103869, y: -0.061129928, t: 653146429.403802), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 247, position: PointInTime(x: -0.15610075, y: 0.0060634613, t: 653146429.420857), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 259, position: PointInTime(x: -0.10573429, y: 0.05004275, t: 653146429.437477), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 270, position: PointInTime(x: -0.065179765, y: 0.08029193, t: 653146429.453859), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 281, position: PointInTime(x: -0.029405773, y: 0.09999806, t: 653146429.4705), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 292, position: PointInTime(x: -0.008898675, y: 0.102884054, t: 653146429.487352), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 303, position: PointInTime(x: 0.0072813034, y: 0.088852644, t: 653146429.503686), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 314, position: PointInTime(x: 0.0191046, y: 0.014254928, t: 653146429.520518), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 325, position: PointInTime(x: 0.023664355, y: -0.054502845, t: 653146429.536894), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 328, position: PointInTime(x: 0.02749002, y: -0.095508814, t: 653146429.553776), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 348, position: PointInTime(x: 0.039760828, y: -0.14301538, t: 653146429.570553), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 359, position: PointInTime(x: 0.06147945, y: -0.15773666, t: 653146429.587187), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 370, position: PointInTime(x: 0.10315609, y: -0.1619345, t: 653146429.60377), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 381, position: PointInTime(x: 0.17963982, y: -0.15295589, t: 653146429.620392), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 392, position: PointInTime(x: 0.2513429, y: -0.13273478, t: 653146429.63735), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 404, position: PointInTime(x: 0.27946556, y: -0.12796366, t: 653146429.653841), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 415, position: PointInTime(x: 0.3080119, y: -0.12299824, t: 653146429.670544), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 426, position: PointInTime(x: 0.32754016, y: -0.118771315, t: 653146429.687275), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 437, position: PointInTime(x: 0.33307278, y: -0.11651695, t: 653146429.703962), &unwrittenSubtrees, getMonotonicId)
//        tree.add(leafData: 448, position: PointInTime(x: 0.0, y: 0.0, t: 653146429.715357), &unwrittenSubtrees, getMonotonicId)
        XCTAssertEqual(tree.elements(in: boundingCube).sorted(), [1, 3].sorted())
    }

    func testBoundingCubes() {
        let boundingCube = CodableCube(cubeMin: PointInTime(x: -100.0, y: -100.0, t: 0.0), cubeMax: PointInTime(x: 100.0, y: 100.0, t: 66))
        let tree: Octree = Octree(boundingCube: boundingCube, maxLeavesPerNode: 10, maximumDepth: INT64_MAX, id: 0)
        let bc = tree.calcBoundingCubes()

        print(bc)

//        [
//            ArezzoTests.CodableCube(cubeMin: ArezzoTests.PointInTime(x: 0.0, y: 0.0, t: 0.0), cubeMax: ArezzoTests.PointInTime(x: 100.0, y: 100.0, t: 331582498.3351525)),
//            ArezzoTests.CodableCube(cubeMin: ArezzoTests.PointInTime(x: 0.0, y: -100.0, t: 0.0), cubeMax: ArezzoTests.PointInTime(x: 100.0, y: 0.0, t: 331582498.3351525)),
//            ArezzoTests.CodableCube(cubeMin: ArezzoTests.PointInTime(x: -100.0, y: -100.0, t: 0.0), cubeMax: ArezzoTests.PointInTime(x: 0.0, y: 0.0, t: 331582498.3351525)),
//            ArezzoTests.CodableCube(cubeMin: ArezzoTests.PointInTime(x: -100.0, y: 0.0, t: 0.0), cubeMax: ArezzoTests.PointInTime(x: 0.0, y: 100.0, t: 331582498.3351525)),
//            ArezzoTests.CodableCube(cubeMin: ArezzoTests.PointInTime(x: 0.0, y: 0.0, t: 331582498.3351525), cubeMax: ArezzoTests.PointInTime(x: 100.0, y: 100.0, t: 663164996.670305)),
//            ArezzoTests.CodableCube(cubeMin: ArezzoTests.PointInTime(x: 0.0, y: -100.0, t: 331582498.3351525), cubeMax: ArezzoTests.PointInTime(x: 100.0, y: 0.0, t: 663164996.670305)),
//            ArezzoTests.CodableCube(cubeMin: ArezzoTests.PointInTime(x: -100.0, y: -100.0, t: 331582498.3351525), cubeMax: ArezzoTests.PointInTime(x: 0.0, y: 0.0, t: 663164996.670305)),
//            ArezzoTests.CodableCube(cubeMin: ArezzoTests.PointInTime(x: -100.0, y: 0.0, t: 331582498.3351525), cubeMax: ArezzoTests.PointInTime(x: 0.0, y: 100.0, t: 663164996.670305))
//        ]
    }
}
