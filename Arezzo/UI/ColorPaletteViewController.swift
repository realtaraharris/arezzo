//
//  ColorPaletteViewController.swift
//  Arezzo
//
//  Created by Max Harris on 3/27/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import UIKit

class ColorPatch: UIButton {
    var colorWell: UIColorWell = UIColorWell()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 72, height: 36)
    }

    override required init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        self.colorWell.frame = CGRect(x: 36, y: 0, width: 36, height: 36)
        self.colorWell.addTarget(self, action: #selector(self.colorWellChanged(colorWell:)), for: .valueChanged)
        self.addSubview(self.colorWell)
    }

    @objc func colorWellChanged(colorWell: UIColorWell) {
        self.backgroundColor = colorWell.selectedColor
    }
}

class ColorPaletteViewController: UIViewController {
    var pencilButton: UIButton = UIButton(type: .custom)
    var lassoButton: UIButton = UIButton(type: .custom)
    var delegate: ToolbarDelegate?
    var colorWells: [ColorPatch] = [ColorPatch(), ColorPatch(), ColorPatch(), ColorPatch()]

    override func loadView() {
        self.view = UIStackView()
    }

    override func viewDidLoad() {
        let stackView = self.view as! UIStackView
        stackView.alignment = .fill
        stackView.axis = .horizontal

        for colorWell in self.colorWells {
            colorWell.addTarget(self, action: #selector(self.colorWellChanged(colorWell:)), for: .touchUpInside)
            stackView.addArrangedSubview(colorWell)
        }
    }

    @objc func colorWellChanged(colorWell: ColorPatch) {
        self.delegate?.setColor(color: colorWell.backgroundColor!)
    }
}
