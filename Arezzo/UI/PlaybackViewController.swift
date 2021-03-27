//
//  PlaybackViewController.swift
//  Arezzo
//
//  Created by Max Harris on 3/23/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import UIKit

class PlaybackViewController: UIViewController {
    var playbackButton: UIButton = UIButton(type: .custom)
    var fastForwardButton: UIButton = UIButton(type: .custom)

    var delegate: ToolbarDelegate?
    var playing: Bool = false
    var playbackSlider: UISlider = UISlider()

    override func viewDidLoad() {
        configureButton(self.playbackButton, UIImage(systemName: "play.fill")!)
        self.playbackButton.addTarget(self, action: #selector(self.togglePlayback), for: .touchUpInside)
        view.addSubview(self.playbackButton)

        configureButton(self.fastForwardButton, UIImage(systemName: "forward.fill")!)
        self.fastForwardButton.addTarget(self, action: #selector(self.toggleFastForward), for: .touchUpInside)
        view.addSubview(self.fastForwardButton)

        self.playbackSlider.minimumValue = 0.0
        self.playbackSlider.maximumValue = 1.0
        self.playbackSlider.translatesAutoresizingMaskIntoConstraints = false
        self.playbackSlider.addTarget(self, action: #selector(self.playbackSliderChanged), for: .valueChanged)
        view.addSubview(self.playbackSlider)

        NSLayoutConstraint.activate([
            self.playbackButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            self.playbackButton.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            self.playbackButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            self.playbackButton.heightAnchor.constraint(equalToConstant: buttonHeight),

            self.fastForwardButton.leadingAnchor.constraint(equalTo: self.playbackButton.trailingAnchor, constant: margin),
            self.fastForwardButton.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            self.fastForwardButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            self.fastForwardButton.heightAnchor.constraint(equalToConstant: buttonHeight),

            self.playbackSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            self.playbackSlider.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin),
            self.playbackSlider.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -(margin * 2)),
        ])
    }

    @objc func togglePlayback() {
        print("togglePlayback()")
        if !self.playing {
            self.delegate?.startPlaying()
        } else {
            self.delegate?.stopPlaying()
        }

//        playButton!.setTitle("\(playing ? "Start" : "Stop") Playing", for: .normal)
        self.playing = !self.playing
    }

    @objc func toggleFastForward() {}

    @objc func playbackSliderChanged(_ sender: UISlider!) {
        self.delegate?.setPlaybackPosition(sender.value)
    }
}
