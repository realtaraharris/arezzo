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

    override func loadView() {
        self.view = UIStackView()
    }

    override func viewDidLoad() {
        let stackView = self.view as! UIStackView
        stackView.alignment = .fill
        stackView.axis = .horizontal

        configureButton(self.pencilButton, UIImage(systemName: "pencil")!)
        self.pencilButton.addTarget(self, action: #selector(self.togglePencil), for: .touchUpInside)
        stackView.addArrangedSubview(self.pencilButton)

        configureButton(self.lassoButton, UIImage(systemName: "lasso")!)
        self.lassoButton.addTarget(self, action: #selector(self.toggleLasso), for: .touchUpInside)
        stackView.addArrangedSubview(self.lassoButton)
    }

    @objc func togglePencil() {
        print("toggling pencil")
    }

    @objc func toggleLasso() {
        print("toggling lasso")
    }
}
