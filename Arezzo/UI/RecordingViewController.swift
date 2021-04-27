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
    var clearButton: UIButton = UIButton(type: .custom)
    var portalButton: UIButton = UIButton(type: .custom)

    var delegate: ToolbarDelegate?
    var recording: Bool = false
    var mode: PenDownMode = .draw

    override func loadView() {
        self.view = UIStackView()
    }

    override func viewDidLoad() {
        let stackView = self.view as! UIStackView
        stackView.alignment = .top
        stackView.spacing = 0.0
        stackView.axis = .horizontal

        configureButton(self.recordButton, UIImage(systemName: "record.circle")!)
        self.recordButton.addTarget(self, action: #selector(self.record), for: .touchUpInside)
        stackView.addArrangedSubview(self.recordButton)

        configureButton(self.panButton, UIImage(systemName: "pencil")!)
        self.panButton.addTarget(self, action: #selector(self.pan), for: .touchUpInside)
        self.panButton.tintColor = self.view.tintColor
        stackView.addArrangedSubview(self.panButton)

        configureButton(self.zoomButton, UIImage(systemName: "plus.magnifyingglass")!)
        self.zoomButton.addTarget(self, action: #selector(self.zoom), for: .touchUpInside)
        stackView.addArrangedSubview(self.zoomButton)

        configureButton(self.undoButton, UIImage(systemName: "arrow.uturn.backward")!)
        self.undoButton.addTarget(self, action: #selector(self.undo), for: .touchUpInside)
        stackView.addArrangedSubview(self.undoButton)

        configureButton(self.redoButton, UIImage(systemName: "arrow.uturn.forward")!)
        self.redoButton.addTarget(self, action: #selector(self.redo), for: .touchUpInside)
        stackView.addArrangedSubview(self.redoButton)

        configureButton(self.portalButton, UIImage(systemName: "p.circle")!)
        self.portalButton.addTarget(self, action: #selector(self.addPortal), for: .touchUpInside)
        stackView.addArrangedSubview(self.portalButton)

        /*
         clearButton!.translatesAutoresizingMaskIntoConstraints = false
         clearButton!.layer.cornerRadius = cornerRadius
         clearButton!.clipsToBounds = true
         clearButton!.titleEdgeInsets = titleEdgeInsets
         clearButton!.setTitle("Clear", for: .normal)
         clearButton!.addTarget(self, action: #selector(clear), for: .touchUpInside)
         view.addSubview(clearButton!)

         let thicknessSlider = UISlider()
         thicknessSlider.minimumValue = 5.0
         thicknessSlider.maximumValue = 50.0
         thicknessSlider.translatesAutoresizingMaskIntoConstraints = false
         thicknessSlider.addTarget(self, action: #selector(thicknessSliderChanged), for: .valueChanged)
         view.addSubview(thicknessSlider)
         */
    }

    @objc func record() {
        print("toggling recording")
        if !self.recording {
            self.recordButton.setBackgroundImage(UIImage(systemName: "stop.circle"), for: .normal)
            self.recordButton.tintColor = self.view.tintColor
            self.delegate?.startRecording()
        } else {
            self.recordButton.tintColor = .black
            self.recordButton.setBackgroundImage(UIImage(systemName: "record.circle"), for: .normal)
            self.delegate?.stopRecording()
        }

        self.recording = !self.recording
    }

    @objc func pan() {
        if self.mode != .draw {
            self.delegate?.setPenDownMode(mode: .draw)
        } else {
            self.delegate?.setPenDownMode(mode: .pan)
        }

        self.panButton.setBackgroundImage(
            self.mode == .draw ? UIImage(systemName: "hand.raised") : UIImage(systemName: "pencil"), for: .normal
        )

        if self.mode == .draw {
            self.mode = .pan
        } else {
            self.mode = .draw
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

    @objc func addPortal() {
        self.delegate?.setPenDownMode(mode: .portal)
    }

    @objc func switchPortals() {
        self.delegate?.switchPortals()
    }

    /*
     @objc func clear() {
         delegate?.clear()
     }

     @objc func thicknessSliderChanged(_ sender: UISlider!) {
         delegate?.setLineWidth(sender.value)
     }
      */
}
