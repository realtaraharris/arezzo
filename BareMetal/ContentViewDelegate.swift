//
//  ContentViewDelegate.swift
//  BareMetal
//
//  Created by Max Harris on 8/19/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Combine
import Foundation
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

    init(
        playing: Bool = false,
        recording: Bool = false,
        clear: Bool = false,
        selectedColor: Color = Color.red,
        strokeWidth: Float = DEFAULT_STROKE_THICKNESS,
        mode _: String = "draw",
        uiRect _: [String: CGRect] = [:]
    ) {
        self.playing = playing
        self.recording = recording
        self.clear = clear
        self.selectedColor = selectedColor
        self.strokeWidth = strokeWidth
    }

    func copy() -> ContentViewDelegate {
        let copy = ContentViewDelegate(
            playing: playing,
            recording: recording,
            clear: clear,
            selectedColor: selectedColor,
            strokeWidth: strokeWidth,
            mode: mode,
            uiRect: uiRects
        )
        return copy
    }
}
