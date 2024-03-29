//
//  MakeSampleBuffer.swift
//  Arezzo
//
//  Created by Max Harris on 2/16/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

// from https://stackoverflow.com/a/34463033/53140

import CoreMedia
import Foundation

func createAudio(sampleBytes: UnsafeRawPointer, startFrm: Double, nFrames: Int, sampleRate _: Float64, numChannels _: UInt32) -> CMSampleBuffer? {
    let bytesPerFrame = BYTES_PER_FRAME
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

    var asbd = audioFormat

    var formatDesc: CMAudioFormatDescription?
    status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDesc)
    assert(status == noErr)

    let presentationTimestamp = CMTimeFromTimeInterval(startFrm)

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
