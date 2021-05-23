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
    var saveButton: UIButton = UIButton(type: .custom)
    var restoreButton: UIButton = UIButton(type: .custom)
    var restoreFilePicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "json")!], asCopy: false)
    var exportButton: UIButton = UIButton(type: .custom)
    var saveIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
    var restoreProgressIndicator: UIProgressView = UIProgressView()
    var exportProgressIndicator: UIProgressView = UIProgressView()
    var documentNameLabel: UILabel = UILabel()

    var delegate: ToolbarDelegate?

    override func loadView() {
        self.view = UIStackView()
    }

    override func viewDidLoad() {
        let stackView = self.view as! UIStackView
        stackView.alignment = .top
        stackView.axis = .horizontal

        configureButton(self.saveButton, UIImage(systemName: "square.and.arrow.down")!)
        self.saveButton.addTarget(self, action: #selector(self.save), for: .touchUpInside)
        stackView.addArrangedSubview(self.saveButton)

        self.saveIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.saveIndicator.clipsToBounds = true
        view.addSubview(self.saveIndicator)

        configureButton(self.restoreButton, UIImage(systemName: "square.and.arrow.up")!)
        self.restoreButton.addTarget(self, action: #selector(self.restore), for: .touchUpInside)
        stackView.addArrangedSubview(self.restoreButton)

        self.restoreFilePicker.allowsMultipleSelection = false
        self.restoreFilePicker.modalPresentationStyle = .automatic
        self.restoreFilePicker.delegate = self

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

        let padding: UIView = UIView()
        configurePadding(padding)
        stackView.addArrangedSubview(padding)

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
        guard self.documentNameLabel.text == "Untitled" else {
            self.delegate?.save(filename: self.documentNameLabel.text!)
            return
        }

        let alert = UIAlertController(title: "Name Required", message: "Enter a filename for this workbook.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = self.documentNameLabel.text
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] _ in
            let newName = (alert?.textFields![0].text)!
            self.documentNameLabel.text = newName
            self.delegate?.save(filename: newName)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: false, completion: nil)
    }

    @objc func restore() {
        self.view.window!.rootViewController!.present(self.restoreFilePicker, animated: false, completion: nil)
    }

    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt: [URL]) {
        guard didPickDocumentsAt.count > 0 else { return }
        let pickedFile: String = didPickDocumentsAt[0].deletingPathExtension().lastPathComponent
        self.documentNameLabel.text = pickedFile
        self.delegate?.restore(filename: pickedFile)
    }

    @objc func startExport() {
        self.delegate?.startExport(filename: self.documentNameLabel.text!)
    }
}
