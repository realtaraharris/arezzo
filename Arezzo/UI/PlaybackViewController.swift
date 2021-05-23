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

    override func loadView() {
        self.view = UIStackView()
    }

    override func viewDidLoad() {
        let stackView = self.view as! UIStackView
        stackView.alignment = .top
        stackView.axis = .vertical

        let buttonStack = UIStackView()
        buttonStack.alignment = .fill
        buttonStack.axis = .horizontal

        configureButton(self.playbackButton, UIImage(systemName: "play.fill")!)
        self.playbackButton.addTarget(self, action: #selector(self.togglePlayback), for: .touchUpInside)
        buttonStack.addArrangedSubview(self.playbackButton)

        configureButton(self.fastForwardButton, UIImage(systemName: "forward.fill")!)
        self.fastForwardButton.addTarget(self, action: #selector(self.toggleFastForward), for: .touchUpInside)
        buttonStack.addArrangedSubview(self.fastForwardButton)

        stackView.addArrangedSubview(buttonStack)

        self.playbackSlider.minimumValue = 0.0
        self.playbackSlider.maximumValue = 1.0
        self.playbackSlider.translatesAutoresizingMaskIntoConstraints = false
        self.playbackSlider.widthAnchor.constraint(equalToConstant: 444.0).isActive = true
        self.playbackSlider.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
        self.playbackSlider.addTarget(self, action: #selector(self.playbackSliderChanged), for: .valueChanged)
        stackView.addArrangedSubview(self.playbackSlider)
    }

    @objc func togglePlayback() {
        print("togglePlayback()")
        if !self.playing {
            self.playbackButton.setBackgroundImage(UIImage(systemName: "pause.fill"), for: .normal)
            self.delegate?.startPlaying()
        } else {
            self.playbackButton.setBackgroundImage(UIImage(systemName: "play.fill"), for: .normal)
            self.delegate?.stopPlaying()
        }

        self.playing = !self.playing
    }

    @objc func toggleFastForward() {}

    @objc func playbackSliderChanged(_ sender: UISlider!) {
        self.readyToPlay()
        self.delegate?.setPlaybackPosition(sender.value)
    }

    @objc func readyToPlay() {
        self.playbackButton.setBackgroundImage(UIImage(systemName: "play.fill"), for: .normal)
        self.playing = false
    }
}
