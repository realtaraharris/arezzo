//
//  GeometryGetter.swift
//  BareMetal
//
//  Created by Max Harris on 8/13/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import SwiftUI

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
