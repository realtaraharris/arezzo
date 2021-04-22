//
//  ViewController.swift
//  Arezzo
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import AudioToolbox
import Combine
import CoreMedia
import Foundation
import Metal
import Photos
import QuartzCore
import simd // vector_float2, vector_float4
import UIKit

import MetalKit

@available(iOS 14.0, *)
@available(macCatalyst 14.0, *)
class ViewController: UIViewController, ToolbarDelegate {
    var device: MTLDevice = MTLCreateSystemDefaultDevice()!
    var metalLayer: CAMetalLayer = CAMetalLayer()
    var mtkView: MTKView!
    var renderer: Renderer!
    var timer: CADisplayLink!
    var nextRenderTimer: CFRunLoopTimer?

    public lazy var allowedTouchTypes: [TouchType] = [.finger, .pencil]
    var queue: AudioQueueRef?

    let toolbar: Toolbar = Toolbar()
    var drawOperationCollector: DrawOperationCollector = DrawOperationCollector() // TODO: consider renaming this to shapeCollector

    var selectedColor: [Float] = [1.0, 0.0, 0.0, 1.0]
    var lineWidth: Float = DEFAULT_LINE_WIDTH
    var mode: PenDownMode = PenDownMode.draw
    var playing: Bool = false
    var recording: Bool = false
    var startPosition: Double = 0.0
    var endPosition: Double = 1.0
    var playingState: PlayingState = PlayingState(running: false, lastIndexRead: 0, audioData: [])
    var runNumber: Int = 0
    var currentRunNumber: Int = 0

    public var recordingThread: Thread = Thread() // TODO: get rid of this

    public enum TouchType: Equatable, CaseIterable {
        case finger, pencil

        var uiTouchTypes: [UITouch.TouchType] {
            switch self {
            case .finger:
                return [.direct, .indirect]
            case .pencil:
                return [.pencil, .stylus]
            }
        }
    }

    @objc override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black // without this, event handlers don't fire, not sure why yet

        print("window frame:", self.view.frame.width, self.view.frame.height)

        self.mtkView = MTKView() // frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
        self.mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self.mtkView)

//        self.mtkView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor).isActive = true
//        self.mtkView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor).isActive = true
//        self.mtkView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
//        self.mtkView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true

//        self.mtkView.leadingAnchor.constraint(equalTo: self.view.layoutMarginsGuide.leadingAnchor).isActive = true
//        self.mtkView.trailingAnchor.constraint(equalTo: self.view.layoutMarginsGuide.trailingAnchor).isActive = true
//        self.mtkView.topAnchor.constraint(equalTo: self.view.layoutMarginsGuide.topAnchor).isActive = true
//        self.mtkView.bottomAnchor.constraint(equalTo: self.view.layoutMarginsGuide.bottomAnchor).isActive = true

        self.mtkView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        self.mtkView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        self.mtkView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        self.mtkView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true

        self.mtkView.autoResizeDrawable = true
        self.mtkView.enableSetNeedsDisplay = true
        self.mtkView.isPaused = true
        self.mtkView.device = self.device

        self.mtkView.colorPixelFormat = .bgra8Unorm
        self.mtkView.depthStencilPixelFormat = .depth32Float
        self.renderer = Renderer(view: self.mtkView, device: self.device, drawOperationCollector: self.drawOperationCollector)
        self.mtkView.delegate = self.renderer

        self.toolbar.recordingVC.delegate = self
        self.toolbar.playbackVC.delegate = self
        self.toolbar.editingVC.delegate = self
        self.toolbar.colorPaletteVC.delegate = self
        self.toolbar.documentVC.delegate = self

        view.addSubview(self.toolbar.view)
    }

    // MARK: - input event handlers

    override open func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.recording, let touch = touches.first else { return }

        guard self.allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }

        let timestamp = getCurrentTimestamp()

        self.drawOperationCollector.beginProvisionalOps()
        self.drawOperationCollector.addOp(op: PenDown(color: self.selectedColor,
                                                      lineWidth: self.lineWidth,
                                                      timestamp: timestamp,
                                                      mode: self.mode), device: self.device)

        self.renderer.endTimestamp = timestamp
