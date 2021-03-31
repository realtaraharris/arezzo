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

let margin: CGFloat = 20.0
let buttonHeight: CGFloat = 44.0
let buttonWidth: CGFloat = 44.0

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
//    var delegate: ToolbarDelegate?
    var recording: Bool = false
    var playing: Bool = false
    var modeSelector: UISegmentedControl = UISegmentedControl(items: [
        UIImage(systemName: "square.and.pencil") as Any, // Mac: !.imageWithTopInset(1.0)
        UIImage(systemName: "slider.horizontal.3")! as Any, // Mac: !.imageWithTopInset(3.0)
        UIImage(systemName: "play.circle")! as Any, // Mac: !.imageWithTopInset(3.0)
    ])

    private var stackView = UIStackView()

    let documentVC = DocumentViewController()
    let recordingVC = RecordingViewController()
    let editingVC = EditingViewController()
    let playbackVC = PlaybackViewController()
    let colorPaletteVC = ColorPaletteViewController()

    var clearButton: UIButton?

    override func loadView() {
        view = ToolbarView()
    }

    override func viewDidLoad() {
        self.modeSelector.selectedSegmentIndex = 0
        self.modeSelector.addTarget(self, action: #selector(self.segmentControl(_:)), for: .valueChanged)

        // create a vertical stackView to pad out the mode selector
        let paddingStackView = UIStackView()
        paddingStackView.axis = .vertical
        paddingStackView.addArrangedSubview(UIView())
        paddingStackView.addArrangedSubview(self.modeSelector)
        paddingStackView.addArrangedSubview(UIView())
        paddingStackView.distribution = UIStackView.Distribution.equalCentering

        self.stackView.axis = .horizontal
        self.stackView.distribution = .fill
        self.stackView.addArrangedSubview(paddingStackView)
        self.stackView.spacing = 10.0

        self.addArrangedChild(self.documentVC)
        self.addArrangedChild(self.recordingVC)
        self.addArrangedChild(self.colorPaletteVC)
        self.stackView.distribution = .fill

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
        let toolbarWidth: CGFloat = 800
        let toolbarHeight: CGFloat = 120

        view.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.75)
        view.isUserInteractionEnabled = true
        view.frame = CGRect(x: 12, y: 40, width: toolbarWidth, height: toolbarHeight)
        view.layer.cornerRadius = 5.0
        view.layer.masksToBounds = true

        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self.stackView)

        NSLayoutConstraint.activate([
            self.stackView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 10.0),
            self.stackView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10.0),
        ])

        /*
                NSLayoutConstraint.activate([
                    thicknessSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
                    thicknessSlider.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
                    thicknessSlider.widthAnchor.constraint(equalToConstant: 80.0),

                    colorSampleView!.leadingAnchor.constraint(equalTo: drawModeButton!.trailingAnchor, constant: margin),
                    colorSampleView!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
                    colorSampleView!.widthAnchor.constraint(equalToConstant: 33.0),
                    colorSampleView!.heightAnchor.constraint(equalToConstant: 20.0),

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

                    startExportButton!.leadingAnchor.constraint(equalTo: clearButton!.trailingAnchor, constant: margin),
                    startExportButton!.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
                    startExportButton!.widthAnchor.constraint(equalToConstant: 100.0),

                    exportProgressIndicator!.leadingAnchor.constraint(equalTo: clearButton!.trailingAnchor, constant: margin),
                    exportProgressIndicator!.topAnchor.constraint(equalTo: startExportButton!.bottomAnchor, constant: 5),
                    exportProgressIndicator!.widthAnchor.constraint(equalToConstant: 100.0),
                ])
         */
    }

    @objc func segmentControl(_ segmentedControl: UISegmentedControl) {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            self.removeAllArrangedChildren()
            self.addArrangedChild(self.documentVC)
            self.addArrangedChild(self.recordingVC)
            self.addArrangedChild(self.colorPaletteVC)
        case 1:
            self.removeAllArrangedChildren()
            self.addArrangedChild(self.documentVC)
            self.addArrangedChild(self.editingVC)
            self.addArrangedChild(self.colorPaletteVC)
        case 2:
            self.removeAllArrangedChildren()
            self.addArrangedChild(self.documentVC)
            self.addArrangedChild(self.playbackVC)
        default:
            break
        }
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
