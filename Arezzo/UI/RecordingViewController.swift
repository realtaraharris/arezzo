//
//  RecordingView.swift
//  Arezzo
//
//  Created by Max Harris on 3/23/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import UIKit

class RecordingViewController: UIViewController {
    var recordButton: UIButton = UIButton(type: .custom)
    var panButton: UIButton = UIButton(type: .custom)
    var zoomButton: UIButton = UIButton(type: .custom)
    var undoButton: UIButton = UIButton(type: .custom)
    var redoButton: UIButton = UIButton(type: .custom)

    var delegate: ToolbarDelegate?
    var recording: Bool = false
    var mode: String = "draw"

    override func viewDidLoad() {
        configureButton(self.recordButton, UIImage(systemName: "record.circle")!)
        self.recordButton.addTarget(self, action: #selector(self.record), for: .touchUpInside)
        view.addSubview(self.recordButton)

        configureButton(self.panButton, UIImage(systemName: "hand.raised")!)
        self.panButton.addTarget(self, action: #selector(self.pan), for: .touchUpInside)
        view.addSubview(self.panButton)

        configureButton(self.zoomButton, UIImage(systemName: "plus.magnifyingglass")!)
        self.zoomButton.addTarget(self, action: #selector(self.zoom), for: .touchUpInside)
        view.addSubview(self.zoomButton)

        configureButton(self.undoButton, UIImage(systemName: "arrow.uturn.backward")!)
        self.undoButton.addTarget(self, action: #selector(self.undo), for: .touchUpInside)
        view.addSubview(self.undoButton)

        configureButton(self.redoButton, UIImage(systemName: "arrow.uturn.forward")!)
        self.redoButton.addTarget(self, action: #selector(self.redo), for: .touchUpInside)
        view.addSubview(self.redoButton)

        NSLayoutConstraint.activate([
            self.recordButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            self.recordButton.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            self.recordButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            self.recordButton.heightAnchor.constraint(equalToConstant: buttonHeight),

            self.panButton.leadingAnchor.constraint(equalTo: self.recordButton.trailingAnchor, constant: margin),
            self.panButton.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            self.panButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            self.panButton.heightAnchor.constraint(equalToConstant: buttonHeight),

            self.zoomButton.leadingAnchor.constraint(equalTo: self.panButton.trailingAnchor, constant: 0),
            self.zoomButton.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            self.zoomButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            self.zoomButton.heightAnchor.constraint(equalToConstant: buttonHeight),

            self.undoButton.leadingAnchor.constraint(equalTo: self.zoomButton.trailingAnchor, constant: margin),
            self.undoButton.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            self.undoButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            self.undoButton.heightAnchor.constraint(equalToConstant: buttonHeight),

            self.redoButton.leadingAnchor.constraint(equalTo: self.undoButton.trailingAnchor, constant: 0),
            self.redoButton.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            self.redoButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            self.redoButton.heightAnchor.constraint(equalToConstant: buttonHeight),
        ])
    }

    @objc func record() {
        print("toggling recording")
        if !self.recording {
            self.delegate?.startRecording()
        } else {
            self.delegate?.stopRecording()
        }

        self.recording = !self.recording
    }

    @objc func pan() {
        print("toggleDrawMode()")
        if self.mode != "draw" {
            self.delegate?.setDrawMode()
        } else {
            self.delegate?.setPanMode()
        }

        self.panButton.setImage(
            self.mode == "draw" ? UIImage(systemName: "hand.raised") : UIImage(systemName: "pencil"), for: .normal
        )

        if self.mode == "draw" {
            self.mode = "pan"
        } else {
            self.mode = "draw"
        }
    }

    @objc func zoom() {
        print("toggling zooming")
    }

    @objc func undo() {
        print("toggling undo")
    }

    @objc func redo() {
        print("toggling redo")
    }
}
