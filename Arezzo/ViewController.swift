//
//  ViewController.swift
//  Arezzo
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import Foundation
import Photos
import UIKit

class ViewController: UIViewController, ToolbarDelegate {
    var renderer: Renderer!
    var timer: CADisplayLink!
    var updateScreenTimer: CFRunLoopTimer?
    var updateProgressTimer: CFRunLoopTimer?
    var allowedTouchTypes: [TouchType] = [.finger, .pencil]
    var queue: AudioQueueRef?

    let toolbar: Toolbar = Toolbar()
    let portalControls = PortalViewController()

    var selectedColor: [Float] = [1.0, 0.0, 0.0, 1.0]
    var lineWidth: Float = DEFAULT_LINE_WIDTH
    var mode: PenDownMode = PenDownMode.draw
    var isPlaying: Bool = false
    var isRecording: Bool = false
    var startPosition: Double = 0.0
    var playingState: PlayingState = PlayingState(running: false)
    var recordingState: RecordingState = RecordingState(running: false, recording: nil)
    var muted: Bool = true

    var recordingIndex: RecordingIndex = RecordingIndex()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black // the input event handlers don't fire without this, but I don't know why

        self.renderer = Renderer(frame: view.layer.frame, scale: UIScreen.main.scale)
        view.layer.addSublayer(self.renderer.metalLayer)

        self.toolbar.recordingVC.delegate = self
        self.toolbar.playbackVC.delegate = self
        self.toolbar.editingVC.delegate = self
        self.toolbar.colorPaletteVC.delegate = self
        self.toolbar.documentVC.delegate = self
        self.portalControls.delegate = self

        self.portalControls.view.isHidden = true
        self.view.addSubview(self.portalControls.view)
        addChild(self.portalControls)
        self.portalControls.didMove(toParent: self)

