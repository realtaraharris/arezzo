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

        self.assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        self.assetWriterVideoInput.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
        ]

        self.assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.assetWriterVideoInput,
                                                                                sourcePixelBufferAttributes: sourcePixelBufferAttributes)

        self.assetWriter.add(self.assetWriterVideoInput)
    }

    func startRecording() {
        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: CMTime.zero)

        self.recordingStartTime = CACurrentMediaTime()
        self.isRecording = true
    }

    func endRecording(_ completionHandler: @escaping () -> Void) {
        self.isRecording = false

        self.assetWriterVideoInput.markAsFinished()
        self.assetWriter.finishWriting(completionHandler: completionHandler)
    }

    func writeFrame(forTexture texture: MTLTexture) {
        if !self.isRecording {
            return
        }

        while !self.assetWriterVideoInput.isReadyForMoreMediaData {}

        guard let pixelBufferPool = assetWriterPixelBufferInput.pixelBufferPool else {
            print("Pixel buffer asset writer input did not have a pixel buffer pool available; cannot retrieve frame")
            return
        }

        var maybePixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &maybePixelBuffer)
        if status != kCVReturnSuccess {
            print("Could not get pixel buffer from asset writer input; dropping frame...")
            return
        }

        guard let pixelBuffer = maybePixelBuffer else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let pixelBufferBytes = CVPixelBufferGetBaseAddress(pixelBuffer)!

        // Use the bytes per row value from the pixel buffer since its stride may be rounded up to be 16-byte aligned
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)

        texture.getBytes(pixelBufferBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let frameTime = CACurrentMediaTime() - self.recordingStartTime
        let presentationTime = CMTimeMakeWithSeconds(frameTime, preferredTimescale: 240)
        assetWriterPixelBufferInput.append(pixelBuffer, withPresentationTime: presentationTime)

        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }
}
