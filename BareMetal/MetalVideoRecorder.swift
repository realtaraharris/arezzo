//
//  MetalVideoRecorder.swift
//  BareMetal
//
//  Created by Max Harris on 2/12/21.
//  Copyright © 2021 Max Harris. All rights reserved.
//

// Original code by Warren Moore, from Stack Overflow https://stackoverflow.com/a/43860229/53140

import AVKit
import Foundation

class MetalVideoRecorder {
    var isRecording = false
    var recordingStartTime = TimeInterval(0)

    private var assetWriter: AVAssetWriter
    private var assetWriterVideoInput: AVAssetWriterInput
    private var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor
    private var audioInput: AVAssetWriterInput
    private var size: CGSize

    init?(outputURL url: URL, size: CGSize) {
        do {
            self.assetWriter = try AVAssetWriter(outputURL: url, fileType: AVFileType.m4v)
        } catch {
            print("Error creating video output file: \(url.absoluteString)")
            return nil
        }

        let outputSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                             AVVideoWidthKey: size.width,
                                             AVVideoHeightKey: size.height]

        let audioOutputSettings = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0,
            AVEncoderBitRateKey: 192_000,
        ] as [String: Any]

        self.audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
        self.audioInput.expectsMediaDataInRealTime = true

        self.assetWriter.add(self.audioInput)

        self.assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        self.assetWriterVideoInput.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]

        self.size = size

        self.assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.assetWriterVideoInput,
                                                                                sourcePixelBufferAttributes: sourcePixelBufferAttributes)

        self.assetWriter.add(self.assetWriterVideoInput)
    }

    func startRecording() {
        self.assetWriter.startWriting()
        let sourceTime = CMTimeMake(value: 0, timescale: TIMESCALE)
        self.assetWriter.startSession(atSourceTime: sourceTime)
        print("STARTING RECORDING AT:", sourceTime)

        self.recordingStartTime = 0
//        self.isRecording = true
    }

    func endRecording(_ completionHandler: @escaping () -> Void) {
//        self.isRecording = false

        self.assetWriterVideoInput.markAsFinished()
        self.assetWriter.finishWriting(completionHandler: completionHandler)
    }

    func writeAudio(samples: CMSampleBuffer) {
        self.audioInput.append(samples)
    }

    func writeFrame(forTexture texture: MTLTexture, timestamp: Double) {
        print("VIDEO TIMESTAMP:", timestamp)

        while !self.assetWriterVideoInput.isReadyForMoreMediaData {}

//        guard let pixelBufferPool = assetWriterPixelBufferInput.pixelBufferPool else {
//            print("Pixel buffer asset writer input did not have a pixel buffer pool available; cannot retrieve frame")
//            return
//        }

        let sourcePixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: size.width,
            kCVPixelBufferHeightKey: self.size.height,
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as [CFString: Any]

        var pixelBuffer: CVPixelBuffer?
        var dumbStatus: CVReturn = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(self.size.width),
            Int(self.size.height),
            kCVPixelFormatType_32BGRA,
            sourcePixelBufferAttributes as CFDictionary,
            &pixelBuffer
        )

        print("DumbStatus:", dumbStatus)

//        var maybePixelBuffer: CVPixelBuffer?
//        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &maybePixelBuffer)
//        if status != kCVReturnSuccess {
//            print("Could not get pixel buffer from asset writer input; dropping frame...")
//            return
//        }

//        guard let pixelBuffer = maybePixelBuffer else {
//            print("NOPE!!!")
//            return
//        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        let pixelBufferBytes = CVPixelBufferGetBaseAddress(pixelBuffer!)!

        // Use the bytes per row value from the pixel buffer since its stride may be rounded up to be 16-byte aligned
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer!)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)

        texture.getBytes(pixelBufferBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let presentationTime = CMTimeMake(value: Int64(timestamp * 1000), timescale: TIMESCALE)
        print("line 113 presentationTime:", presentationTime)
        assetWriterPixelBufferInput.append(pixelBuffer!, withPresentationTime: presentationTime)

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, [])
    }
}
