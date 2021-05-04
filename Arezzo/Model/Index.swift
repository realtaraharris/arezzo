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
    var currentRecording: Recording!
    var pathStack: [String] = []

    init() {
        self.addRecording(name: "Root")
        self.currentRecording = self.recordings[0]
        self.pushRecording(name: "Root")
    }

    func addRecording(name: String) {
        let recording = Recording(name: name, recordingIndex: self)
        self.recordings.append(recording)
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
}
