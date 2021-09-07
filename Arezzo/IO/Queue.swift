//
//  Queue.swift
//  StreamingTree
//
//  Created by Max Harris on 8/21/21.
//

public struct Queue<T>: ExpressibleByArrayLiteral {
    public private(set) var elements = LinkedList<T>()

    public mutating func push(value: T) { self.elements.append(value: value) } // O(1)

    public mutating func pop() -> T { self.elements.remove(node: self.elements.first!) } // O(1)

    public var isEmpty: Bool { self.elements.isEmpty }

    public var count: Int { self.elements.count }

    public init(arrayLiteral elements: T...) {
        for element in elements {
            self.elements.append(value: element) // = elements
        }
    }
}
