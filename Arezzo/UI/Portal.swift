//
//  Portal.swift
//  Arezzo
//
//  Created by Max Harris on 4/29/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import UIKit

class PortalViewController: UIViewController {
    var playButton: UIButton = UIButton(type: .custom)
    var recordButton: UIButton = UIButton(type: .custom)

    override func loadView() {
        let stackView = UIStackView(frame: CGRect(x: 0, y: 0, width: 88.0, height: 44.0))
        stackView.backgroundColor = .darkGray
        stackView.alignment = .top
        stackView.distribution = .equalSpacing
        stackView.axis = .horizontal

        configureButton(self.playButton, UIImage(systemName: "play.circle")!)
        self.playButton.tintColor = .white
        self.playButton.translatesAutoresizingMaskIntoConstraints = false
        self.playButton.clipsToBounds = true
        stackView.addArrangedSubview(self.playButton)

        configureButton(self.recordButton, UIImage(systemName: "record.circle")!)
        self.recordButton.tintColor = .white
        self.recordButton.translatesAutoresizingMaskIntoConstraints = false
        self.recordButton.clipsToBounds = true
        stackView.addArrangedSubview(self.recordButton)

        self.playButton.addTarget(self, action: #selector(self.play), for: .touchUpInside)
        self.recordButton.addTarget(self, action: #selector(self.record), for: .touchUpInside)

        self.view = stackView
    }

    @objc func play() {
        print("play")
    }

    @objc func record() {
        print("record")
    }
}
