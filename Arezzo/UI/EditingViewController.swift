//
//  EditingViewController.swift
//  Arezzo
//
//  Created by Max Harris on 3/24/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import UIKit

class EditingViewController: UIViewController {
    var pencilButton: UIButton = UIButton(type: .custom)
    var lassoButton: UIButton = UIButton(type: .custom)
    var delegate: ToolbarDelegate?

    override func viewDidLoad() {
        configureButton(self.pencilButton, UIImage(systemName: "pencil")!)
        self.pencilButton.addTarget(self, action: #selector(self.togglePencil), for: .touchUpInside)
        view.addSubview(self.pencilButton)

        configureButton(self.lassoButton, UIImage(systemName: "lasso")!)
        self.lassoButton.addTarget(self, action: #selector(self.toggleLasso), for: .touchUpInside)
        view.addSubview(self.lassoButton)

        NSLayoutConstraint.activate([
            self.pencilButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            self.pencilButton.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            self.pencilButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            self.pencilButton.heightAnchor.constraint(equalToConstant: buttonHeight),

            self.lassoButton.leadingAnchor.constraint(equalTo: self.pencilButton.trailingAnchor, constant: margin),
            self.lassoButton.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            self.lassoButton.widthAnchor.constraint(equalToConstant: buttonWidth),
            self.lassoButton.heightAnchor.constraint(equalToConstant: buttonHeight),
        ])
    }

    @objc func togglePencil() {
        print("toggling pencil")
    }

    @objc func toggleLasso() {
        print("toggling lasso")
    }
}
