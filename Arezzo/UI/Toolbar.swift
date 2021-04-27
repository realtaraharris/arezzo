//
//  Toolbar.swift
//  Arezzo
//
//  Created by Max Harris on 9/1/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation
import UIKit

func configureButton(_ button: UIButton, _ icon: UIImage) {
    button.translatesAutoresizingMaskIntoConstraints = false
    button.widthAnchor.constraint(equalToConstant: 44.0).isActive = true
    button.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
    button.layer.cornerRadius = 0.0
    button.clipsToBounds = true
    button.tintColor = .black
    button.setBackgroundImage(icon, for: .normal)
}

protocol ToolbarDelegate {
    func startRecording()
    func stopRecording()

    func startPlaying()
    func stopPlaying()

    func setPenDownMode(mode: PenDownMode)
    func setColor(color: UIColor)

    func save(filename: String)
    func restore(filename: String)
    func clear()

    func startExport(filename: String)

    func setLineWidth(_ lineWidth: Float)
    func setPlaybackPosition(_ playbackPosition: Float)
    func getPlaybackTimestamp() -> Double

    func switchPortals()
}

class ToolbarView: UIControl {
    var toolbarPositionSaved: Bool = true

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let p1 = touch.location(in: self.superview)
            let p0 = touch.previousLocation(in: self.superview)
            let translation = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            self.toolbarPositionSaved = false

            // cancel the touches here or the view below will get drawn on
            self.cancelTracking(with: event)
        }
    }

    override func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
        guard !self.toolbarPositionSaved else { return }
        UserDefaults.standard.set(self.center.x, forKey: "ToolbarPositionX")
        UserDefaults.standard.set(self.center.y, forKey: "ToolbarPositionY")
        self.toolbarPositionSaved = true
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

extension Toolbar {
    func removeAllArrangedChildren() {
        for child in self.children {
            self.removeArrangedChild(child)
        }
    }

    func addArrangedChild(_ child: UIViewController) {
        addChild(child)
        self.stackView.addArrangedSubview(child.view)
        child.didMove(toParent: self)
    }

    func removeArrangedChild(_ child: UIViewController) {
        guard child.parent != nil else {
            return
        }

        child.willMove(toParent: nil)
        self.stackView.removeArrangedSubview(child.view)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }
}

@available(iOS 14.0, *)
@available(macCatalyst 14.0, *)
class Toolbar: UIViewController {
    var recording: Bool = false
    var playing: Bool = false

    var recordingModeButton: UIButton = UIButton(type: .custom)
    var editingModeButton: UIButton = UIButton(type: .custom)
    var playbackModeButton: UIButton = UIButton(type: .custom)

    private var stackView = UIStackView()

    let documentVC = DocumentViewController()
    let recordingVC = RecordingViewController()
    let editingVC = EditingViewController()
    let playbackVC = PlaybackViewController()
    let colorPaletteVC = ColorPaletteViewController()

    override func loadView() {
        view = ToolbarView()
    }

    override func viewDidLoad() {
        configureButton(self.recordingModeButton, UIImage(systemName: "square.and.pencil")!)
        self.recordingModeButton.addTarget(self, action: #selector(self.enterRecordingMode), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.recordingModeButton)

        configureButton(self.editingModeButton, UIImage(systemName: "slider.horizontal.3")!)
        self.editingModeButton.addTarget(self, action: #selector(self.enterEditingMode), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.editingModeButton)

        configureButton(self.playbackModeButton, UIImage(systemName: "play.circle")!)
        self.playbackModeButton.addTarget(self, action: #selector(self.enterPlaybackMode), for: .touchUpInside)
        self.stackView.addArrangedSubview(self.playbackModeButton)

        self.stackView.axis = .horizontal
        self.stackView.alignment = .top
        self.stackView.distribution = .fill

        view.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
        view.isUserInteractionEnabled = true
        view.frame = CGRect(x: 16, y: 44, width: 1000, height: 120)

        let toolbarX = UserDefaults.standard.float(forKey: "ToolbarPositionX")
        let toolbarY = UserDefaults.standard.float(forKey: "ToolbarPositionY")
        if toolbarX != 0.0, toolbarY != 0.0 {
            self.view.center.x = CGFloat(toolbarX)
            self.view.center.y = CGFloat(toolbarY)
        }
        view.layer.cornerRadius = 5.0
        view.layer.masksToBounds = true

        self.enterRecordingMode()
        view.addSubview(self.stackView)

        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.stackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 10.0),
            self.stackView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10.0),
        ])
    }

    @objc func enterRecordingMode() {
        self.recordingModeButton.tintColor = self.view.tintColor
        self.editingModeButton.tintColor = .black
        self.playbackModeButton.tintColor = .black

        self.removeAllArrangedChildren()
        self.addArrangedChild(self.documentVC)
        self.addArrangedChild(self.recordingVC)
        self.addArrangedChild(self.colorPaletteVC)
    }

    @objc func enterEditingMode() {
        self.recordingModeButton.tintColor = .black
        self.editingModeButton.tintColor = self.view.tintColor
        self.playbackModeButton.tintColor = .black

        self.removeAllArrangedChildren()
        self.addArrangedChild(self.documentVC)
        self.addArrangedChild(self.editingVC)
        self.addArrangedChild(self.colorPaletteVC)
    }

    @objc func enterPlaybackMode() {
        self.recordingModeButton.tintColor = .black
        self.editingModeButton.tintColor = .black
        self.playbackModeButton.tintColor = self.view.tintColor

        self.removeAllArrangedChildren()
        self.addArrangedChild(self.documentVC)
        self.addArrangedChild(self.playbackVC)
    }
}