        view.addSubview(self.toolbar.view) // add this last so that it appears on top of the metal layer
    }

    func checkPortalRects(_ inputPoint: CGPoint) -> PortalRect? {
        for portalRect in self.renderer.portalRects {
            if portalRect.rect.contains(inputPoint) { return portalRect }
        }
        return nil
    }

    // MARK: - input event handlers

    override open func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.isRecording, let touch = touches.first else { return }
        guard self.allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }

        let inputPoint = touch.location(in: view)

        let portalRect = self.checkPortalRects(inputPoint)
        if portalRect != nil {
            self.portalControls.view.frame = portalRect!.rect
            self.portalControls.view.isHidden = false
            self.portalControls.targetName = portalRect!.name
            return
        } else {
            self.portalControls.view.isHidden = true
        }

        let timestamp = CFAbsoluteTimeGetCurrent()

        self.recordingIndex.currentRecording.beginProvisionalOps()

        if self.mode == PenDownMode.portal {
            let name = UUID().uuidString
            self.recordingIndex.addRecording(name: name)
            self.recordingIndex.currentRecording.addOp(op: PenDown(color: self.selectedColor,
                                                                   lineWidth: self.lineWidth,
                                                                   timestamp: timestamp,
                                                                   mode: self.mode,
                                                                   portalName: name))
        } else {
            self.recordingIndex.currentRecording.addOp(op: PenDown(color: self.selectedColor,
                                                                   lineWidth: self.lineWidth,
                                                                   timestamp: timestamp,
                                                                   mode: self.mode,
                                                                   portalName: ""))
        }

        self.renderer.portalRects = []
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: timestamp)
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.isRecording, let touch = touches.first else { return }
        guard self.allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }

        let inputPoint = touch.location(in: view)

        let portalRect = self.checkPortalRects(inputPoint)
        if portalRect != nil {
            self.portalControls.view.frame = portalRect!.rect
            self.portalControls.view.isHidden = false
            self.portalControls.targetName = portalRect!.name
            self.portalControls.view.setNeedsDisplay(portalRect!.rect)
            return
        }

        let timestamp = CFAbsoluteTimeGetCurrent()

        let point = [Float(inputPoint.x), Float(inputPoint.y)]
        if self.mode == PenDownMode.draw {
            self.recordingIndex.currentRecording.addOp(
                op: Point(point: point, timestamp: timestamp)
            )
        } else if self.mode == PenDownMode.pan {
            self.recordingIndex.currentRecording.addOp(
                op: Pan(point: point, timestamp: timestamp)
            )
        } else if self.mode == PenDownMode.portal {
            self.recordingIndex.currentRecording.addOp(
                op: Portal(point: point, timestamp: timestamp)
            )
        } else {
            print("invalid mode: \(self.mode)")
        }

        self.renderer.portalRects = []
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: timestamp)
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.isRecording, let touch = touches.first else { return }

        let inputPoint = touch.location(in: view)
        let portalRect = self.checkPortalRects(inputPoint)
        if portalRect != nil {
            self.portalControls.view.center.x = portalRect!.rect.midX
            self.portalControls.view.center.y = portalRect!.rect.midY
            self.portalControls.view.setNeedsDisplay(portalRect!.rect)
            return
        }

        let timestamp = CFAbsoluteTimeGetCurrent()

        self.recordingIndex.currentRecording.addOp(op: PenUp(timestamp: timestamp))
        self.recordingIndex.currentRecording.commitProvisionalOps()

        self.renderer.portalRects = []
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: timestamp)
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo

        if self.mode == .portal {
            self.toolbar.recordingVC.enterDrawMode()
        }
    }

    override open func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        self.recordingIndex.currentRecording.cancelProvisionalOps()
        guard self.isRecording else { return }

        let timestamp = CFAbsoluteTimeGetCurrent()
        self.renderer.portalRects = []
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: timestamp)
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo
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
            self.exportToVideo(filename, outputSize)
        }
    }

    func exportToVideo(_ filename: String, _ outputSize: CGSize) {
        let outputUrl = getDocumentsDirectory().appendingPathComponent(filename).appendingPathExtension("m4v")

        FileManager.default.removePossibleItem(at: outputUrl)

        let videoRecorder = MetalVideoRecorder(outputURL: outputUrl, size: outputSize)!

        let (startIndex, endIndex) = self.recordingIndex.currentRecording.getTimestampIndices(startPosition: self.startPosition, endPosition: 1.0)
        var timestampIterator = self.recordingIndex.currentRecording.getTimestampIterator(startIndex: startIndex, endIndex: endIndex)

        let firstPlaybackTimestamp = self.recordingIndex.currentRecording.timestamps[startIndex]
        let firstTimestamp = self.recordingIndex.currentRecording.timestamps[0]
//        let timeOffset = firstPlaybackTimestamp - firstTimestamp

        videoRecorder.startRecording(firstTimestamp)

//        self.playingState.lastIndexRead = calcBufferOffset(timeOffset: timeOffset)

        let frameCount: Float = Float(self.recordingIndex.currentRecording.timestamps.count)
        var framesRendered = 0

        func renderNext() {
            let (currentTime, nextTime) = timestampIterator.next()!

            if nextTime == -1 {
                self.playingState.running = false
                return
            }

            self.renderer.renderToVideo(recordingIndex: self.recordingIndex,
                                        name: self.recordingIndex.currentRecording.name,
                                        firstTimestamp: firstPlaybackTimestamp, endTimestamp: currentTime, videoRecorder: videoRecorder)

            for op in self.recordingIndex.currentRecording.opList {
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

    // MARK: playback

    func startPlaying() {
        if self.isPlaying { return }

        self.isPlaying = true
        self.playback()
    }

    func stopPlaying() {
        self.playingState.running = false

        CFRunLoopTimerInvalidate(self.updateScreenTimer)
        CFRunLoopTimerInvalidate(self.updateProgressTimer)
        check(AudioQueueStop(self.queue!, true))
        check(AudioQueueDispose(self.queue!, true))
        self.isPlaying = false
    }

    func setPlaybackPosition(_ playbackPosition: Float) {
        if self.recordingIndex.currentRecording.opList.count == 0 { return }
//        let wasPlaying = self.isPlaying
        if self.isPlaying {
            self.stopPlaying()
        }
        self.renderer.portalRects = []
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: self.recordingIndex.currentRecording.getTimestamp(position: Double(playbackPosition)))
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo

        self.startPosition = Double(playbackPosition)
        // TODO: need to track timers and cancel them fully in order to do this. right now this results in buggy double playback!
//        if wasPlaying {
//            self.startPlaying()
//        }
    }

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

    func playback() {
        var audioOpIndexes: [Int] = []
        var drawOpIndexes: [Int] = []
        var currentDrawOpIndex = 0
        let firstTime = self.recordingIndex.currentRecording.opList.first!.timestamp
        let lastTime = self.recordingIndex.currentRecording.opList.last!.timestamp
        let duration = lastTime - firstTime
        let startTime = self.recordingIndex.currentRecording.getTimestamp(position: self.startPosition)
        let playbackStart = CFAbsoluteTimeGetCurrent()
        let steps: Int = Int(self.toolbar.playbackVC.playbackSlider.frame.width)
        let progressUpdateInterval: Double = duration / Double(steps)
        var progressStep: Int = Int(self.startPosition * Double(steps))
        let startProgressStep: Int = progressStep

        for (index, op) in self.recordingIndex.currentRecording.opList.enumerated() {
            if op.timestamp < startTime { continue }
            if op.type == .audioClip {
                audioOpIndexes.append(index)
            } else {
                drawOpIndexes.append(index)
            }
        }

        self.playingState.currentRecording = self.recordingIndex.currentRecording
        self.playingState.currentAudioOpIndex = 0
        self.playingState.audioOpIndexes = audioOpIndexes
        self.playingState.running = true

        func updateScreen(_: CFRunLoopTimer?) {
            if !self.playingState.running { return }

            if currentDrawOpIndex == 0 {
                check(AudioQueueStart(self.queue!, nil))
            }

            if currentDrawOpIndex >= drawOpIndexes.count { return }

            let opIndex = drawOpIndexes[currentDrawOpIndex]
            let op = self.recordingIndex.currentRecording.opList[opIndex]

            self.renderer.portalRects = []
            self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                         name: self.recordingIndex.currentRecording.name,
                                         endTimestamp: op.timestamp)
            self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
            self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo

            currentDrawOpIndex += 1

            if currentDrawOpIndex >= drawOpIndexes.count { return }

            let nextOpIndex = drawOpIndexes[currentDrawOpIndex]
            let nextOp = self.recordingIndex.currentRecording.opList[nextOpIndex]
            let fireDate = playbackStart + nextOp.timestamp - startTime

            self.updateScreenTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, updateScreen)
            RunLoop.current.add(self.updateScreenTimer!, forMode: .common)
        }

        func updateProgress(_: CFRunLoopTimer?) {
            if !self.playingState.running { return }
            self.toolbar.playbackVC.playbackSlider.setValueEx(value: Float(Double(progressStep) / Double(steps)))
            progressStep += 1

            if progressStep > steps {
                self.toolbar.playbackVC.readyToPlay()
                return
            }

            let fireDate = playbackStart + (progressUpdateInterval * Double(progressStep - startProgressStep))
            self.updateProgressTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, updateProgress)
            RunLoop.current.add(self.updateProgressTimer!, forMode: .common)
        }

        check(AudioQueueNewOutput(&audioFormat, outputCallback, &self.playingState, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &self.queue))

        var buffers: [AudioQueueBufferRef?] = Array<AudioQueueBufferRef?>.init(repeating: nil, count: BUFFER_COUNT)
        for i in 0 ..< BUFFER_COUNT {
            check(AudioQueueAllocateBuffer(self.queue!, UInt32(bufferByteSize), &buffers[i]))
            outputCallback(inUserData: &self.playingState, inAQ: self.queue!, inBuffer: buffers[i]!)
        }
        AudioQueuePrime(self.queue!, 0, nil)

        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, playbackStart, 0, 0, 0, updateScreen)
        RunLoop.current.add(timer!, forMode: .common)

        let progressTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, playbackStart, 0, 0, 0, updateProgress)
        RunLoop.current.add(progressTimer!, forMode: .common)
    }

    func getPlaybackTimestamp() -> Double {
        self.recordingIndex.currentRecording.getTimestamp(position: self.startPosition)
    }

    func startRecording() {
        self.recordingIndex.currentRecording.addOp(op: Viewport(bounds: [Float(self.view.frame.width), Float(self.view.frame.height)], timestamp: CFAbsoluteTimeGetCurrent()))

        self.isRecording = true
        self.startAudioRecording()
    }

    func stopRecording() {
        self.isRecording = false
        self.stopAudioRecording()
    }

    // MARK: audio recording

    func startAudioRecording() {
        if self.muted { return }
        self.recordingState.recording = self.recordingIndex.currentRecording

        check(AudioQueueNewInput(&audioFormat, inputCallback, &self.recordingState, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &self.queue))

        var buffers: [AudioQueueBufferRef?] = Array<AudioQueueBufferRef?>.init(repeating: nil, count: BUFFER_COUNT)

        self.recordingState.running = true

        for i in 0 ..< BUFFER_COUNT {
            check(AudioQueueAllocateBuffer(self.queue!, UInt32(bufferByteSize), &buffers[i]))
            check(AudioQueueEnqueueBuffer(self.queue!, buffers[i]!, 0, nil))
        }

        check(AudioQueueStart(self.queue!, nil))
    }

    func stopAudioRecording() {
        if !self.recordingState.running { return }
        check(AudioQueueStop(self.queue!, true))
        check(AudioQueueDispose(self.queue!, true))
    }

    func setPenDownMode(mode: PenDownMode) {
        self.mode = mode
    }

    func save(filename: String) {
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                self.toolbar.documentVC.saveIndicator.startAnimating()
                self.toolbar.documentVC.saveButton.isEnabled = false
            }
            self.recordingIndex.save(filename: filename)
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
            self.recordingIndex.restore(filename: filename)
            DispatchQueue.main.async {
                self.toolbar.documentVC.restoreButton.isEnabled = true
                self.toolbar.documentVC.restoreProgressIndicator.isHidden = true
                self.toolbar.documentVC.restoreProgressIndicator.progress = 0
            }
        }
    }

    func clear() {
        self.recordingIndex.currentRecording.clear()
        let timestamp = CFAbsoluteTimeGetCurrent()
        self.renderer.portalRects = []
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: timestamp)
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo
    }

    func setLineWidth(_ lineWidth: Float) {
        self.lineWidth = lineWidth
    }

    func enterPortal(destination: String) {
        self.recordingIndex.pushRecording(name: destination)
        self.renderer.portalRects = []
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: CFAbsoluteTimeGetCurrent())
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo

        self.portalControls.view.isHidden = true
        self.portalControls.view.setNeedsDisplay()
    }

    func exitPortal() {
        self.recordingIndex.popRecording()
        self.renderer.portalRects = []
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: CFAbsoluteTimeGetCurrent())
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo
    }

    func undo() {
        self.recordingIndex.currentRecording.addOp(op: Undo(timestamp: CFAbsoluteTimeGetCurrent()))
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: CFAbsoluteTimeGetCurrent())
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo
    }

    func redo() {
        self.recordingIndex.currentRecording.addOp(op: Redo(timestamp: CFAbsoluteTimeGetCurrent()))
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: CFAbsoluteTimeGetCurrent())
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo
    }

    func recordAudio(_ muted: Bool) {
        self.muted = muted

        if self.muted, self.isRecording {
            self.stopAudioRecording()
        } else if !self.muted, self.isRecording {
            self.startRecording()
        }
        print("self.muted:", self.muted)
    }
}

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
