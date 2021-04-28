//
//  Utilities.swift
//  Arezzo
//
//  Created by Max Harris on 4/28/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation

extension FileManager {
    func removePossibleItem(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            fatalError("\(error)")
        }
    }
}
