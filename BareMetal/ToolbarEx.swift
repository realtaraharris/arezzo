//
//  Toolbar.swift
//  BareMetal
//
//  Created by Max Harris on 9/1/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation
import UIKit

class ToolbarEx: UIViewController {
    override func viewDidLoad () {
        let recordButton = UIButton(type: .system)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        // recordButton.backgroundColor = UIColor.blue
        recordButton.setTitle("foo", for: .normal)

        view.addSubview(recordButton)

        NSLayoutConstraint.activate([
            recordButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            recordButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: 0),
        ])
    }
}
