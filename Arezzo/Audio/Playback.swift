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
    var currentAudioOpIndex: Int?
    var currentRecording: Recording?
    var audioOpIndexes: [Int]?

    init(running: Bool) {
        self.running = running
    }
}

func outputCallback(inUserData: UnsafeMutableRawPointer?, inAQ: AudioQueueRef, inBuffer: AudioQueueBufferRef) {
    guard let player = inUserData?.assumingMemoryBound(to: PlayingState.self) else {
        print("missing user data in output callback")
        return
    }

    if !player.pointee.running { return }

    let currentAudioOpIndex = player.pointee.currentAudioOpIndex!

    let audioOpIndexes = player.pointee.audioOpIndexes!
    if currentAudioOpIndex >= audioOpIndexes.count { return }

    let opIndex = audioOpIndexes[currentAudioOpIndex]
    let audioOp = player.pointee.currentRecording!.getOp(opIndex) as! AudioClip
//    print("currentAudioOpIndex:", currentAudioOpIndex, "opIndex:", opIndex, "audoOp.timestamp:", audioOp.timestamp, "time:", CFAbsoluteTimeGetCurrent(), "delta:", CFAbsoluteTimeGetCurrent() - audioOp.timestamp)
    let audioSamples = audioOp.audioSamples
    let sliceCount = audioOp.audioSamples.count
    let bytesPerChannel = MemoryLayout<Int16>.size
    memcpy(inBuffer.pointee.mAudioData, audioSamples, sliceCount * bytesPerChannel)
    inBuffer.pointee.mAudioDataByteSize = UInt32(sliceCount * bytesPerChannel)

    // enqueue the buffer, or re-enqueue it if it's a used one
    check(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil))

    player.pointee.currentAudioOpIndex! += 1
}
