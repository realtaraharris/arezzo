//
//  Octree.swift
//
// https://github.com/bikemap/BMQuadtree/blob/develop/BMQuadtreePlayground.playground/Sources/BMQuadtree.swift

import BinaryCoder
import Foundation
import simd

// bitwise masks for each child position
// 0b0000_0001 == 1
// 0b0000_0010 == 2
// 0b0000_0100 == 4
// 0b0000_1000 == 8
// 0b0001_0000 == 16
// 0b0010_0000 == 32
// 0b0100_0000 == 64
// 0b1000_0000 == 128
let pow2table: [UInt8] = [1, 2, 4, 8, 16, 32, 64, 128]

func highBitPositions(_ input: UInt8) -> [Int] {
    var result: [Int] = []
    for i in 0 ..< 8 {
        if input & pow2table[i] > 0 {
            result.append(i)
        }
    }
    return result
}

struct PointInTime: BinaryCodable {
    var x: Float
    var y: Float
    var t: Double
}

// axis-aligned cube
public struct CodableCube: BinaryCodable {
    var cubeMin: PointInTime
    var cubeMax: PointInTime
}

extension CodableCube {
    /// check if the point specified is within this cube
    ///
    /// - Parameter point: the point to query
    /// - Returns: returns true if the point specified is within the cube
    func contains(_ point: PointInTime) -> Bool {
        // above lower left front corner
        let gtMin = (point.x >= self.cubeMin.x && point.y >= self.cubeMin.y && point.t >= self.cubeMin.t)

        // below upper right rear corner
        let leMax = (point.x <= self.cubeMax.x && point.y <= self.cubeMax.y && point.t <= self.cubeMax.t)

        // if both are true, the point is inside the cube
        return (gtMin && leMax)
    }

    /// check if the specified cube intersects with itself
    ///
    /// - Parameter cube: the cube to query
    /// - Returns: returns true if the cube intersects
    public func intersects(_ cube: CodableCube) -> Bool {
        if self.cubeMin.x > cube.cubeMax.x ||
            self.cubeMin.y > cube.cubeMax.y ||
            self.cubeMin.t > cube.cubeMax.t {
            return false
        }

        if self.cubeMax.x < cube.cubeMin.x ||
            self.cubeMax.y < cube.cubeMin.y ||
            self.cubeMax.t < cube.cubeMin.t {
            return false
        }

        return true
    }
}

public final class Octree {
    var cube: CodableCube // bounding cube

    var subtrees: [Octree?] = [nil, nil, nil, nil, nil, nil, nil, nil]

    var depth: Int64 = 0
    public var id: Int64

    /// the maximum depth of the tree. this limit allows us to avoid infinite loops
    /// when adding the same, or very close elements in large numbers.
    /// this limits the maximum number of elements stored in the tree:
    /// numberOfNodes ^ maximumDepth * maxLeavesPerNode
    /// 8 ^ 10 * 10 = 10,737,418,240
    private var maximumDepth: Int64 = 0

    init(
        boundingCube cube: CodableCube,
        maxLeavesPerNode: Int = 1,
        maximumDepth: Int64 = 100_000,
        id: Int64
    ) {
        self.cube = cube
        self.maxLeavesPerNode = maxLeavesPerNode
        self.maximumDepth = maximumDepth
        self.id = id
    }

    /// adds a leaf to this octree with a given point
    /// this data will always reside in the leaf node its point is in
    ///
    /// - Parameters:
    ///   - element: the element to store
    ///   - point: the point associated with the element you want to store
    /// - Returns: the octree node the element was added to
    @discardableResult func add(leafData: UInt64, position: PointInTime, _ subtreeTracker: inout [Octree], _ getMonotonicId: () -> Int64) -> Octree? {
        if self.depth >= self.maximumDepth {
            print("warning: exceeded maximum depth of \(self.maximumDepth) with \(self.depth)")
        }

        let leaf = DrawOperationEx(leafData: leafData, position: position, id: getMonotonicId())

        // check to see if the leaf fits without rebalancing
        if self.leaves.count < self.maxLeavesPerNode, self.hasChildren == false {
            if self.depth > 10 {
                print("Octree depth", leaf.leafData, self.depth, self.maxLeavesPerNode)
            }

            self.leaves.append(leaf)
            subtreeTracker.append(self)
            return self
        }

        // redistribute the points by moving them into subtrees
        var newSubtree: Octree?
        var existingElements: [DrawOperationEx] = self.leaves
        existingElements.append(leaf)
        let boundingCubes = self.calcBoundingCubes()
        for element in existingElements {
            for i in 0 ..< 8 {
                if !boundingCubes[i].contains(element.position) { continue } // only add cubes containing the point

                guard let s = self.subtrees[i] else {
                    let subtree = Octree(boundingCube: boundingCubes[i], maxLeavesPerNode: self.maxLeavesPerNode, id: getMonotonicId())
                    subtree.parent = self
                    subtree.leaves.append(
                        DrawOperationEx(leafData: element.leafData, position: element.position, id: element.id)
                    )
                    self.subtrees[i] = subtree
                    break
                }
                newSubtree = s.add(leafData: element.leafData, position: element.position, &subtreeTracker, getMonotonicId)
                break
            }
        }

        if self.hasChildren {
            self.leaves.removeAll() // all these leaves are reassigned
        }

        if newSubtree != nil {
            subtreeTracker.append(newSubtree!)
        }
        return newSubtree
    }