//        self.renderer.draw(in: self.mtkView)
        self.mtkView.setNeedsDisplay()
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.recording, let touch = touches.first else { return }

        guard self.allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }

        let timestamp = getCurrentTimestamp()

        let inputPoint = touch.location(in: view)
        let scale = self.mtkView.contentScaleFactor
        let point = [Float(inputPoint.x * scale), Float(inputPoint.y * scale)]
        print(point)
        if self.mode == PenDownMode.draw {
            self.drawOperationCollector.addOp(
                op: Point(point: point, timestamp: timestamp), device: self.device
            )
        } else if self.mode == PenDownMode.pan {
            self.drawOperationCollector.addOp(
                op: Pan(point: point, timestamp: timestamp), device: self.device
            )
        } else if self.mode == PenDownMode.portal {
            self.drawOperationCollector.addOp(
                op: Portal(point: point, timestamp: timestamp, url: ""), device: self.device
            )
        } else {
            print("invalid mode: \(self.mode)")
        }

        self.renderer.endTimestamp = timestamp
//        self.renderer.draw(in: self.mtkView)
        self.mtkView.setNeedsDisplay()
    }

    override open func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
//        self.renderer.triggerProgrammaticCapture()
        guard self.recording else { return }

        let timestamp = getCurrentTimestamp()

        self.drawOperationCollector.addOp(op: PenUp(timestamp: timestamp), device: self.device)
        self.drawOperationCollector.commitProvisionalOps()

        self.renderer.endTimestamp = timestamp
//        self.renderer.draw(in: self.mtkView)
        self.mtkView.setNeedsDisplay()
    }

    override open func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        self.drawOperationCollector.cancelProvisionalOps()
        guard self.recording else { return }

        let timestamp = getCurrentTimestamp()
        self.renderer.endTimestamp = timestamp
