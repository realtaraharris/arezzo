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

        self.assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: self.assetWriterVideoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        self.assetWriter.add(self.assetWriterVideoInput)
    }

    func startRecording(_ timestamp: Double) {
        self.assetWriter.startWriting()
        let sourceTime = CMTimeMakeWithSeconds(timestamp, preferredTimescale: TIMESCALE)
        self.assetWriter.startSession(atSourceTime: sourceTime)
    }

    func endRecording(_ completionHandler: @escaping () -> Void) {
        self.assetWriterVideoInput.markAsFinished()
        self.assetWriter.finishWriting(completionHandler: completionHandler)
    }

    func writeAudio(samples: CMSampleBuffer) {
        while !self.audioInput.isReadyForMoreMediaData {}
        let ok = self.audioInput.append(samples)
        if !ok {
            print("audio append failed. error: ", self.assetWriter.error as Any)
        }
    }

    func writeFrame(forTexture texture: MTLTexture, timestamp: Double) {
        while !self.assetWriterVideoInput.isReadyForMoreMediaData {}

        let sourcePixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: size.width,
            kCVPixelBufferHeightKey: self.size.height,
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as [CFString: Any]

        var pixelBuffer: CVPixelBuffer?
        let pixelBufferStatus: CVReturn = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(self.size.width),
            Int(self.size.height),
            kCVPixelFormatType_32BGRA,
            sourcePixelBufferAttributes as CFDictionary,
            &pixelBuffer
        )

        if pixelBufferStatus != kCVReturnSuccess {
            print("error in pixelBufferStatus:", pixelBufferStatus)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        let pixelBufferBytes = CVPixelBufferGetBaseAddress(pixelBuffer!)!

        // Use the bytes per row value from the pixel buffer since its stride may be rounded up to be 16-byte aligned
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer!)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)

        texture.getBytes(pixelBufferBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let presentationTime = CMTimeMakeWithSeconds(timestamp, preferredTimescale: TIMESCALE)

        assetWriterPixelBufferInput.append(pixelBuffer!, withPresentationTime: presentationTime)

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, [])
    }
}
