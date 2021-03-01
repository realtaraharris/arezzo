//
//  Player.swift
//  AudioRecorderPlayerSwift
//
//  Created by Max Harris on 11/6/20.
//

import AudioToolbox
import Foundation

class PlayingState {
    var running: Bool
    var lastIndexRead: Int
    var audioData: [Int16]

    init(running: Bool, lastIndexRead: Int, audioData: [Int16]) {
        self.running = running
        self.lastIndexRead = lastIndexRead
        self.audioData = audioData
    }
}

func outputCallback(inUserData: UnsafeMutableRawPointer?, inAQ: AudioQueueRef, inBuffer: AudioQueueBufferRef) {
    guard let player = inUserData?.assumingMemoryBound(to: PlayingState.self) else {
        print("missing user data in output callback")
        return
    }

    print("player.pointee.running:", player.pointee.running)
    if player.pointee.running == false { return }

    let bytesPerChannel = MemoryLayout<Int16>.size
    let sliceStart = player.pointee.lastIndexRead
    let sliceEnd = min(player.pointee.audioData.count, player.pointee.lastIndexRead + bufferByteSize / bytesPerChannel)

    if sliceEnd >= player.pointee.audioData.count {
        player.pointee.running = false
        print("found end of audio data")
        return
    }

    let slice = Array(player.pointee.audioData[sliceStart ..< sliceEnd])
    let sliceCount = slice.count

    // print("slice start:", sliceStart, "slice end:", sliceEnd, "audioData.count", audioData.count, "slice count:", sliceCount)

    // need to be careful to convert from counts of Ints to bytes
    memcpy(inBuffer.pointee.mAudioData, slice, sliceCount * bytesPerChannel)
    inBuffer.pointee.mAudioDataByteSize = UInt32(sliceCount * bytesPerChannel)
    player.pointee.lastIndexRead += sliceCount

    // enqueue the buffer, or re-enqueue it if it's a used one
    check(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil))
}
