//
//  AudioRecorder.swift
//  Arezzo
//
//  Created by Max Harris on 6/4/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import AVFoundation
import Combine
import Foundation
import SwiftUI

class AudioRecorder: NSObject, ObservableObject {
    override init() {
        super.init()
        self.fetchRecordings()
    }

    let objectWillChange = PassthroughSubject<AudioRecorder, Never>()

    var audioRecorder: AVAudioRecorder!

    var recordings = [Recording]()

    var recording = false {
        didSet {
            self.objectWillChange.send(self)
        }
    }

//

    func startRecording() -> URL {
        let timestamp = getCurrentTimestamp()
        print("starting setup for recording: \(timestamp)")

        let recordingSession = AVAudioSession.sharedInstance()

        print("recordingSession.availableCategories:", recordingSession.availableCategories)
        print("recordingSession.availableModes:", recordingSession.availableModes)
        print("recordingSession.availableInputs:", recordingSession.availableInputs ?? [])

        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            print("Failed to set up recording session")
        }

        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("\(Date().toString(dateFormat: "dd-MM-YY_'at'_HH:mm:ss")).m4a")

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            self.audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)

            let timestamp2 = getCurrentTimestamp()
            print("starting at: \(timestamp2)")
            audioRecorder.record()

            self.recording = true
        } catch {
            print("Could not start recording")
        }

        return audioFilename
    }

    func stopRecording() {
        self.audioRecorder.stop()
        self.recording = false

        self.fetchRecordings()
    }

    func fetchRecordings() {
        self.recordings.removeAll()

        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directoryContents = try! fileManager.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
        for audio in directoryContents {
            let recording = Recording(fileURL: audio, createdAt: getCreationDate(for: audio))
            recordings.append(recording)
        }

        self.recordings.sort(by: { $0.createdAt.compare($1.createdAt) == .orderedAscending })

        self.objectWillChange.send(self)
    }

    func deleteRecording(urlsToDelete: [URL]) {
        for url in urlsToDelete {
            print(url)
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("File could not be deleted!")
            }
        }

        self.fetchRecordings()
    }
}

struct SoundControl: View {
    @ObservedObject var audioRecorder: AudioRecorder

    var body: some View {
        NavigationView {
            VStack {
                RecordingsList(audioRecorder: audioRecorder)
                if audioRecorder.recording == false {
                    Button(action: {
                        print("STARTED RECORDING")
                        print(self.audioRecorder.startRecording())
                    }) {
                        Image(systemName: "circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipped()
                            .foregroundColor(.red)
                            .padding(.bottom, 40)
                    }
                } else {
                    Button(action: {
                        print("STOPPED RECORDING")
                        self.audioRecorder.stopRecording()
                    }) {
                        Image(systemName: "stop.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipped()
                            .foregroundColor(.red)
                            .padding(.bottom, 40)
                    }
                }
            }
//            .navigationBarTitle("Voice recorder")
            .navigationBarItems(trailing: EditButton())
        }
    }
}

// struct ContentPreviews: PreviewProvider {
//    static var previews: some View {
//        ContentViewEx(audioRecorder: AudioRecorder())
//    }
// }

struct RecordingsList: View {
    @ObservedObject var audioRecorder: AudioRecorder

    var body: some View {
        List {
            ForEach(audioRecorder.recordings, id: \.createdAt) { recording in
                RecordingRow(audioURL: recording.fileURL)
            }
            .onDelete(perform: delete)
        }
    }

    func delete(at offsets: IndexSet) {
        var urlsToDelete = [URL]()
        for index in offsets {
            urlsToDelete.append(self.audioRecorder.recordings[index].fileURL)
        }
        self.audioRecorder.deleteRecording(urlsToDelete: urlsToDelete)
    }
}

struct RecordingsListPreviews: PreviewProvider {
    static var previews: some View {
        RecordingsList(audioRecorder: AudioRecorder())
    }
}

struct RecordingRow: View {
    var audioURL: URL

    @ObservedObject var audioPlayer = AudioPlayer()

    var body: some View {
        HStack {
            Text("\(audioURL.lastPathComponent)")
            Spacer()
            if audioPlayer.isPlaying == false {
                Button(action: {
                    self.audioPlayer.startPlayback(audio: self.audioURL)
                }) {
                    Image(systemName: "play.circle")
                        .imageScale(.large)
                }
            } else {
                Button(action: {
                    self.audioPlayer.stopPlayback()
                }) {
                    Image(systemName: "stop.fill")
                        .imageScale(.large)
                }
            }
        }
    }
}
