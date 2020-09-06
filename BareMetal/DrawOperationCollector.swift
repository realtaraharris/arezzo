//
//  DrawOperationCollector.swift
//  BareMetal
//
//  Created by Max Harris on 9/3/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation

class DrawOperationCollector {
    var drawOperations: [DrawOperation] = []
    var provisionalOpIndex = 0

    func addOp(_ op: DrawOperation) {
        drawOperations.append(op)
    }

    func beginProvisionalOps() {
        provisionalOpIndex = drawOperations.count
    }

    func commitProvisionalOps() {
        provisionalOpIndex = drawOperations.count
    }

    func cancelProvisionalOps() {
        drawOperations.removeSubrange(provisionalOpIndex ..< drawOperations.count)
    }
}
