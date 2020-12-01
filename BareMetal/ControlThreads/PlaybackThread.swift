//
//  PlaybackThread.swift
//  BareMetal
//
//  Created by Max Harris on 11/30/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import AudioToolbox
import Foundation

extension ViewController {
    @objc func playback(thread _: Thread) {
        check(AudioQueueNewOutput(&audioFormat, outputCallback, &self.playingState, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &self.queue))

        var buffers: [AudioQueueBufferRef?] = Array<AudioQueueBufferRef?>.init(repeating: nil, count: BUFFER_COUNT)

        self.playingState.running = true

        for i in 0 ..< BUFFER_COUNT {
            check(AudioQueueAllocateBuffer(self.queue!, UInt32(bufferByteSize), &buffers[i]))
            outputCallback(inUserData: &self.playingState, inAQ: self.queue!, inBuffer: buffers[i]!)

            if !self.playingState.running {
                break
            }
        }

        let timestamps = Timestamps(timestamps: Array(self.timestamps))
        var timestampIterator = timestamps.makeIterator()

        let (currInit, nextInit) = timestampIterator.next()!
        let delta = nextInit - currInit

        func renderNext(_: Timer) {
            let (curr, next) = timestampIterator.next()!

            if next == -1 {
                self.playingState.running = false
                return
            }

            self.render(endTimestamp: curr)

            let delta = next - curr
            let timer = Timer(fire: Date(milliseconds: getCurrentTimestamp() + delta), interval: 0, repeats: false, block: renderNext)
            RunLoop.current.add(timer, forMode: .common)
        }

        let timer = Timer(fire: Date(milliseconds: delta), interval: 0, repeats: false, block: renderNext)
        RunLoop.current.add(timer, forMode: .common)

        check(AudioQueueStart(self.queue!, nil))

        repeat {
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, BUFFER_DURATION, false)
        } while !self.playbackThread.isCancelled

        if !self.playbackThread.isCancelled {
            // delay to ensure queue emits all buffered audio
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, BUFFER_DURATION * Double(BUFFER_COUNT + 1), false)
        }

        self.playing = false
        performSelector(onMainThread: #selector(self.stopPlayUI), with: nil, waitUntilDone: false)

        check(AudioQueueStop(self.queue!, true))
        check(AudioQueueDispose(self.queue!, true))
    }
}