    /// returns all of the elements in the octree node this
    /// point would be placed in
    ///
    /// - Parameter point: the point to query
    /// - Returns: an array of all the data found at the octree node this
    /// point would be placed in
    func elements(at point: PointInTime) -> [UInt64] {
        var elements: [UInt64] = []

        // if point is outside the tree bounds, return empty array
        if self.cube.contains(point) == false {
            return elements
        }

        if self.hasChildren == false {
            elements = self.leaves.compactMap { $0.leafData }
        } else {
            for i in 0 ..< 8 {
                guard let subtree = self.subtrees[i] else { continue }
                elements.append(contentsOf: subtree.elements(at: point))
            }
        }
        return elements
    }

    /// returns all of the elements that resides in octree nodes which
    /// intersect the given cube. recursively check if the search cube contains
    /// the points in the cube
    ///
    /// - Parameter cube: the cube you want to test
    /// - Returns: an arry of all the elements in all of the nodes that
    /// intersect the given cube
    public func elements(in cube: CodableCube) -> [UInt64] {
        var elements: [UInt64] = []

        // return early if the search cube does not intersect with self
        if self.cube.intersects(cube) == false {
            return elements
        }

        if self.hasChildren == false {
            // if there is no leaf, filter the objects, which are in the search cube
            elements = self
                .leaves
                .filter { cube.contains($0.position) }
                .compactMap { $0.leafData }
        }

        for i in 0 ..< 8 {
            guard let subtree = self.subtrees[i] else { continue }
            elements.append(contentsOf: subtree.elements(in: cube))
        }

        return elements
    }

    /// keep a reference to the parent so we can search nearby cubes and unsubdivide after deletion
    public weak var parent: Octree? {
        didSet {
            self.depth = self.parent!.depth + 1
        }
    }

    /// the maximum number of leaves allowed  per node before the subtree is rebalanced
    var maxLeavesPerNode: Int = 1

    /// leaves stored in this node
    var leaves: [DrawOperationEx] = []

    /// true if the tree has leaves
    /// we can be sure that there are no objects stored direclty in the tree, but only in its leaves
    internal var hasChildren: Bool {
        for i in 0 ..< 8 {
            if self.subtrees[i] != nil { return true }
        }
        return false
    }

    func calcBoundingCubes() -> [CodableCube] {
        let minX = self.cube.cubeMin.x
        let minY = self.cube.cubeMin.y
        let minZ = self.cube.cubeMin.t

        let maxX = self.cube.cubeMax.x
        let maxY = self.cube.cubeMax.y
        let maxZ = self.cube.cubeMax.t

        let deltaX = maxX - minX
        let deltaY = maxY - minY
        let deltaZ = maxZ - minZ

        return [
            CodableCube(
                cubeMin: PointInTime(x: minX + deltaX / 2, y: minY + deltaY / 2, t: minZ),
                cubeMax: PointInTime(x: maxX, y: maxY, t: maxZ - deltaZ / 2)
            ),
            CodableCube(
                cubeMin: PointInTime(x: minX + deltaX / 2, y: minY, t: minZ),
                cubeMax: PointInTime(x: maxX, y: maxY - deltaY / 2, t: maxZ - deltaZ / 2)
            ),
            CodableCube(
                cubeMin: PointInTime(x: minX, y: minY, t: minZ),
                cubeMax: PointInTime(x: minX + deltaX / 2, y: minY + deltaY / 2, t: maxZ - deltaZ / 2)
            ),
            CodableCube(
                cubeMin: PointInTime(x: minX, y: minY + deltaY / 2, t: minZ),
                cubeMax: PointInTime(x: maxX - deltaX / 2, y: maxY, t: maxZ - deltaZ / 2)
            ),
            CodableCube(
                cubeMin: PointInTime(x: minX + deltaX / 2, y: minY + deltaY / 2, t: maxZ - deltaZ / 2),
                cubeMax: PointInTime(x: maxX, y: maxY, t: maxZ)
            ),
            CodableCube(
                cubeMin: PointInTime(x: minX + deltaX / 2, y: minY, t: maxZ - deltaZ / 2),
                cubeMax: PointInTime(x: maxX, y: maxY - deltaY / 2, t: maxZ)
            ),
            CodableCube(
                cubeMin: PointInTime(x: minX, y: minY, t: maxZ - deltaZ / 2),
                cubeMax: PointInTime(x: minX + deltaX / 2, y: minY + deltaY / 2, t: maxZ)
            ),
            CodableCube(
                cubeMin: PointInTime(x: minX, y: minY + deltaY / 2, t: maxZ - deltaZ / 2),
                cubeMax: PointInTime(x: maxX - deltaX / 2, y: maxY, t: maxZ)
            ),
        ]
    }

    func split(_ id: Int64, _ slotNumber: Int) -> Octree {
        let boundingCubes = self.calcBoundingCubes()
        let subtree = Octree(
            boundingCube: boundingCubes[slotNumber],
            maxLeavesPerNode: self.maxLeavesPerNode,
            id: id
        )
        subtree.parent = self
        self.subtrees[slotNumber] = subtree
        return subtree
    }

    /// optimise the octree by cleaning up after removing elements
    /// if the number of elements in all child cubes are less then minimumCellSize,
    /// delete all the child cubes and place the objects into the parent
    // if all cubes are empty, delete them all
    private func unify() {
        var empty = true
        for i in 0 ..< 8 {
            guard let subtree = self.subtrees[i] else { continue }
            if subtree.leaves.count > 0 { empty = false }
        }

        if empty {
            for i in 0 ..< 8 {
                self.subtrees[i] = nil
            }
        }
    }

    func encodeChildOccupancy() -> UInt8 {
        var scratch: UInt8 = 0

        for i in 0 ..< 8 {
            if self.subtrees[i] != nil {
                scratch = scratch | pow2table[i]
            }
        }

        return scratch
    }
}
