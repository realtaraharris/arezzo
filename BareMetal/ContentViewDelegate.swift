//
//  ContentViewDelegate.swift
//  BareMetal
//
//  Created by Max Harris on 8/19/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

class ContentViewDelegate: ObservableObject {
    var didChange = PassthroughSubject<ContentViewDelegate, Never>()
    var objectWillChange = PassthroughSubject<ContentViewDelegate, Never>()

    var playing: Bool = false {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    var recording: Bool = false {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    // TODO: this is gross. is there nicer a way to call functions?
    var clear: Bool = false {
        didSet {
            didChange.send(self)
            clear = false
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    var selectedColor: Color = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0) {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    var strokeWidth: Float = DEFAULT_STROKE_THICKNESS {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    var mode: String = "draw" {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }

    var uiRects: [String: CGRect] = [:] {
        didSet {
            didChange.send(self)
        }

        willSet {
            objectWillChange.send(self)
        }
    }
}
