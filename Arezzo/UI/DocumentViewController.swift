//
//  DocumentViewController.swift
//  Arezzo
//
//  Created by Max Harris on 3/30/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import UIKit
import UniformTypeIdentifiers

class DocumentViewController: UIViewController, UIDocumentPickerDelegate {
    var importButton: UIButton = UIButton(type: .custom)
    var saveButton: UIButton = UIButton(type: .custom)
    var restoreButton: UIButton = UIButton(type: .custom)
    var startExportButton: UIButton = UIButton(type: .custom)
    var saveIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
    var restoreProgressIndicator: UIProgressView = UIProgressView()
    var exportProgressIndicator: UIProgressView = UIProgressView()
    var documentNameLabel: UITextField = UITextField()

    var delegate: ToolbarDelegate?

    override func loadView() {
        self.view = UIStackView()
    }

    override func viewDidLoad() {
        let stackView = self.view as! UIStackView
        stackView.alignment = .fill
        stackView.axis = .horizontal

        configureButton(self.importButton, UIImage(systemName: "plus.square.on.square")!)
        self.importButton.addTarget(self, action: #selector(self.startImport), for: .touchUpInside)
        stackView.addArrangedSubview(self.importButton)

        configureButton(self.saveButton, UIImage(systemName: "square.and.arrow.down")!)
        self.saveButton.addTarget(self, action: #selector(self.save), for: .touchUpInside)
        stackView.addArrangedSubview(self.saveButton)

        self.saveIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.saveIndicator.clipsToBounds = true
        view.addSubview(self.saveIndicator)

        configureButton(self.restoreButton, UIImage(systemName: "square.and.arrow.up")!)
        self.restoreButton.addTarget(self, action: #selector(self.restore), for: .touchUpInside)
        stackView.addArrangedSubview(self.restoreButton)

        self.restoreProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.restoreProgressIndicator.isHidden = true
        view.addSubview(self.restoreProgressIndicator)

        configureButton(self.startExportButton, UIImage(systemName: "film")!)
        self.startExportButton.addTarget(self, action: #selector(self.startExport), for: .touchUpInside)
        stackView.addArrangedSubview(self.startExportButton)

        self.exportProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.exportProgressIndicator.isHidden = true
        view.addSubview(self.exportProgressIndicator)

        self.documentNameLabel.text = "Untitled"
        stackView.addArrangedSubview(self.documentNameLabel)
    }

    @objc func save() {
        self.delegate?.save(filename: self.documentNameLabel.text!)
    }

    @objc func restore() {
        self.delegate?.restore(filename: self.documentNameLabel.text!)
    }

    @objc func startExport() {
        self.delegate?.startExport(filename: self.documentNameLabel.text!)
    }

    @objc func startImport() {
        let supportedTypes: [UTType] = [UTType.image]
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: false)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .automatic
        present(documentPicker, animated: false, completion: nil)
    }
}

/*
        NSLayoutConstraint.activate([
            thicknessSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            thicknessSlider.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            thicknessSlider.widthAnchor.constraint(equalToConstant: 80.0),

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
