//
//  Recorder.swift
//  AudioRecorderPlayerSwift
//
//  Created by Max Harris on 11/6/20.
//

import AudioToolbox
import Foundation

class RecordingState {
    var running: Bool
    var drawOperationCollector: DrawOperationCollector

    init(running: Bool, drawOperationCollector: DrawOperationCollector) {
        self.running = running
        self.drawOperationCollector = drawOperationCollector
    }
}

func inputCallback(inUserData: UnsafeMutableRawPointer?, inQueue: AudioQueueRef, inBuffer: AudioQueueBufferRef, inStartTime _: UnsafePointer<AudioTimeStamp>, inNumPackets _: UInt32, inPacketDesc _: UnsafePointer<AudioStreamPacketDescription>?) {
//    print("in inputCallback()")

    guard let recorder = inUserData?.assumingMemoryBound(to: RecordingState.self) else {
        return
    }

    let bytesPerChannel = MemoryLayout<Int16>.size
    let numBytes: Int = Int(inBuffer.pointee.mAudioDataByteSize) / bytesPerChannel

    let int16Ptr = inBuffer.pointee.mAudioData.bindMemory(to: Int16.self, capacity: numBytes)
    let int16Buffer = UnsafeBufferPointer(start: int16Ptr, count: numBytes)

    let timestamp = getCurrentTimestamp()
    let id: Int64 = -1
    let audioSamples: [Int16] = Array(int16Buffer)
    if audioSamples.count > 0 {
        recorder.pointee.drawOperationCollector.addOp(op: AudioClip(timestamp: timestamp, id: id, audioSamples: audioSamples))
    }

    // enqueue the buffer, or re-enqueue it if it's a used one
    if recorder.pointee.running {
        check(AudioQueueEnqueueBuffer(inQueue, inBuffer, 0, nil))
    }
}
