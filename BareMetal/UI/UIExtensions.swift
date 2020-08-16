//
//  Extensions.swift
//  BareMetal
//
//  Created by Max Harris on 8/13/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import SwiftUI

// https://medium.com/better-programming/handling-colors-in-swiftui-576e8f100d65
extension Color {
    func toColorArray() -> [Float] {
        let hex = description
        let space = CharacterSet(charactersIn: " ")
        let trim = hex.trimmingCharacters(in: space)
        let value = hex.first != "#" ? "#\(trim)" : trim
        let values = Array(value)

        func radixValue(_ index: Int) -> Float? {
            var result: Float?
            if values.count > index + 1 {
                var input = "\(values[index])\(values[index + 1])"
                if values[index] == "0" {
                    input = "\(values[index + 1])"
                }
                if let val = Int(input, radix: 16) {
                    result = Float(val)
                }
            }
            return result
        }

        var rgb = (red: Float(0), green: Float(0), blue: Float(0), alpha: Float(0))
        if let outputR = radixValue(1) { rgb.red = outputR / 255 }
        if let outputG = radixValue(3) { rgb.green = outputG / 255 }
        if let outputB = radixValue(5) { rgb.blue = outputB / 255 }
        if let outputA = radixValue(7) { rgb.alpha = outputA / 255 }

        return [rgb.red, rgb.green, rgb.blue, rgb.alpha]
    }
}

extension View {
    func Print(_ vars: Any...) -> some View {
        for v in vars { print(v) }
        return EmptyView()
    }
}
