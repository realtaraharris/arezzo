//
//  PlaybackThread.swift
//  BareMetal
//
//  Created by Max Harris on 11/30/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import AudioToolbox
import Foundation

@available(iOS 14.0, *)
@available(macCatalyst 14.0, *)
extension ViewController {
    func playback(runNumber: Int) {
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
            if !self.playing {
                return
            }
            let (currentTime, nextTime) = timestampIterator.next()!

            if nextTime == -1 {
                self.playingState.running = false
                return
            }

            if runNumber < self.currentRunNumber { return }
            self.currentRunNumber = runNumber

            self.render(endTimestamp: currentTime)
            let current: Float = Float(self.playingState.lastIndexRead)
            let position: Float = current / totalAudioLength
            self.toolbar.playbackSlider!.setValue(Float(position), animated: false)

            let fireDate = startTime + nextTime - firstTime
            self.nextRenderTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, renderNext)
            RunLoop.current.add(nextRenderTimer!, forMode: .common)
        }

        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, startTime, 0, 0, 0, renderNext)
        RunLoop.current.add(timer!, forMode: .common)

        check(AudioQueueStart(self.queue!, nil))

        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, BUFFER_DURATION, false)
    }
}
