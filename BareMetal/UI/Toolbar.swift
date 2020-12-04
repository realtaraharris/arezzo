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

    func setLineWidth(_ lineWidth: Float)
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

        let slider = UISlider()
        slider.minimumValue = 5.0
        slider.maximumValue = 50.0
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.transform = CGAffineTransform(rotationAngle: CGFloat(Float.pi / -2))
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        view.addSubview(slider)

        view.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)
        view.isUserInteractionEnabled = true
        view.frame = CGRect(x: 500, y: 100, width: 500, height: 100)

        NSLayoutConstraint.activate([
            slider.widthAnchor.constraint(equalTo: view.heightAnchor),
            slider.centerYAnchor.constraint(equalTo: view.layoutMarginsGuide.centerYAnchor),

            playButton!.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: -20),
            playButton!.centerYAnchor.constraint(equalTo: view.layoutMarginsGuide.centerYAnchor),
            playButton!.widthAnchor.constraint(equalToConstant: 130.0),

            drawModeButton!.leadingAnchor.constraint(equalTo: playButton!.trailingAnchor, constant: 20),
            drawModeButton!.centerYAnchor.constraint(equalTo: view.layoutMarginsGuide.centerYAnchor),
            drawModeButton!.widthAnchor.constraint(equalToConstant: 80.0),

            recordButton!.leadingAnchor.constraint(equalTo: drawModeButton!.trailingAnchor, constant: 20),
            recordButton!.centerYAnchor.constraint(equalTo: view.layoutMarginsGuide.centerYAnchor),
            recordButton!.widthAnchor.constraint(equalToConstant: 150.0),
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

    @objc func sliderChanged(_ sender: UISlider!) {
        delegate?.setLineWidth(sender.value)
        print("slider changed: \(sender.value)")
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