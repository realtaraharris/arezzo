//
//  ColorPaletteViewController.swift
//  Arezzo
//
//  Created by Max Harris on 3/27/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation
import UIKit

extension UserDefaults {
    func colorsForKey(key: String) -> [UIColor]? {
        var colors: [UIColor]?
        if let colorData = data(forKey: key) {
            colors = NSKeyedUnarchiver.unarchiveObject(with: colorData) as? [UIColor]
        }
        return colors
    }

    func setColors(_ colors: [UIColor]?, forKey key: String) {
        var colorData: NSData?
        if let colors = colors {
            colorData = NSKeyedArchiver.archivedData(withRootObject: colors) as NSData?
        }
        set(colorData, forKey: key)
    }
}

class ColorPatch: UIButton {
    var colorWell: UIColorWell = UIColorWell()

    required init(_ color: UIColor) {
        super.init(frame: .zero)

        self.backgroundColor = color
        self.colorWell.frame = CGRect(x: 36, y: 0, width: 36, height: 36)
        self.colorWell.addTarget(self, action: #selector(self.colorWellChanged(colorWell:)), for: .valueChanged)
        self.addSubview(self.colorWell)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 72, height: 36)
    }

    @objc func colorWellChanged(colorWell: UIColorWell) {
        self.backgroundColor = colorWell.selectedColor
    }
}

class ColorPaletteViewController: UIViewController {
    var addButton: UIButton = UIButton(type: .custom)
    var removeButton: UIButton = UIButton(type: .custom)
    var delegate: ToolbarDelegate?
    var colorWells: [ColorPatch] = []
    let MIN_COLORWELLS = 1

    override func loadView() {
        self.view = UIStackView()

        let colors = UserDefaults.standard.colorsForKey(key: "ToolbarColors")
        guard colors != nil, colors!.count > 0 else { return }
        self.colorWells = colors!.map { ColorPatch($0) }
    }

    func clear() {
        let stackView = self.view as! UIStackView
        for view in stackView.subviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    func render() {
        let stackView = self.view as! UIStackView
        stackView.alignment = .fill
        stackView.axis = .horizontal

        for colorWell in self.colorWells {
            colorWell.addTarget(self, action: #selector(self.colorWellChanged(colorWell:)), for: .touchUpInside)
            stackView.addArrangedSubview(colorWell)
        }

        configureButton(self.addButton, UIImage(systemName: "plus.circle")!)
        self.addButton.addTarget(self, action: #selector(self.addColorWell), for: .touchUpInside)
        stackView.addArrangedSubview(self.addButton)

        if self.colorWells.count > self.MIN_COLORWELLS {
            configureButton(self.removeButton, UIImage(systemName: "minus.circle")!)
            self.removeButton.addTarget(self, action: #selector(self.removeColorWell), for: .touchUpInside)
            stackView.addArrangedSubview(self.removeButton)
        }
    }

    override func viewDidLoad() {
        self.render()
    }

    @objc func colorWellChanged(colorWell: ColorPatch) {
        self.delegate?.setColor(color: colorWell.backgroundColor!)
        self.saveColorWells()
    }

    @objc func addColorWell() {
        self.clear()
        self.colorWells.append(ColorPatch(UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)))
        self.render()
        self.saveColorWells()
    }

    @objc func removeColorWell() {
        guard self.colorWells.count > self.MIN_COLORWELLS else { return }
        self.clear()
        self.colorWells.removeLast()
        self.render()
        self.saveColorWells()
    }

    func saveColorWells() {
        let colors = self.colorWells.map { $0.backgroundColor! }
        UserDefaults.standard.setColors(colors, forKey: "ToolbarColors")
    }
}
