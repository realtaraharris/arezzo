//
//  ColorSwatch.swift
//  BareMetal
//
//  Created by Max Harris on 8/13/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import SwiftUI

struct ColorSwatch: View {
    var color: SwiftUI.Color
    @Binding var showPopover: Bool
    @Binding var selectedColor: SwiftUI.Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 30, height: 30)
            .onTapGesture {
                self.selectedColor = self.color
                self.showPopover = false
            }
    }
}
