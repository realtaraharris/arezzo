//
//  ColorPickerPopover.swift
//  BareMetal
//
//  Created by Max Harris on 8/13/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import SwiftUI

struct ColorPickerPopover: View {
    @State private var showPopover: Bool = false
    @Binding var selectedColor: SwiftUI.Color
    @Binding var uiRects: [String: CGRect]

    var body: some View {
        HStack {
            Button(action: {
                self.showPopover = true
            }
            ) {
                Text("Colors")
            }
            .popover(isPresented: $showPopover) {
                HStack {
                    ForEach(largePalette, id: \.self) { column in
                        VStack {
                            ForEach(column, id: \.self) { c in
                                ColorSwatch(color: Color(red: c[0], green: c[1], blue: c[2], opacity: c[3]), showPopover: self.$showPopover, selectedColor: self.$selectedColor)
                            }
                        }
                    }
                }
                .padding(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
                .background(GeometryGetter(rects: self.$uiRects, key: "colorPicker"))
                .onDisappear(perform: {
                    self.uiRects.removeValue(forKey: "colorPicker")
                })
            }
        }
    }
}

// struct ColorPickerPopover_Preview: PreviewProvider {
//    static var previews: some View {
//        ColorPickerPopover(selectedColor: Color.green)
//    }
// }
