//
//  Index.swift
//  Arezzo
//
//  Created by Max Harris on 5/1/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

import Foundation

class RecordingIndex {
    var recordings: [Recording] = []
    var urls: [String] = []
    var currentRecording: Recording!
    var pathStack: [String] = []

    init() {
        self.addRecording(name: "Root")
        self.currentRecording = self.recordings[0]
        self.pushRecording(name: "Root")
    }

    func addRecording(name: String) -> Recording {
        let recording = Recording(name: name, recordingIndex: self)
        self.recordings.append(recording)
        self.urls.append(name)

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
        guard let index = self.recordings.firstIndex(where: { $0.name == name }) else {
            print("error - could not find recording")
            return nil
        }
        return self.recordings[index]
    }

    func save(filename: String) {
        let path = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("json")

        do {
            let jsonData = try JSONEncoder().encode(self.urls)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            try jsonString.write(to: path, atomically: true, encoding: String.Encoding.utf8)

            for recording in self.recordings {
                recording.serialize(filename: recording.name)
            }
        } catch {
            print(error)
        }
    }

    func restore(filename: String) {
        self.urls.removeAll()
        self.recordings.removeAll()
        let path = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("json")

        func progressCallback(todoCount: Int, todo: Int) {
            let progress = Float(todoCount) / Float(todo)

            DispatchQueue.main.async {
//                self.toolbar.documentVC.restoreProgressIndicator.progress = progress
            }
        }

        do {
            let jsonString = try String(contentsOf: path, encoding: .utf8)
            let decoded = try JSONDecoder().decode([String].self, from: jsonString.data(using: .utf8)!)

            for name in decoded {
                let restoredRecording = self.addRecording(name: name)
                restoredRecording.deserialize(filename: name, progressCallback)
                if name == "Root" {
                    self.currentRecording = restoredRecording
                }
            }
        } catch {
            print(error)
        }
    }
}
