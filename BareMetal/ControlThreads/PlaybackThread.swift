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

        let (startIndex, endIndex) = self.drawOperationCollector.getTimestampIndices(startPosition: self.startPosition, endPosition: self.endPosition)
        var timestampIterator = self.drawOperationCollector.getTimestampIterator(startIndex: startIndex, endIndex: endIndex)

        let firstPlaybackTimestamp = self.drawOperationCollector.timestamps[startIndex]
        let firstTimestamp = self.drawOperationCollector.timestamps[0]
        let timeOffset = firstPlaybackTimestamp - firstTimestamp

        self.playingState.lastIndexRead = calcBufferOffset(timeOffset: timeOffset)
        let totalAudioLength: Float = Float(self.drawOperationCollector.audioData.count)

        let (firstTime, _) = timestampIterator.next()!
        let startTime = CFAbsoluteTimeGetCurrent()

        func renderNext(_: CFRunLoopTimer?) {
            let (currentTime, nextTime) = timestampIterator.next()!

            if nextTime == -1 {
                self.playingState.running = false
                return
            }

            self.render(endTimestamp: currentTime, present: true)

            let fireDate = startTime + nextTime - firstTime
            let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, renderNext)
            RunLoop.current.add(timer!, forMode: .common)
        }

        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, startTime, 0, 0, 0, renderNext)
        RunLoop.current.add(timer!, forMode: .common)

        check(AudioQueueStart(self.queue!, nil))

        func updateSliderPosition() {
            let current: Float = Float(self.playingState.lastIndexRead)
            let position: Float = current / totalAudioLength
            self.playbackSliderPosition = Float(position) // runloop on main thread picks this up and updates the UI - see ViewController.swift
        }

        repeat {
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, BUFFER_DURATION, false)
            updateSliderPosition()

        } while !self.playbackThread.isCancelled && self.playingState.running

        if !self.playbackThread.isCancelled {
            // delay to ensure queue emits all buffered audio
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, BUFFER_DURATION * Double(BUFFER_COUNT + 1), false)
            updateSliderPosition()
        }

        self.playing = false
        performSelector(onMainThread: #selector(self.stopPlayUI), with: nil, waitUntilDone: false)

        check(AudioQueueStop(self.queue!, true))
        check(AudioQueueDispose(self.queue!, true))
    }
}
