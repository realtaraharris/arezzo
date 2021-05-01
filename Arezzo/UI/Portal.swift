//
//  Portal.swift
//  Arezzo
//
//  Created by Max Harris on 4/29/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import UIKit

class PortalView: UIControl {
    override func touchesBegan(_: Set<UITouch>, with event: UIEvent?) {
        // cancel the touches here or the view below will get drawn on
        self.cancelTracking(with: event)
    }

    override func touchesMoved(_: Set<UITouch>, with event: UIEvent?) {
        // cancel the touches here or the view below will get drawn on
        self.cancelTracking(with: event)
    }

    override func touchesEnded(_: Set<UITouch>, with event: UIEvent?) {
        // cancel the touches here or the view below will get drawn on
        self.cancelTracking(with: event)
    }

    override func touchesCancelled(_: Set<UITouch>, with event: UIEvent?) {
        // cancel the touches here or the view below will get drawn on
        self.cancelTracking(with: event)
    }
}

class PortalViewController: UIViewController {
    var playButton: UIButton = UIButton(type: .custom)
    var recordButton: UIButton = UIButton(type: .custom)

    var delegate: ToolbarDelegate?

    override func loadView() {
        self.view = PortalView()
        self.view.backgroundColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.4)
        let stackView = UIStackView()
        stackView.backgroundColor = .darkGray
        stackView.alignment = .top
        stackView.distribution = .equalSpacing
        stackView.axis = .horizontal

        configureButton(self.playButton, UIImage(systemName: "play.circle")!)
        self.playButton.tintColor = .white
        self.playButton.translatesAutoresizingMaskIntoConstraints = false
        self.playButton.clipsToBounds = true
        self.playButton.isEnabled = false
        stackView.addArrangedSubview(self.playButton)

        configureButton(self.recordButton, UIImage(systemName: "pencil")!)
        self.recordButton.tintColor = .white
        self.recordButton.translatesAutoresizingMaskIntoConstraints = false
        self.recordButton.clipsToBounds = true
        stackView.addArrangedSubview(self.recordButton)

        self.playButton.addTarget(self, action: #selector(self.play), for: .touchUpInside)
        self.recordButton.addTarget(self, action: #selector(self.record), for: .touchUpInside)

        self.view.addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
        ])
    }

    @objc func play() {
        print("play")
    }

    @objc func record() {
        self.delegate?.switchPortals()
    }
}
