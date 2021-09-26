//
//  Index.swift
//  Arezzo
//
//  Created by Max Harris on 5/1/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation

class RecordingIndex {
    var recordings: [String: Recording] = [:]
    var currentRecording: Recording!
    var pathStack: [String] = []

    init() {
        self.addRecording(name: "Root")
        self.currentRecording = self.recordings["Root"]
        self.pushRecording(name: "Root")
    }

    @discardableResult func addRecording(name: String) -> Recording {
        let recording = Recording(name: name)
        self.recordings[name] = recording

        return recording
    }

    func pushRecording(name: String) {
        self.currentRecording = self.getRecordingByUrl(name: name)
        self.pathStack.append(name)
    }

    func popRecording() {
        guard self.pathStack.count > 1 else { return }
        self.pathStack.removeLast()
        self.currentRecording = self.getRecordingByUrl(name: self.pathStack.last!)
    }

    func getRecordingByUrl(name: String) -> Recording! {
        self.recordings[name]
    }

    func save(filename: String) {
        let path = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("json")

        do {
            let jsonData = try JSONEncoder().encode(Array(self.recordings.keys))
            let jsonString = String(data: jsonData, encoding: .utf8)!
            try jsonString.write(to: path, atomically: true, encoding: String.Encoding.utf8)

            for (name, recording) in self.recordings {
                recording.serialize(filename: name)
            }
        } catch {
            print(error)
        }
    }

    func restore(filename: String) {
        self.recordings.removeAll()
        let path = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("json")

//        func progressCallback(todoCount: Int, todo: Int) {
//            let progress = Float(todoCount) / Float(todo)
//
//            DispatchQueue.main.async {
        // //                self.toolbar.documentVC.restoreProgressIndicator.progress = progress
//            }
//        }

        do {
            let jsonString = try String(contentsOf: path, encoding: .utf8)
            let decoded = try JSONDecoder().decode([String].self, from: jsonString.data(using: .utf8)!)

            for name in decoded {
                let restoredRecording = self.addRecording(name: name)
                restoredRecording.deserialize(filename: name)
                if name == "Root" {
                    self.currentRecording = restoredRecording
                }
            }
        } catch {
            print(error)
        }
    }
}
