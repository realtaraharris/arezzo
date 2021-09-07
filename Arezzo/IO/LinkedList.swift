//
//  LinkedList.swift
//  StreamingTree
//
//  Created by Max Harris on 8/21/21.
//

public class Node<T> {
    var value: T
    var next: Node<T>?
    weak var previous: Node<T>?

    init(value: T) {
        self.value = value
    }
}

public class LinkedList<T> {
    private var head: Node<T>?
    private var tail: Node<T>?
    public var count: Int = 0

    public var isEmpty: Bool {
        self.head == nil
    }

    public var first: Node<T>? {
        self.head
    }

    public func append(value: T) {
        let newNode = Node(value: value)
        if let tailNode = tail {
            newNode.previous = tailNode
            tailNode.next = newNode
        } else {
            self.head = newNode
        }
        self.tail = newNode

        self.count += 1
    }

    public func remove(node: Node<T>) -> T {
        let prev = node.previous
        let next = node.next

        if let prev = prev {
            prev.next = next
        } else {
            self.head = next
        }
        next?.previous = prev

        if next == nil {
            self.tail = prev
        }

        node.previous = nil
        node.next = nil

        self.count -= 1

        return node.value
    }
}
