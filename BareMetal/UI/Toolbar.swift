//
//  Toolbar.swift
//  BareMetal
//
//  Created by Max Harris on 9/1/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation
import UIKit

protocol ToolbarDelegate {
    func startRecording()
    func stopRecording()

    func startPlaying()
    func stopPlaying()

    func setDrawMode()
    func setPanMode()

    func setColor(color: UIColor)

    func save()
    func restore()
    func clear()

    func startExport()

    func setLineWidth(_ lineWidth: Float)
    func setPlaybackPosition(_ playbackPosition: Float)
}

class ToolbarView: UIView {
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let p1 = touch.location(in: self.superview)
            let p0 = touch.previousLocation(in: self.superview)
            let translation = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)

            // cancel the touches here or the view below will get drawn on
            touchesCancelled(touches, with: event)
        }
    }
}

extension UISlider {
    func setValueEx(value: Float) {
        let pixelPerPercent = 1 / self.frame.maxX

        let delta = value - self.value

        if CGFloat(delta) >= pixelPerPercent || value == 1.0 {
            self.setValue(value, animated: false)
        }
    }
}

@available(iOS 14.0, *)
@available(macCatalyst 14.0, *)
class Toolbar: UIViewController {
    var delegate: ToolbarDelegate?
    var recording: Bool = false
    var playing: Bool = false
    var mode: String = "draw"

    var recordButton: UIButton?
    var playButton: UIButton?
    var drawModeButton: UIButton?

    var saveButton: UIButton?
    var saveIndicator: UIActivityIndicatorView?

    var restoreButton: UIButton?
    var restoreProgressIndicator: UIProgressView?
    var clearButton: UIButton?

    var startExportButton: UIButton?
    var exportProgressIndicator: UIProgressView?

    var playbackSlider: UISlider?

    var colorPicker: UIColorPickerViewController?
    var colorSampleView: UIButton?

    @objc func pickColor(_: Any) {
        if (colorPicker == nil) {
            colorPicker = UIColorPickerViewController()
        }
        colorPicker!.delegate = self
        colorPicker!.selectedColor = colorSampleView!.backgroundColor ?? UIColor.black
        self.view.window?.rootViewController!.present(colorPicker!, animated: false, completion: nil)
    }

    override func loadView() {
        view = ToolbarView()
    }

