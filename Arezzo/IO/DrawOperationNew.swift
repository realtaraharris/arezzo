//
//  DrawOperation.swift
//  streaming-octree
//
//  Created by Max Harris on 7/8/21.
//

import BinaryCoder
import Foundation

enum NodeType: UInt8, BinaryCodable {
    case nodeRecord, leaf, line, pan, point, penDown, penUp, audioStart, audioClip, audioStop, portal, viewport, undo, redo
}

struct DrawOperationEx: BinaryCodable {
    var leafData: UInt64
    var position: PointInTime
    var id: Int64
}
