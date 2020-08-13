//
//  ContentView.swift
//  Arezzo
//
//  Created by Max Harris on 5/24/20.
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

struct ColorPickerPopover: View {
    @State private var showPopover: Bool = false
    @Binding var selectedColor: SwiftUI.Color
    @Binding var uiRects: [String: CGRect]

    /* this is necessary because the description field of the resulting Color object will be a string like 'red' if you initialize with Color(.red), and the extension above will return zero for each component */
    var red: SwiftUI.Color = SwiftUI.Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0)
    var blue: SwiftUI.Color = SwiftUI.Color(red: 0.0, green: 0.0, blue: 1.0, opacity: 1.0)
    var green: SwiftUI.Color = SwiftUI.Color(red: 0.0, green: 1.0, blue: 0.0, opacity: 1.0)

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

extension View {
    func Print(_ vars: Any...) -> some View {
        for v in vars { print(v) }
        return EmptyView()
    }
}

struct GeometryGetter: View {
    @Binding var rects: [String: CGRect]
    let key: String

    var body: some View {
        GeometryReader { geometry in
            self.makeView(geometry: geometry)
        }
    }

    func makeView(geometry: GeometryProxy) -> some View {
        DispatchQueue.main.async {
            self.rects[self.key] = geometry.frame(in: .global)
        }

        return Rectangle().fill(Color.clear)
    }
}

struct ContentView: View {
    @ObservedObject var delegate: ContentViewDelegate

    init(delegate: ContentViewDelegate) {
        self.delegate = delegate
    }

    @State var currentPage = 0

    @State var drawViewEnabled = true

    @State private var clearScreen = false
    @State private var undo = false
    @State private var redo = false

    var body: some View {
        ZStack {
            VStack {
                ToolPalette()
                HStack(alignment: .bottom, spacing: 10) {
                    Button("Clear") {
                        self.delegate.clear = true
                    }
                    Button("Undo") {
                        self.undo = true
                    }
                    Button("Redo") {
                        self.redo = true
                    }

                    self.delegate.recording ? Button("Stop Recording") {
                        self.delegate.recording = false
                    } : Button("Record") {
                        self.delegate.recording = true
                    }
                    self.delegate.playing ? Button("Stop Playing") {
                        self.delegate.playing = false
                    } : Button("Play") {
                        self.delegate.playing = true
                    }

                    ColorPickerPopover(selectedColor: self.$delegate.selectedColor, uiRects: $delegate.uiRects)
                    // SoundControl(audioRecorder: AudioRecorder()).background(Color.clear)
                }.background(GeometryGetter(rects: $delegate.uiRects, key: "main"))
            }
        }
    }
}

struct ToolPalette: View {
    @State private var currentPosition: CGSize = .zero
    @State private var newPosition: CGSize = .zero
    @State private var tapped = false
    @State private var expanded = false

    var body: some View {
        let circleDragGesture = DragGesture(minimumDistance: 0.0, coordinateSpace: CoordinateSpace.global)
            .onChanged { value in
                self.currentPosition = CGSize(
                    width: value.translation.width + self.newPosition.width,
                    height: value.translation.height + self.newPosition.height
                )
                self.tapped = true
            }
            .onEnded { value in
                self.currentPosition = CGSize(
                    width: value.translation.width + self.newPosition.width,
                    height: value.translation.height + self.newPosition.height
                )
                print(self.newPosition.width)
                self.newPosition = self.currentPosition
                self.tapped = false
            }

        return !expanded ? AnyView(Circle()
            .scaleEffect(tapped ? 1.3 : 1)
            .frame(width: 60, height: 60)
            .foregroundColor(Color.white)
            .shadow(color: Color(red: 0.9, green: 0.9, blue: 0.9, opacity: 1.0), radius: 10)
            .offset(x: self.currentPosition.width, y: self.currentPosition.height)
            .onTapGesture {
                self.tapped.toggle()
            }
            .gesture(circleDragGesture))
            : AnyView(Rectangle()
                .frame(width: 300, height: 120)
                .foregroundColor(Color.green)
                .offset(x: self.currentPosition.width, y: self.currentPosition.height)
                .drawingGroup()
                .gesture(circleDragGesture))
    }
}