    override func viewDidLoad() {
        if recordButton == nil {
            recordButton = UIButton(type: .system)
        }

        if playButton == nil {
            playButton = UIButton(type: .system)
        }

        if drawModeButton == nil {
            drawModeButton = UIButton(type: .system)
        }

        if saveButton == nil {
            saveButton = UIButton(type: .system)
        }

        if saveIndicator == nil {
            saveIndicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
        }

        if restoreButton == nil {
            restoreButton = UIButton(type: .system)
        }

        if restoreProgressIndicator == nil {
            restoreProgressIndicator = UIProgressView()
        }

        if clearButton == nil {
            clearButton = UIButton(type: .system)
        }

        if playbackSlider == nil {
            playbackSlider = UISlider()
        }

        if startExportButton == nil {
            startExportButton = UIButton(type: .system)
        }

        if exportProgressIndicator == nil {
            exportProgressIndicator = UIProgressView()
        }

        if colorSampleView == nil {
            colorSampleView = UIButton()
        }

        let cornerRadius: CGFloat = 10.0
        let titleEdgeInsets = UIEdgeInsets(top: 2, left: 5, bottom: 2, right: 5)

        recordButton!.translatesAutoresizingMaskIntoConstraints = false
        recordButton!.layer.cornerRadius = cornerRadius
        recordButton!.clipsToBounds = true
        recordButton!.titleEdgeInsets = titleEdgeInsets
        recordButton!.setTitle("\(!recording ? "Start" : "Stop") Recording", for: .normal)
        recordButton!.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        view.addSubview(recordButton!)

        playButton!.translatesAutoresizingMaskIntoConstraints = false
        playButton!.layer.cornerRadius = cornerRadius
        playButton!.clipsToBounds = true
        playButton!.titleEdgeInsets = titleEdgeInsets
        playButton!.setTitle("\(!recording ? "Start" : "Stop") Playing", for: .normal)
        playButton!.addTarget(self, action: #selector(togglePlaying), for: .touchUpInside)
        view.addSubview(playButton!)

        drawModeButton!.translatesAutoresizingMaskIntoConstraints = false
        drawModeButton!.layer.cornerRadius = cornerRadius
        drawModeButton!.clipsToBounds = true
        drawModeButton!.titleEdgeInsets = titleEdgeInsets
        drawModeButton!.setTitle(mode == "pan" ? "Pan" : "Draw", for: .normal)
        drawModeButton!.addTarget(self, action: #selector(toggleDrawMode), for: .touchUpInside)
        view.addSubview(drawModeButton!)

        saveButton!.translatesAutoresizingMaskIntoConstraints = false
        saveButton!.layer.cornerRadius = cornerRadius
        saveButton!.clipsToBounds = true
        saveButton!.titleEdgeInsets = titleEdgeInsets
        saveButton!.setTitle("Save", for: .normal)
        saveButton!.addTarget(self, action: #selector(save), for: .touchUpInside)
        view.addSubview(saveButton!)

        saveIndicator!.translatesAutoresizingMaskIntoConstraints = false
        saveIndicator!.clipsToBounds = true
        view.addSubview(saveIndicator!)

        restoreButton!.translatesAutoresizingMaskIntoConstraints = false
        restoreButton!.layer.cornerRadius = cornerRadius
        restoreButton!.clipsToBounds = true
        restoreButton!.titleEdgeInsets = titleEdgeInsets
        restoreButton!.setTitle("Restore", for: .normal)
        restoreButton!.addTarget(self, action: #selector(restore), for: .touchUpInside)
        view.addSubview(restoreButton!)

        restoreProgressIndicator!.translatesAutoresizingMaskIntoConstraints = false
        restoreProgressIndicator!.isHidden = true
        view.addSubview(restoreProgressIndicator!)

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

        let toolbarWidth: CGFloat = 1100
        let toolbarHeight: CGFloat = 120

        playbackSlider!.minimumValue = 0.0
        playbackSlider!.maximumValue = 1.0
        playbackSlider!.translatesAutoresizingMaskIntoConstraints = false
        playbackSlider!.addTarget(self, action: #selector(playbackSliderChanged), for: .valueChanged)
        let margin: CGFloat = 20
        view.addSubview(playbackSlider!)

        startExportButton!.translatesAutoresizingMaskIntoConstraints = false
        startExportButton!.layer.cornerRadius = cornerRadius
        startExportButton!.clipsToBounds = true
        startExportButton!.titleEdgeInsets = titleEdgeInsets
        startExportButton!.setTitle("Start Export", for: .normal)
        startExportButton!.addTarget(self, action: #selector(startExport), for: .touchUpInside)
        view.addSubview(startExportButton!)

        exportProgressIndicator!.translatesAutoresizingMaskIntoConstraints = false
        exportProgressIndicator!.isHidden = true
        view.addSubview(exportProgressIndicator!)

        colorSampleView!.translatesAutoresizingMaskIntoConstraints = false
        colorSampleView!.backgroundColor = UIColor.red
        colorSampleView!.layer.cornerRadius = cornerRadius
        colorSampleView!.clipsToBounds = true
        colorSampleView!.titleEdgeInsets = titleEdgeInsets
        colorSampleView!.addTarget(self, action: #selector(pickColor), for: .touchUpInside)
        view.addSubview(colorSampleView!)

        view.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        view.isUserInteractionEnabled = true
        view.frame = CGRect(x: 12, y: 40, width: toolbarWidth, height: toolbarHeight)

        NSLayoutConstraint.activate([
            thicknessSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            thicknessSlider.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            thicknessSlider.widthAnchor.constraint(equalToConstant: 80.0),

            playButton!.leadingAnchor.constraint(equalTo: thicknessSlider.trailingAnchor, constant: margin),
            playButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            playButton!.widthAnchor.constraint(equalToConstant: 130.0),

            drawModeButton!.leadingAnchor.constraint(equalTo: playButton!.trailingAnchor, constant: margin),
            drawModeButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            drawModeButton!.widthAnchor.constraint(equalToConstant: 80.0),

            colorSampleView!.leadingAnchor.constraint(equalTo: drawModeButton!.trailingAnchor, constant: margin),
            colorSampleView!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            colorSampleView!.widthAnchor.constraint(equalToConstant: 33.0),
            colorSampleView!.heightAnchor.constraint(equalToConstant: 20.0),

            recordButton!.leadingAnchor.constraint(equalTo: colorSampleView!.trailingAnchor, constant: margin),
            recordButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            recordButton!.widthAnchor.constraint(equalToConstant: 150.0),

            saveButton!.leadingAnchor.constraint(equalTo: recordButton!.trailingAnchor, constant: margin),
            saveButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            saveButton!.widthAnchor.constraint(equalToConstant: 80.0),

            saveIndicator!.leadingAnchor.constraint(equalTo: saveButton!.trailingAnchor, constant: 5.0),
            saveIndicator!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            saveIndicator!.widthAnchor.constraint(equalToConstant: 25.0),

            restoreButton!.leadingAnchor.constraint(equalTo: saveIndicator!.trailingAnchor, constant: 5.0),
            restoreButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            restoreButton!.widthAnchor.constraint(equalToConstant: 100.0),

            restoreProgressIndicator!.leadingAnchor.constraint(equalTo: saveIndicator!.trailingAnchor, constant: 5.0),
            restoreProgressIndicator!.topAnchor.constraint(equalTo: restoreButton!.bottomAnchor, constant: 5),
            restoreProgressIndicator!.widthAnchor.constraint(equalToConstant: 100.0),

            clearButton!.leadingAnchor.constraint(equalTo: restoreButton!.trailingAnchor, constant: margin),
            clearButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            clearButton!.widthAnchor.constraint(equalToConstant: 100.0),

            playbackSlider!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            playbackSlider!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin),
            playbackSlider!.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -(margin * 2)),

            startExportButton!.leadingAnchor.constraint(equalTo: clearButton!.trailingAnchor, constant: margin),
            startExportButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            startExportButton!.widthAnchor.constraint(equalToConstant: 100.0),

            exportProgressIndicator!.leadingAnchor.constraint(equalTo: clearButton!.trailingAnchor, constant: margin),
            exportProgressIndicator!.topAnchor.constraint(equalTo: startExportButton!.bottomAnchor, constant: 5),
            exportProgressIndicator!.widthAnchor.constraint(equalToConstant: 100.0),
        ])
    }

    @objc func toggleRecording() {
        print("toggleRecording()")
        if !recording {
            delegate?.startRecording()
        } else {
            delegate?.stopRecording()
        }

        recordButton!.setTitle("\(recording ? "Start" : "Stop") Recording", for: .normal)
        recording = !recording
    }

    @objc func togglePlaying() {
        print("togglePlaying()")
        if !playing {
            delegate?.startPlaying()
        } else {
            delegate?.stopPlaying()
        }

        playButton!.setTitle("\(playing ? "Start" : "Stop") Playing", for: .normal)
        playing = !playing
    }

    @objc func toggleDrawMode() {
        print("toggleDrawMode()")
        if mode != "draw" {
            delegate?.setDrawMode()
        } else {
            delegate?.setPanMode()
        }

        drawModeButton!.setTitle("\(self.mode == "draw" ? "Pan" : "Draw")", for: .normal)

        if self.mode == "draw" {
            self.mode = "pan"
        } else {
            self.mode = "draw"
        }
    }

    @objc func save() {
        delegate?.save()
    }

    @objc func restore() {
        delegate?.restore()
    }

    @objc func clear() {
        delegate?.clear()
    }

    @objc func startExport() {
        delegate?.startExport()
    }

    @objc func thicknessSliderChanged(_ sender: UISlider!) {
        delegate?.setLineWidth(sender.value)
    }

    @objc func playbackSliderChanged(_ sender: UISlider!) {
        delegate?.setPlaybackPosition(sender.value)
    }
}

@available(iOS 14.0, *)
@available(macCatalyst 14.0, *)
extension Toolbar: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        colorSampleView!.backgroundColor = viewController.selectedColor
        delegate?.setColor(color: viewController.selectedColor)
        viewController.dismiss(animated: false, completion: {})
    }

    func colorPickerViewControllerDidFinish(_: UIColorPickerViewController) {}
}
