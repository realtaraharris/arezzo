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
            self.didChange.send(self)
        }

        willSet {
            self.objectWillChange.send(self)
        }
    }

    var recording: Bool = false {
        didSet {
            self.didChange.send(self)
        }

        willSet {
            self.objectWillChange.send(self)
        }
    }

    // TODO: this is gross. is there nicer a way to call functions?
    var clear: Bool = false {
        didSet {
            self.didChange.send(self)
            self.clear = false
        }

        willSet {
            self.objectWillChange.send(self)
        }
    }

    var selectedColor: Color = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0) {
        didSet {
            self.didChange.send(self)
        }

        willSet {
            self.objectWillChange.send(self)
        }
    }

    var lineWidth: Float = DEFAULT_LINE_WIDTH {
        didSet {
            self.didChange.send(self)
        }

        willSet {
            self.objectWillChange.send(self)
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
            self.didChange.send(self)
        }

        willSet {
            self.objectWillChange.send(self)
        }
    }

    init(
        playing: Bool = false,
        recording: Bool = false,
        clear: Bool = false,
        selectedColor: Color = Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0),
        lineWidth: Float = DEFAULT_LINE_WIDTH,
        mode _: String = "draw",
        uiRect _: [String: CGRect] = [:]
    ) {
        self.playing = playing
        self.recording = recording
        self.clear = clear
        self.selectedColor = selectedColor
        self.lineWidth = lineWidth
    }

    func copy() -> ContentViewDelegate {
        let copy = ContentViewDelegate(
            playing: playing,
            recording: recording,
            clear: clear,
            selectedColor: selectedColor,
            lineWidth: lineWidth,
            mode: mode,
            uiRect: uiRects
        )
        return copy
    }
}
