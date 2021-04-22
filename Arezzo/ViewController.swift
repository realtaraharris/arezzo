//
//  ViewController.swift
//  Arezzo
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import AudioToolbox
import Foundation
import Photos
import QuartzCore
import UIKit

@available(iOS 14.0, *)
@available(macCatalyst 14.0, *)
class ViewController: UIViewController, ToolbarDelegate {
    var device: MTLDevice = MTLCreateSystemDefaultDevice()!
    var metalLayer: CAMetalLayer = CAMetalLayer()
    var segmentVertexBuffer: MTLBuffer!
    var segmentIndexBuffer: MTLBuffer!
    var capVertexBuffer: MTLBuffer!
    var capIndexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var commandQueue: MTLCommandQueue!
    var segmentRenderPipelineState: MTLRenderPipelineState!
    var capRenderPipelineState: MTLRenderPipelineState!
    var timer: CADisplayLink!
    var nextRenderTimer: CFRunLoopTimer?
    var width: CGFloat = 0.0
    var height: CGFloat = 0.0
    var renderedShapes: [RenderedShape] = []
    public lazy var allowedTouchTypes: [TouchType] = [.finger, .pencil]
    var queue: AudioQueueRef?

    let toolbar: Toolbar = Toolbar()
    let capEdges = 21
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

        self.metalLayer.device = self.device
        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.framebufferOnly = false
        self.metalLayer.frame = view.layer.frame
        let screenScale = UIScreen.main.scale
        self.metalLayer.drawableSize = CGSize(width: view.frame.width * screenScale, height: view.frame.height * screenScale)
        view.layer.addSublayer(self.metalLayer)

        self.setupRender()

        self.view.backgroundColor = .black // without this, event handlers don't fire, not sure why yet

        self.toolbar.recordingVC.delegate = self
        self.toolbar.playbackVC.delegate = self
        self.toolbar.editingVC.delegate = self
        self.toolbar.colorPaletteVC.delegate = self
        self.toolbar.documentVC.delegate = self

        view.addSubview(self.toolbar.view) // add this last so that it appears on top of the metal layer
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

        self.render(endTimestamp: timestamp)
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.recording, let touch = touches.first else { return }

        guard self.allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }

        let timestamp = getCurrentTimestamp()

        let inputPoint = touch.location(in: view)
        let point = [Float(inputPoint.x), Float(inputPoint.y)]
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

        self.render(endTimestamp: timestamp)
    }

    override open func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
//        triggerProgrammaticCapture()
        guard self.recording else { return }

        let timestamp = getCurrentTimestamp()

        self.drawOperationCollector.addOp(op: PenUp(timestamp: timestamp), device: self.device)
        self.drawOperationCollector.commitProvisionalOps()

        self.render(endTimestamp: timestamp)
    }

    override open func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        self.drawOperationCollector.cancelProvisionalOps()
        guard self.recording else { return }

        let timestamp = getCurrentTimestamp()
        self.render(endTimestamp: timestamp)
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

            self.renderOffline(firstTimestamp: firstPlaybackTimestamp, endTimestamp: currentTime, videoRecorder: videoRecorder)

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
        self.render(endTimestamp: timestamp)
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
        self.render(endTimestamp: self.drawOperationCollector.getTimestamp(position: Double(playbackPosition)))
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
