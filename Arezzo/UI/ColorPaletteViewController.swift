//
//  ColorPaletteViewController.swift
//  Arezzo
//
//  Created by Max Harris on 3/27/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import UIKit

class ColorPaletteViewController: UIViewController {
    var pencilButton: UIButton = UIButton(type: .custom)
    var lassoButton: UIButton = UIButton(type: .custom)
    var delegate: ToolbarDelegate?
    var colorWell: UIColorWell = UIColorWell(frame: CGRect(x: 0, y: 0, width: 44, height: 44))

    override func loadView() {
        self.view = UIStackView()
    }

    override func viewDidLoad() {
        let stackView = self.view as! UIStackView
        stackView.alignment = .fill
        stackView.axis = .horizontal

        self.colorWell.addTarget(self, action: #selector(self.colorWellChanged(_:)), for: .valueChanged)
        stackView.addArrangedSubview(self.colorWell)
    }

    @objc func colorWellChanged(_: Any) {
        self.view.backgroundColor = self.colorWell.selectedColor
    }
}
