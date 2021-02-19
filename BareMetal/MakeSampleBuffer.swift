//
//  MakeSampleBuffer.swift
//  BareMetal
//
//  Created by Max Harris on 2/16/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

// from https://stackoverflow.com/a/34463033/53140

import CoreMedia
import Foundation

let TIMESCALE: Int32 = 800

func createAudio(sampleBytes: UnsafeRawPointer, startFrm: Double, nFrames: Int, sampleRate: Float64, numChannels: UInt32) -> CMSampleBuffer? {
    let bytesPerFrame = UInt32(2 * numChannels)
    let blockSize = nFrames * Int(bytesPerFrame)

    var block: CMBlockBuffer?
    var status = CMBlockBufferCreateWithMemoryBlock(
        allocator: kCFAllocatorDefault,
        memoryBlock: nil,
        blockLength: blockSize,
        blockAllocator: nil,
        customBlockSource: nil,
        offsetToData: 0,
        dataLength: blockSize,
        flags: 0,
        blockBufferOut: &block
    )
    assert(status == kCMBlockBufferNoErr)

    CMBlockBufferReplaceDataBytes(with: sampleBytes, blockBuffer: block!, offsetIntoDestination: 0, dataLength: blockSize)
    assert(status == kCMBlockBufferNoErr)

    var asbd = AudioStreamBasicDescription(
        mSampleRate: sampleRate,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kLinearPCMFormatFlagIsSignedInteger,
        mBytesPerPacket: bytesPerFrame,
        mFramesPerPacket: 1,
        mBytesPerFrame: bytesPerFrame,
        mChannelsPerFrame: numChannels,
        mBitsPerChannel: 16,
        mReserved: 0
    )

    var formatDesc: CMAudioFormatDescription?
    status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDesc)
    assert(status == noErr)

    print("AUDIO TIMESTAMP:", startFrm)
    let presentationTimestamp = CMTimeMake(value: Int64(startFrm), timescale: TIMESCALE)
    print("line 52 presentationTimestamp:", presentationTimestamp)

    var sampleBuffer: CMSampleBuffer?
    status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
        allocator: kCFAllocatorDefault,
        dataBuffer: block!,
        formatDescription: formatDesc!,
        sampleCount: nFrames,
        presentationTimeStamp: presentationTimestamp,
        packetDescriptions: nil,
        sampleBufferOut: &sampleBuffer
    )
    assert(status == noErr)

    return sampleBuffer
}
