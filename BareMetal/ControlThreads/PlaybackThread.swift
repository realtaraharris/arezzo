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
        guard self.drawOperationCollector.timestamps.count > 0 else {
            return
        }

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

        let recordedCursor = self.drawOperationCollector.timestamps[startIndex]
        let recordedStart = self.drawOperationCollector.timestamps[0]
        let timeOffset = recordedCursor - recordedStart

        self.playingState.lastIndexRead = calcBufferOffset(timeOffset: timeOffset)

        guard timestampIterator.count > 0 else { return }

        let timeStart = self.drawOperationCollector.timestamps[0]
        let timeEnd = self.drawOperationCollector.timestamps[self.drawOperationCollector.timestamps.count - 1]

        let timeDelta = timeEnd - timeStart

        let (firstTime, _) = timestampIterator.next()!
        let playbackStart = CFAbsoluteTimeGetCurrent()

        /*
                   0         a   a'       b
          recorded |---------|===,========|---------|
          playback |---------------------------------------|===,========|---------|
                   0                                       c   c'

          timeDelta = b - a
          currentPct = (c'-c + a'-a)/timeDelta

          where
            c' = playbackCursor
            c = playbackStart
            a' = recordedCursor
            a = recordedStart
         */

        func renderNext(_: CFRunLoopTimer?) {
            let playbackCursor = CFAbsoluteTimeGetCurrent()
            let position: Float = Float((playbackCursor - playbackStart + recordedCursor - recordedStart) / timeDelta)

            self.toolbar.playbackSlider!.setValueEx(value: position)

            if !self.playing {
                return
            }
            let (currentTime, nextTime) = timestampIterator.next()!

            if nextTime == -1 {
                self.toolbar.playbackSlider!.setValueEx(value: 1.0)
                self.playingState.running = false
                return
            }

            if runNumber < self.currentRunNumber { return }
            self.currentRunNumber = runNumber

            self.render(endTimestamp: currentTime)

            let fireDate = playbackStart + nextTime - firstTime

            self.nextRenderTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, renderNext)
            RunLoop.current.add(nextRenderTimer!, forMode: .common)
        }

        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, playbackStart, 0, 0, 0, renderNext)
        RunLoop.current.add(timer!, forMode: .common)

        check(AudioQueueStart(self.queue!, nil))

        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, BUFFER_DURATION, false)
    }
}
