//
//  Timestamps.swift
//  BareMetal
//
//  Created by Max Harris on 11/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation

struct Timestamps: Sequence {
    let timestamps: [Int64]

    func makeIterator() -> TimestampIterator {
        TimestampIterator(self.timestamps)
    }
}

struct TimestampIterator: IteratorProtocol {
    private let values: [Int64]
    private var index: Int?

    init(_ values: [Int64]) {
        self.values = values
    }

    private func nextIndex(for index: Int?) -> Int? {
        if let index = index, index < self.values.count - 1 {
            return index + 1
        }
        if index == nil, !self.values.isEmpty {
            return 0
        }
        return nil
    }

    mutating func next() -> (Int64, Int64)? {
        if let index = self.nextIndex(for: self.index) {
            self.index = index

            let a = self.values[index]
            let b = (index + 1 < self.values.count) ? self.values[index + 1] : -1
            return (a, b)
        }
        return nil
    }
}

/*
 var timestamps = Timestamps(timestamps: [getCurrentTimestamp(), getCurrentTimestamp(), getCurrentTimestamp(), getCurrentTimestamp(), getCurrentTimestamp(), getCurrentTimestamp(), getCurrentTimestamp(), getCurrentTimestamp(), getCurrentTimestamp()])

 for timestamp in timestamps {
     print(timestamp)
 }
 */
