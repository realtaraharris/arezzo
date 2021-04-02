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
        self.startExportButton.addTarget(self, action: #selector(self.export), for: .touchUpInside)
        stackView.addArrangedSubview(self.startExportButton)

        self.exportProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.exportProgressIndicator.isHidden = true
        view.addSubview(self.exportProgressIndicator)
    }

    @objc func save() {
        self.delegate?.save()
    }

    @objc func restore() {
        self.delegate?.restore()
    }

    @objc func export() {
        self.delegate?.startExport()
    }
}
