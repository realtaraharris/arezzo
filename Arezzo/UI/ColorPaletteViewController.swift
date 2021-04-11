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
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: colors as Any, requiringSecureCoding: false)
            set(data, forKey: key)
        } catch {
            print("unexpected error", error)
        }
    }
}

class ColorPatch: UIButton {
    var colorWell: UIColorWell = UIColorWell()

    required init(_ color: UIColor, active: Bool) {
        super.init(frame: .zero)

        self.backgroundColor = color
        self.colorWell.frame = CGRect(x: 36, y: 0, width: 36, height: 36)
        self.colorWell.addTarget(self, action: #selector(self.colorWellChanged(colorWell:)), for: .valueChanged)
        self.addSubview(self.colorWell)

        if active {
            self.layer.borderWidth = 2
            self.layer.borderColor = UIColor.black.cgColor
        }
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
    var activeColorIndex = 0

    override func loadView() {
        self.view = UIStackView()

        let colors = UserDefaults.standard.colorsForKey(key: "SelectedColors")
        let activeColorIndex = UserDefaults.standard.integer(forKey: "SelectedColorIndex")

        guard colors != nil, colors!.count > 0 else { return }
        self.activeColorIndex = activeColorIndex
        self.delegate?.setColor(color: colors![activeColorIndex])
        self.colorWells = colors!.enumerated().map { index, element in ColorPatch(element, active: index == activeColorIndex) }
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

        for (index, colorWell) in self.colorWells.enumerated() {
            if index == self.activeColorIndex {
                colorWell.layer.borderWidth = 2
                colorWell.layer.borderColor = UIColor.black.cgColor
            } else {
                colorWell.layer.borderWidth = 0
                colorWell.layer.borderColor = UIColor.clear.cgColor
            }
            colorWell.addTarget(self, action: #selector(self.colorWellChanged(colorWell:)), for: .touchUpInside)
            colorWell.tag = index
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
        let index = colorWell.tag
        self.activeColorIndex = index
        self.saveColorWells()
        self.delegate?.setColor(color: self.colorWells[index].backgroundColor!)
        self.clear()
        self.render()
    }

    @objc func addColorWell() {
        self.clear()
        self.colorWells.append(ColorPatch(UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), active: true))
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
        UserDefaults.standard.set(self.activeColorIndex, forKey: "SelectedColorIndex")
        UserDefaults.standard.setColors(colors, forKey: "SelectedColors")
    }
}