//        self.renderer.draw(in: self.mtkView)
        self.mtkView.setNeedsDisplay()
    }

    // MARK: delegate methods

    func setColor(color: UIColor) {
        self.selectedColor = [
            Float(color.cgColor.components![0]),
            Float(color.cgColor.components![1]),
            Float(color.cgColor.components![2]),
            Float(color.cgColor.components![3]),
        ]
    }

    func startExport(filename: String) {
        let screenScale = UIScreen.main.scale
        let outputSize = CGSize(width: self.view.frame.width * screenScale, height: self.view.frame.height * screenScale)

        self.toolbar.documentVC.exportButton.isEnabled = false
        self.toolbar.documentVC.exportProgressIndicator.isHidden = false

        DispatchQueue.global().async {
            self.actuallyDoExport(filename, outputSize)
        }
    }

    func actuallyDoExport(_ filename: String, _ outputSize: CGSize) {
        let outputUrl = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("m4v")

        FileManager.default.removePossibleItem(at: outputUrl)

        let videoRecorder = MetalVideoRecorder(outputURL: outputUrl, size: outputSize)!

        let (startIndex, endIndex) = self.drawOperationCollector.getTimestampIndices(startPosition: self.startPosition, endPosition: self.endPosition)
        var timestampIterator = self.drawOperationCollector.getTimestampIterator(startIndex: startIndex, endIndex: endIndex)

        let firstPlaybackTimestamp = self.drawOperationCollector.timestamps[startIndex]
        let firstTimestamp = self.drawOperationCollector.timestamps[0]
        let timeOffset = firstPlaybackTimestamp - firstTimestamp

        videoRecorder.startRecording(firstTimestamp)

        self.playingState.lastIndexRead = calcBufferOffset(timeOffset: timeOffset)

        let frameCount: Float = Float(self.drawOperationCollector.timestamps.count)
        var framesRendered = 0

        func renderNext() {
            let (currentTime, nextTime) = timestampIterator.next()!

            if nextTime == -1 {
                self.playingState.running = false
                return
            }

            self.renderer.renderOffline(firstTimestamp: firstPlaybackTimestamp, endTimestamp: currentTime, videoRecorder: videoRecorder)

            for op in self.drawOperationCollector.opList {
                if op.type != .audioClip || op.timestamp != currentTime { continue }
                let audioClip = op as! AudioClip
                let samples = createAudio(sampleBytes: audioClip.audioSamples, startFrm: audioClip.timestamp, nFrames: audioClip.audioSamples.count / 2, sampleRate: SAMPLE_RATE, numChannels: UInt32(CHANNEL_COUNT))
                videoRecorder.writeAudio(samples: samples!)
            }

            DispatchQueue.main.async {
                self.toolbar.documentVC.exportProgressIndicator.progress = Float(framesRendered) / frameCount
                framesRendered += 1
            }
        }
        self.playingState.running = true

        while self.playingState.running {
            renderNext()
        }

        videoRecorder.endRecording {
            DispatchQueue.main.async {
                self.toolbar.documentVC.exportButton.isEnabled = true
                self.toolbar.documentVC.exportProgressIndicator.isHidden = true
                self.toolbar.documentVC.exportProgressIndicator.progress = 0
            }
        }

        DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputUrl) }) { _, _ in
            }
        }
    }

    public func startPlaying() {
        if self.playing { return }

        self.playing = true
        self.playingState.audioData = self.drawOperationCollector.audioData
        self.playingState.lastIndexRead = 0
        self.playback(runNumber: self.runNumber)
        self.runNumber += 1
    }

    public func stopPlaying() {
        guard self.nextRenderTimer != nil else {
            self.playing = false
            return
        }
        CFRunLoopTimerInvalidate(self.nextRenderTimer)
        check(AudioQueueStop(self.queue!, true))
        check(AudioQueueDispose(self.queue!, true))
        self.playing = false
    }

    public func startRecording() {
        self.drawOperationCollector.addOp(op: Viewport(bounds: [Float(self.view.frame.width), Float(self.view.frame.height)], timestamp: getCurrentTimestamp()), device: self.device)

        self.recording = true
        self.recordingThread = Thread(target: self, selector: #selector(self.recording(thread:)), object: nil)
        self.recordingThread.start()
    }

    public func stopRecording() {
        self.recording = false
        self.recordingThread.cancel()
    }

    public func setPenDownMode(mode: PenDownMode) {
        self.mode = mode
    }

    func save(filename: String) {
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                self.toolbar.documentVC.saveIndicator.startAnimating()
                self.toolbar.documentVC.saveButton.isEnabled = false
            }
            self.drawOperationCollector.serialize(filename: filename)
            DispatchQueue.main.async {
                self.toolbar.documentVC.saveIndicator.stopAnimating()
                self.toolbar.documentVC.saveButton.isEnabled = true
            }
        }
    }

    func restore(filename: String) {
        self.toolbar.documentVC.restoreButton.isEnabled = false
        self.toolbar.documentVC.restoreProgressIndicator.isHidden = false
        DispatchQueue.global().async {
            func progressCallback(todoCount: Int, todo: Int) {
                let progress = Float(todoCount) / Float(todo)

                DispatchQueue.main.async {
                    self.toolbar.documentVC.restoreProgressIndicator.progress = progress
                }
            }
            self.drawOperationCollector.deserialize(filename: filename, device: self.device, progressCallback)
            DispatchQueue.main.async {
                self.toolbar.documentVC.restoreButton.isEnabled = true
                self.toolbar.documentVC.restoreProgressIndicator.isHidden = true
                self.toolbar.documentVC.restoreProgressIndicator.progress = 0
            }
        }
    }

    func clear() {
        self.drawOperationCollector.clear()
        let timestamp = getCurrentTimestamp()
        self.renderer.endTimestamp = timestamp
        self.renderer.draw(in: self.mtkView)
    }

    public func setLineWidth(_ lineWidth: Float) {
        self.lineWidth = lineWidth
    }

    func setPlaybackPosition(_ playbackPosition: Float) {
        let wasPlaying = self.playing
        if self.playing {
            self.stopPlaying()
        }
        if self.drawOperationCollector.timestamps.count == 0 { return }

        self.renderer.endTimestamp = self.drawOperationCollector.getTimestamp(position: Double(playbackPosition))
        self.renderer.draw(in: self.mtkView)

        self.startPosition = Double(playbackPosition)
        self.endPosition = 1.0
        if wasPlaying {
            self.startPlaying()
        }
    }

    func getPlaybackTimestamp() -> Double {
        self.drawOperationCollector.getTimestamp(position: self.startPosition)
    }
}
