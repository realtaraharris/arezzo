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

    func save()
    func restore()
    func clear()

    func setLineWidth(_ lineWidth: Float)
    func setPlaybackPosition(_ playbackPosition: Float)
}

class ToolbarView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let frameRect = CGRect(x: 0, y: 0,
                               width: frame.size.width,
                               height: frame.size.height)

        if frameRect.contains(point) {
//            print("frame: \(frame), \(point)")
            return true
        }

        for subview in subviews as [UIView] {
            if !subview.isHidden, subview.alpha > 0, subview.isUserInteractionEnabled, subview.point(inside: convert(point, to: subview), with: event) {
//                print("point: true")
                return true
            }
        }
//        print("point: false")
        return false
    }
}

class Toolbar: UIViewController {
    var delegate: ToolbarDelegate?
    var recording: Bool = false
    var playing: Bool = false
    var mode: String = "draw"

    var recordButton: UIButton?
    var playButton: UIButton?
    var drawModeButton: UIButton?

    var saveButton: UIButton?
    var restoreButton: UIButton?
    var clearButton: UIButton?

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

        if restoreButton == nil {
            restoreButton = UIButton(type: .system)
        }

        if clearButton == nil {
            clearButton = UIButton(type: .system)
        }

        let gesture = UIPanGestureRecognizer(target: self, action: #selector(panView(_:)))
        gesture.cancelsTouchesInView = true
        view.addGestureRecognizer(gesture)

        let cornerRadius: CGFloat = 10.0
        let titleEdgeInsets = UIEdgeInsets(top: 2, left: 5, bottom: 2, right: 5)

        recordButton!.translatesAutoresizingMaskIntoConstraints = false
        recordButton!.backgroundColor = UIColor.darkGray
        recordButton!.layer.cornerRadius = cornerRadius
        recordButton!.clipsToBounds = true
        recordButton!.titleEdgeInsets = titleEdgeInsets
        recordButton!.setTitle("\(!recording ? "Start" : "Stop") Recording", for: .normal)
        recordButton!.addTarget(self, action: #selector(toggleRecording), for: .touchUpInside)
        view.addSubview(recordButton!)

        playButton!.translatesAutoresizingMaskIntoConstraints = false
        playButton!.backgroundColor = UIColor.darkGray
        playButton!.layer.cornerRadius = cornerRadius
        playButton!.clipsToBounds = true
        playButton!.titleEdgeInsets = titleEdgeInsets
        playButton!.setTitle("\(!recording ? "Start" : "Stop") Playing", for: .normal)
        playButton!.addTarget(self, action: #selector(togglePlaying), for: .touchUpInside)
        view.addSubview(playButton!)

        drawModeButton!.translatesAutoresizingMaskIntoConstraints = false
        drawModeButton!.backgroundColor = UIColor.darkGray
        drawModeButton!.layer.cornerRadius = cornerRadius
        drawModeButton!.clipsToBounds = true
        drawModeButton!.titleEdgeInsets = titleEdgeInsets
        drawModeButton!.setTitle(mode == "pan" ? "Pan" : "Draw", for: .normal)
        drawModeButton!.addTarget(self, action: #selector(toggleDrawMode), for: .touchUpInside)
        view.addSubview(drawModeButton!)

        saveButton!.translatesAutoresizingMaskIntoConstraints = false
        saveButton!.backgroundColor = UIColor.darkGray
        saveButton!.layer.cornerRadius = cornerRadius
        saveButton!.clipsToBounds = true
        saveButton!.titleEdgeInsets = titleEdgeInsets
        saveButton!.setTitle("Save", for: .normal)
        saveButton!.addTarget(self, action: #selector(save), for: .touchUpInside)
        view.addSubview(saveButton!)

        restoreButton!.translatesAutoresizingMaskIntoConstraints = false
        restoreButton!.backgroundColor = UIColor.darkGray
        restoreButton!.layer.cornerRadius = cornerRadius
        restoreButton!.clipsToBounds = true
        restoreButton!.titleEdgeInsets = titleEdgeInsets
        restoreButton!.setTitle("Restore", for: .normal)
        restoreButton!.addTarget(self, action: #selector(restore), for: .touchUpInside)
        view.addSubview(restoreButton!)

        clearButton!.translatesAutoresizingMaskIntoConstraints = false
        clearButton!.backgroundColor = UIColor.darkGray
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

        let toolbarWidth: CGFloat = 880
        let toolbarHeight: CGFloat = 120
        let playbackSlider = UISlider()
        playbackSlider.minimumValue = 0
        playbackSlider.maximumValue = 100
        playbackSlider.translatesAutoresizingMaskIntoConstraints = false
        playbackSlider.addTarget(self, action: #selector(playbackSliderChanged), for: .valueChanged)
        let margin: CGFloat = 20
        view.addSubview(playbackSlider)

        view.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        view.isUserInteractionEnabled = true
        view.frame = CGRect(x: 100, y: 100, width: toolbarWidth, height: toolbarHeight)

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

            recordButton!.leadingAnchor.constraint(equalTo: drawModeButton!.trailingAnchor, constant: margin),
            recordButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            recordButton!.widthAnchor.constraint(equalToConstant: 150.0),

            saveButton!.leadingAnchor.constraint(equalTo: recordButton!.trailingAnchor, constant: margin),
            saveButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            saveButton!.widthAnchor.constraint(equalToConstant: 80.0),

            restoreButton!.leadingAnchor.constraint(equalTo: saveButton!.trailingAnchor, constant: margin),
            restoreButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            restoreButton!.widthAnchor.constraint(equalToConstant: 100.0),

            clearButton!.leadingAnchor.constraint(equalTo: restoreButton!.trailingAnchor, constant: margin),
            clearButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            clearButton!.widthAnchor.constraint(equalToConstant: 100.0),

            playbackSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            playbackSlider.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin),
            playbackSlider.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -(margin * 2)),
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

    @objc func thicknessSliderChanged(_ sender: UISlider!) {
        delegate?.setLineWidth(sender.value)
    }

    @objc func playbackSliderChanged(_ sender: UISlider!) {
        delegate?.setPlaybackPosition(sender.value)
    }

    @objc func panView(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: view)

        if let viewToDrag = sender.view {
            viewToDrag.center = CGPoint(x: viewToDrag.center.x + translation.x,
                                        y: viewToDrag.center.y + translation.y)
            sender.setTranslation(CGPoint(x: 0, y: 0), in: viewToDrag)
        }
    }
}
