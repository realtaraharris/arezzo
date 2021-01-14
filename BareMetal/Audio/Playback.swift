//
//  Player.swift
//  AudioRecorderPlayerSwift
//
//  Created by Max Harris on 11/6/20.
//

import AudioToolbox
import Foundation

struct PlayingState {
    var running: Bool = false
    var lastIndexRead: Int = 0
}

func outputCallback(inUserData: UnsafeMutableRawPointer?, inAQ: AudioQueueRef, inBuffer: AudioQueueBufferRef) {
    guard let player = inUserData?.assumingMemoryBound(to: PlayingState.self) else {
        print("missing user data in output callback")
        return
    }

    let bytesPerChannel = MemoryLayout<Int16>.size
    let sliceStart = player.pointee.lastIndexRead
    let sliceEnd = min(audioData.count, player.pointee.lastIndexRead + bufferByteSize / bytesPerChannel)

    if sliceEnd >= audioData.count {
        player.pointee.running = false
        print("found end of audio data")
        return
    }

    let slice = Array(audioData[sliceStart ..< sliceEnd])
    let sliceCount = slice.count

    // print("slice start:", sliceStart, "slice end:", sliceEnd, "audioData.count", audioData.count, "slice count:", sliceCount)

    // need to be careful to convert from counts of Ints to bytes
    memcpy(inBuffer.pointee.mAudioData, slice, sliceCount * bytesPerChannel)
    inBuffer.pointee.mAudioDataByteSize = UInt32(sliceCount * bytesPerChannel)
    player.pointee.lastIndexRead += sliceCount

    // enqueue the buffer, or re-enqueue it if it's a used one
    check(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil))
}
