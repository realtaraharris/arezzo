//
//  RecordingThread.swift
//  Arezzo
//
//  Created by Max Harris on 11/30/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import AudioToolbox
import Foundation

extension ViewController {
    @objc func recording(thread _: Thread) {
        var queue: AudioQueueRef?

        var recordingState = RecordingState(running: false, recording: self.recordingIndex.currentRecording)

        check(AudioQueueNewInput(&audioFormat, inputCallback, &recordingState, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &queue))

        var buffers: [AudioQueueBufferRef?] = Array<AudioQueueBufferRef?>.init(repeating: nil, count: BUFFER_COUNT)

        recordingState.running = true

        for i in 0 ..< BUFFER_COUNT {
            check(AudioQueueAllocateBuffer(queue!, UInt32(bufferByteSize), &buffers[i]))
            var bs = AudioTimeStamp()
            inputCallback(inUserData: &recordingState, inQueue: queue!, inBuffer: buffers[i]!, inStartTime: &bs, inNumPackets: 0, inPacketDesc: nil)

            if !recordingState.running {
                break
            }
        }

        check(AudioQueueStart(queue!, nil))

        repeat {
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, BUFFER_DURATION, false)
        } while !self.recordingThread.isCancelled

        recordingState.running = false
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, BUFFER_DURATION * Double(BUFFER_COUNT + 1), false)

        check(AudioQueueStop(queue!, true))
        check(AudioQueueDispose(queue!, true))
    }
}
