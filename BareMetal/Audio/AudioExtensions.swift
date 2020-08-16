//
//  Extensions.swift
//  Arezzo
//
//  Created by Max Harris on 6/5/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation

extension Date {
    func toString(dateFormat format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}
