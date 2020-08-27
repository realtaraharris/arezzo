//
//  AudioPlayer.swift
//  Arezzo
//
//  Created by Max Harris on 6/5/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import AVFoundation
import Combine
import Foundation
import SwiftUI

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    let objectWillChange = PassthroughSubject<AudioPlayer, Never>()

    var isPlaying = false {
        didSet {
            objectWillChange.send(self)
        }
    }

    var audioPlayer: AVAudioPlayer!

    func startPlayback(audio: URL) {
//        let timestamp = getCurrentTimestamp()
        let playbackSession = AVAudioSession.sharedInstance()

        print("playbackSession.availableCategories:", playbackSession.availableCategories)
        print("playbackSession.availableModes:", playbackSession.availableModes)
        print("playbackSession.availableInputs:", playbackSession.availableInputs ?? [])

        do {
            try playbackSession.setCategory(AVAudioSession.Category.playback,
                                            mode: AVAudioSession.Mode.moviePlayback,
                                            options: [])
        } catch {
            print(error)
        }

//        do {
//            try playbackSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
//        } catch {
//            print("Playing over the device's speakers failed")
//        }

//        playbackSession.overrideOutputAudioPort(AVAudioSession.Port.)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audio)
            audioPlayer.delegate = self
            audioPlayer.play()
            isPlaying = true
        } catch {
            print("Playback failed.")
        }
    }

    func stopPlayback() {
        audioPlayer.stop()
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            isPlaying = false
        }
    }
}
