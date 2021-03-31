//
//  DocumentViewController.swift
//  Arezzo
//
//  Created by Max Harris on 3/30/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import UIKit

class DocumentViewController: UIViewController {
    var saveButton: UIButton = UIButton(type: .custom)
    var restoreButton: UIButton = UIButton(type: .custom)
    var startExportButton: UIButton = UIButton(type: .custom)
    var saveIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
    var restoreProgressIndicator: UIProgressView = UIProgressView()
    var exportProgressIndicator: UIProgressView = UIProgressView()

    var delegate: ToolbarDelegate?

    override func loadView() {
        self.view = UIStackView()
    }

    override func viewDidLoad() {
        let stackView = self.view as! UIStackView
        stackView.alignment = .fill
        stackView.axis = .horizontal

        configureButton(self.saveButton, UIImage(systemName: "square.and.arrow.down")!)
        self.saveButton.addTarget(self, action: #selector(self.save), for: .touchUpInside)
        stackView.addArrangedSubview(self.saveButton)

        saveIndicator.translatesAutoresizingMaskIntoConstraints = false
        saveIndicator.clipsToBounds = true
        view.addSubview(saveIndicator)

        configureButton(self.restoreButton, UIImage(systemName: "square.and.arrow.up")!)
        self.restoreButton.addTarget(self, action: #selector(self.restore), for: .touchUpInside)
        stackView.addArrangedSubview(self.restoreButton)

        restoreProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        restoreProgressIndicator.isHidden = true
        view.addSubview(restoreProgressIndicator)

        configureButton(self.startExportButton, UIImage(systemName: "film")!)
        self.startExportButton.addTarget(self, action: #selector(self.export), for: .touchUpInside)
        stackView.addArrangedSubview(self.startExportButton)

        exportProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        exportProgressIndicator.isHidden = true
        view.addSubview(exportProgressIndicator)
    }

    @objc func save() {
        delegate?.save()
    }

    @objc func restore() {
        delegate?.restore()
    }

    @objc func export() {
        delegate?.startExport()
    }
}
