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
    var drawButton: UIButton = UIButton(type: .custom)
    var panButton: UIButton = UIButton(type: .custom)
    var zoomButton: UIButton = UIButton(type: .custom)
    var undoButton: UIButton = UIButton(type: .custom)
    var redoButton: UIButton = UIButton(type: .custom)
    var clearButton: UIButton = UIButton(type: .custom)
    var portalButton: UIButton = UIButton(type: .custom)
    var micButton: UIButton = UIButton(type: .custom)

    var tempButton: UIButton = UIButton(type: .custom)

    var delegate: ToolbarDelegate?
    var recording: Bool = false
    var mode: PenDownMode = .draw
    var muted: Bool = true

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

        configureButton(self.drawButton, UIImage(systemName: "pencil")!)
        self.drawButton.addTarget(self, action: #selector(self.enterDrawMode), for: .touchUpInside)
        self.drawButton.tintColor = self.view.tintColor
        stackView.addArrangedSubview(self.drawButton)

        configureButton(self.panButton, UIImage(systemName: "hand.raised")!)
        self.panButton.addTarget(self, action: #selector(self.enterPanMode), for: .touchUpInside)
        stackView.addArrangedSubview(self.panButton)

        configureButton(self.portalButton, UIImage(systemName: "p.circle")!)
        self.portalButton.addTarget(self, action: #selector(self.enterPortalMode), for: .touchUpInside)
        stackView.addArrangedSubview(self.portalButton)

        configureButton(self.zoomButton, UIImage(systemName: "plus.magnifyingglass")!)
        self.zoomButton.addTarget(self, action: #selector(self.zoom), for: .touchUpInside)
        stackView.addArrangedSubview(self.zoomButton)

        configureButton(self.undoButton, UIImage(systemName: "arrow.uturn.backward")!)
        self.undoButton.addTarget(self, action: #selector(self.undo), for: .touchUpInside)
        stackView.addArrangedSubview(self.undoButton)

        configureButton(self.redoButton, UIImage(systemName: "arrow.uturn.forward")!)
        self.redoButton.addTarget(self, action: #selector(self.redo), for: .touchUpInside)
        stackView.addArrangedSubview(self.redoButton)

        configureButton(self.tempButton, UIImage(systemName: "bolt")!)
        self.tempButton.addTarget(self, action: #selector(self.switchPortals), for: .touchUpInside)
        stackView.addArrangedSubview(self.tempButton)

        configureButton(self.micButton, UIImage(systemName: "mic.slash")!)
        self.micButton.addTarget(self, action: #selector(self.mic), for: .touchUpInside)
        stackView.addArrangedSubview(self.micButton)

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

    @objc func enterDrawMode() {
        self.delegate?.setPenDownMode(mode: .draw)
        self.drawButton.tintColor = self.view.tintColor
        self.panButton.tintColor = .black
        self.portalButton.tintColor = .black
    }

    @objc func enterPanMode() {
        self.delegate?.setPenDownMode(mode: .pan)
        self.drawButton.tintColor = .black
        self.panButton.tintColor = self.view.tintColor
        self.portalButton.tintColor = .black
    }

    @objc func enterPortalMode() {
        self.delegate?.setPenDownMode(mode: .portal)
        self.drawButton.tintColor = .black
        self.panButton.tintColor = .black
        self.portalButton.tintColor = self.view.tintColor
    }

    @objc func zoom() {
        print("toggling zooming")
    }

    @objc func undo() {
        self.delegate?.undo()
    }

    @objc func redo() {
        self.delegate?.redo()
    }

    @objc func switchPortals() {
        self.delegate?.exitPortal()
    }

    @objc func mic() {
        if self.muted {
            self.micButton.setBackgroundImage(UIImage(systemName: "mic"), for: .normal)
            self.muted = false
        } else {
            self.micButton.setBackgroundImage(UIImage(systemName: "mic.slash"), for: .normal)
            self.muted = true
        }
        self.delegate?.recordAudio(self.muted)
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
