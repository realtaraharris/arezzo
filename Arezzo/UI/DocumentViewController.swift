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
    var exportButton: UIButton = UIButton(type: .custom)
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
        stackView.alignment = .top
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

        configureButton(self.exportButton, UIImage(systemName: "film")!)
        self.exportButton.addTarget(self, action: #selector(self.startExport), for: .touchUpInside)
        stackView.addArrangedSubview(self.exportButton)

        self.exportProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.exportProgressIndicator.isHidden = true
        view.addSubview(self.exportProgressIndicator)

        self.documentNameLabel.text = "Untitled"
        stackView.addArrangedSubview(self.documentNameLabel)

        let centerOffset: CGFloat = 30.0
        NSLayoutConstraint.activate([
            self.saveIndicator.centerYAnchor.constraint(equalTo: self.saveButton.centerYAnchor, constant: centerOffset),
            self.saveIndicator.centerXAnchor.constraint(equalTo: self.saveButton.centerXAnchor),

            self.restoreProgressIndicator.widthAnchor.constraint(equalTo: self.restoreButton.widthAnchor),
            self.restoreProgressIndicator.centerYAnchor.constraint(equalTo: self.restoreButton.centerYAnchor, constant: centerOffset),
            self.restoreProgressIndicator.centerXAnchor.constraint(equalTo: self.restoreButton.centerXAnchor),

            self.exportProgressIndicator.widthAnchor.constraint(equalTo: self.exportButton.widthAnchor),
            self.exportProgressIndicator.centerYAnchor.constraint(equalTo: self.exportButton.centerYAnchor, constant: centerOffset),
            self.exportProgressIndicator.centerXAnchor.constraint(equalTo: self.exportButton.centerXAnchor),
        ])
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
