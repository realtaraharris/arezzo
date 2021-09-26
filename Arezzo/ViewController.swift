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
    var playbackTerminationId: UInt64 = 0
    var totalPan: [Float] = [0, 0]
    var lastPan: [Float] = [0, 0]
    var isPanning = false
    var panStartedInPortal = false

    var recordingIndex: RecordingIndex = RecordingIndex()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black // the input event handlers don't fire without this, but I don't know why

        self.renderer = Renderer(frame: view.layer.frame, scale: UIScreen.main.scale)
        view.layer.addSublayer(self.renderer.metalLayer)

        self.toolbar.delegate = self
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

    func screenSpaceToMetalSpace(_ position: [Float]) -> [Float] {
        let width: Float = Float(self.view.frame.width)
        let height: Float = Float(self.view.frame.height)
        let inverseViewSize = [1.0 / width, 1.0 / height]
        let clipX = (2.0 * position[0] * inverseViewSize[0]) - 1.0
        let clipY = (2.0 * -position[1] * inverseViewSize[1]) + 1.0
        return [clipX, clipY]
    }

    func getTouchLocation(_ touch: UITouch) -> [Float] {
        let inputPoint = touch.location(in: view)
        return self.screenSpaceToMetalSpace([Float(inputPoint.x), Float(inputPoint.y)])
    }

    func getTouchLocationWithPan(_ touch: UITouch) -> [Float] {
        let inputPoint = touch.location(in: view)
        let metalPoint = self.screenSpaceToMetalSpace([Float(inputPoint.x), Float(inputPoint.y)])
        return [metalPoint[0] - self.totalPan[0], metalPoint[1] - self.totalPan[1]]
    }

    override open func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.isRecording, let touch = touches.first else { return }
        guard self.allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }

        let inputPoint = self.getTouchLocationWithPan(touch)

        let portalRect = self.checkPortalRects(CGPoint(x: CGFloat(inputPoint[0]), y: CGFloat(inputPoint[1])))
        if portalRect != nil {
            let pannedRect = portalRect!.rect.offsetBy(dx: CGFloat(self.totalPan[0]), dy: CGFloat(self.totalPan[1]))
            self.portalControls.view.frame = self.translateRect(pannedRect)
            self.portalControls.view.isHidden = false
            self.portalControls.targetName = portalRect!.name
            self.panStartedInPortal = true
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
                                                                   portalName: name),
                                                       position: PointInTime(x: 0, y: 0, t: timestamp))
            self.recordingIndex.currentRecording.addOp(
                op: Point(point: inputPoint, timestamp: timestamp),
                position: PointInTime(x: inputPoint[0], y: inputPoint[1], t: timestamp)
            )
        } else if self.mode == PenDownMode.pan {
            self.recordingIndex.currentRecording.addOp(op: PenDown(color: self.selectedColor,
                                                                   lineWidth: self.lineWidth,
                                                                   timestamp: timestamp,
                                                                   mode: self.mode,
                                                                   portalName: ""),
                                                       position: PointInTime(x: 0, y: 0, t: timestamp))
            self.lastPan = self.getTouchLocation(touch)
            self.isPanning = true

            self.recordingIndex.currentRecording.addOp(
                op: Pan(point: self.totalPan, timestamp: timestamp),
                position: PointInTime(x: 0, y: 0, t: timestamp)
            )
        } else {
            self.recordingIndex.currentRecording.addOp(op: PenDown(color: self.selectedColor,
                                                                   lineWidth: self.lineWidth,
                                                                   timestamp: timestamp,
                                                                   mode: self.mode,
                                                                   portalName: ""),
                                                       position: PointInTime(x: 0, y: 0, t: timestamp))
            self.recordingIndex.currentRecording.addOp(
                op: Point(point: inputPoint, timestamp: timestamp),
                position: PointInTime(x: inputPoint[0], y: inputPoint[1], t: timestamp)
            )
        }

        self.renderer.portalRects = []
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: timestamp)
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo
    }

    func translateRect(_ rect: CGRect) -> CGRect {
        let scale: CGFloat = UIScreen.main.scale
        let width: CGFloat = self.view.frame.width
        let height: CGFloat = self.view.frame.height
        return CGRect(
            x: ((rect.minX + 1.0) / scale) * width,
            y: ((1.0 - rect.maxY) / scale) * height,
            width: rect.width * width / scale,
            height: rect.height * height / scale
        )
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard self.isRecording, let touch = touches.first else { return }
        guard self.allowedTouchTypes.flatMap({ $0.uiTouchTypes }).contains(touch.type) else { return }

        let inputPoint = self.getTouchLocationWithPan(touch)

        let portalRect = self.checkPortalRects(CGPoint(x: CGFloat(inputPoint[0]), y: CGFloat(inputPoint[1])))
        if portalRect != nil, !self.isPanning {
            let pannedRect = portalRect!.rect.offsetBy(dx: CGFloat(self.totalPan[0]), dy: CGFloat(self.totalPan[1]))
            self.portalControls.view.frame = self.translateRect(pannedRect)
            self.portalControls.view.isHidden = false
            self.portalControls.targetName = portalRect!.name
            self.portalControls.view.setNeedsDisplay(portalRect!.rect)
            return
        }

        if self.panStartedInPortal { return }

        let timestamp = CFAbsoluteTimeGetCurrent()

        if self.mode == PenDownMode.draw {
            self.recordingIndex.currentRecording.addOp(
                op: Point(point: inputPoint, timestamp: timestamp),
                position: PointInTime(x: inputPoint[0], y: inputPoint[1], t: timestamp)
            )
        } else if self.mode == PenDownMode.pan {
            let panTouch = self.getTouchLocation(touch)
            let tmp = [
                self.totalPan[0] + panTouch[0] - self.lastPan[0],
                self.totalPan[1] + panTouch[1] - self.lastPan[1],
            ]
            self.recordingIndex.currentRecording.addOp(
                op: Pan(point: tmp, timestamp: timestamp),
                position: PointInTime(x: 0, y: 0, t: timestamp)
            )
        } else if self.mode == PenDownMode.portal {
            self.recordingIndex.currentRecording.addOp(
                op: Portal(point: inputPoint, timestamp: timestamp),
                position: PointInTime(x: inputPoint[0], y: inputPoint[1], t: timestamp)
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

        if self.panStartedInPortal {
            self.panStartedInPortal = false
            return
        }

        let inputPoint = self.getTouchLocationWithPan(touch)
        let portalRect = self.checkPortalRects(CGPoint(x: CGFloat(inputPoint[0]), y: CGFloat(inputPoint[1])))
        if portalRect != nil {
            let pannedRect = portalRect!.rect.offsetBy(dx: CGFloat(self.totalPan[0]), dy: CGFloat(self.totalPan[1]))
            self.portalControls.view.frame = self.translateRect(pannedRect)
            self.portalControls.view.setNeedsDisplay(portalRect!.rect)
            return
        }

        let timestamp = CFAbsoluteTimeGetCurrent()

        if self.mode == PenDownMode.pan {
            let panTouch = self.getTouchLocation(touch)
            let tmp = [
                self.totalPan[0] + panTouch[0] - self.lastPan[0],
                self.totalPan[1] + panTouch[1] - self.lastPan[1],
            ]
            self.recordingIndex.currentRecording.addOp(
                op: Pan(point: tmp, timestamp: timestamp),
                position: PointInTime(x: tmp[0], y: tmp[1], t: timestamp)
            )
            self.totalPan = tmp
            self.isPanning = false
        }

        self.recordingIndex.currentRecording.addOp(op: PenUp(timestamp: timestamp),
                                                   position: PointInTime(x: 0, y: 0, t: timestamp))
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

        self.panStartedInPortal = false

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
                                        firstTimestamp: firstPlaybackTimestamp, endTimestamp: currentTime, videoRecorder: videoRecorder, size: CGSize(width: CGFloat(self.view.frame.width), height: CGFloat(self.view.frame.height)))

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

        if self.queue != nil {
            check(AudioQueueStop(self.queue!, true))
            check(AudioQueueDispose(self.queue!, true))
        }
        self.isPlaying = false

        self.playbackTerminationId += 1 // causes playback timers with the previous playId to terminate
    }

    func setPlaybackPosition(_ playbackPosition: Float) {
        if self.recordingIndex.currentRecording.opList.count == 0 { return }
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
    }

    func getPlaybackPosition() -> Double {
        self.startPosition
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
        if self.recordingIndex.currentRecording.opList.count == 0 { return }

        var audioOpIndexes: [Int] = []
        // no currentAudioOpIndex because it's tracked in self.playingState.currentAudioOpIndex

        var audioControlOpIndexes: [Int] = []
        var currentAudioControlOpIndex = 0

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
        let terminationId = self.playbackTerminationId

        var updateScreenTimer: CFRunLoopTimer?
        var updateProgressTimer: CFRunLoopTimer?
        var updateAudioTimer: CFRunLoopTimer?

        for (index, op) in self.recordingIndex.currentRecording.opList.enumerated() {
            if op.timestamp < startTime { continue }
            if op.type == .audioStart {
                audioControlOpIndexes.append(index)
            } else if op.type == .audioClip {
                audioOpIndexes.append(index)
            } else if op.type == .audioStop {
                audioControlOpIndexes.append(index)
            } else {
                drawOpIndexes.append(index)
            }
        }

        func updateScreen(_: CFRunLoopTimer?) {
            if !self.playingState.running || terminationId < self.playbackTerminationId || currentDrawOpIndex >= drawOpIndexes.count { return }

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

            updateScreenTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, updateScreen)
            RunLoop.current.add(updateScreenTimer!, forMode: .common)
        }

        func updateProgress(_: CFRunLoopTimer?) {
            if !self.playingState.running || terminationId < self.playbackTerminationId { return }
            self.toolbar.playbackVC.playbackSlider.setValueEx(value: Float(Double(progressStep) / Double(steps)))
            progressStep += 1

            if progressStep > steps {
                self.toolbar.playbackVC.readyToPlay()
                return
            }

            let fireDate = playbackStart + (progressUpdateInterval * Double(progressStep - startProgressStep))
            updateProgressTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, updateProgress)
            RunLoop.current.add(updateProgressTimer!, forMode: .common)
        }

        check(AudioQueueNewOutput(&audioFormat, outputCallback, &self.playingState, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &self.queue))

        self.playingState.currentRecording = self.recordingIndex.currentRecording
        self.playingState.currentAudioOpIndex = 0
        self.playingState.audioOpIndexes = audioOpIndexes

        var buffers: [AudioQueueBufferRef?] = Array<AudioQueueBufferRef?>.init(repeating: nil, count: BUFFER_COUNT)
        self.playingState.running = true

        func updateAudio(_: CFRunLoopTimer?) {
            if !self.playingState.running || terminationId < self.playbackTerminationId { return }

            let currentOpIndex = audioControlOpIndexes[currentAudioControlOpIndex]
            let currentOp = self.recordingIndex.currentRecording.opList[currentOpIndex]

            if currentOp.type == .audioStart {
                if currentAudioControlOpIndex == 0 {
                    for i in 0 ..< BUFFER_COUNT {
                        check(AudioQueueAllocateBuffer(self.queue!, UInt32(bufferByteSize), &buffers[i]))
                        outputCallback(inUserData: &self.playingState, inAQ: self.queue!, inBuffer: buffers[i]!)
                    }

                    AudioQueuePrime(self.queue!, 0, nil)
                }
                check(AudioQueueStart(self.queue!, nil))
            } else if currentOp.type == .audioStop {
                AudioQueuePause(self.queue!)
            }

            currentAudioControlOpIndex += 1

            if currentAudioControlOpIndex >= audioControlOpIndexes.count { return }

            let nextOpIndex = audioControlOpIndexes[currentAudioControlOpIndex]
            let nextOp = self.recordingIndex.currentRecording.opList[nextOpIndex]
            let fireDate = playbackStart + nextOp.timestamp - startTime

            updateAudioTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, updateAudio)
            RunLoop.current.add(updateAudioTimer!, forMode: .common)
        }

        let drawOpTimestamp = self.recordingIndex.currentRecording.opList[drawOpIndexes[0]].timestamp

        if audioControlOpIndexes.count > 0 {
            let audioOpTimestamp = self.recordingIndex.currentRecording.opList[audioControlOpIndexes[0]].timestamp
            let audioStart = playbackStart + audioOpTimestamp - drawOpTimestamp
            updateAudioTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, audioStart, 0, 0, 0, updateAudio)
            RunLoop.current.add(updateAudioTimer!, forMode: .common)
        }

        updateScreenTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, playbackStart, 0, 0, 0, updateScreen)
        RunLoop.current.add(updateScreenTimer!, forMode: .common)

        updateProgressTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, playbackStart, 0, 0, 0, updateProgress)
        RunLoop.current.add(updateProgressTimer!, forMode: .common)
    }

    func getPlaybackTimestamp() -> Double {
        self.recordingIndex.currentRecording.getTimestamp(position: self.startPosition)
    }

    func startRecording() {
        let timestamp = CFAbsoluteTimeGetCurrent()
        self.recordingIndex.currentRecording.addOp(op: Viewport(bounds: [Float(self.view.frame.width), Float(self.view.frame.height)], timestamp: timestamp),
                                                   position: PointInTime(x: 0, y: 0, t: timestamp))

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

        let timestamp = CFAbsoluteTimeGetCurrent()
        self.recordingIndex.currentRecording.addOp(
            op: AudioStart(timestamp: timestamp),
            position: PointInTime(x: 0, y: 0, t: timestamp)
        )
        check(AudioQueueStart(self.queue!, nil))
    }

    func stopAudioRecording() {
        if !self.recordingState.running { return }

        let timestamp = CFAbsoluteTimeGetCurrent()
        self.recordingIndex.currentRecording.addOp(
            op: AudioStop(timestamp: timestamp),
            position: PointInTime(x: 0, y: 0, t: timestamp)
        )

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
            self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                         name: self.recordingIndex.currentRecording.name,
                                         endTimestamp: CFAbsoluteTimeGetCurrent())
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

    func updateTotalPan() {
        // find the last pan op
        let lastPanOp = self.recordingIndex.currentRecording.opList.last { (op: DrawOperation) -> Bool in op.type == .pan }

        // update the totalPan vector
        if lastPanOp != nil {
            let op = lastPanOp as! Pan
            self.totalPan = [op.point[0], op.point[1]]
        } else {
            self.totalPan = [0, 0]
        }
    }

    func enterPortal(destination: String) {
        self.recordingIndex.pushRecording(name: destination)
        self.renderer.portalRects = []
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: CFAbsoluteTimeGetCurrent())
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo

        self.updateTotalPan()
        self.panStartedInPortal = false

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

        self.updateTotalPan()
        self.panStartedInPortal = false
    }

    func undo() {
        let timestamp = CFAbsoluteTimeGetCurrent()
        self.recordingIndex.currentRecording.addOp(op: Undo(timestamp: timestamp),
                                                   position: PointInTime(x: 0, y: 0, t: timestamp))
        self.renderer.renderToScreen(recordingIndex: self.recordingIndex,
                                     name: self.recordingIndex.currentRecording.name,
                                     endTimestamp: CFAbsoluteTimeGetCurrent())
        self.toolbar.recordingVC.undoButton.isEnabled = self.renderer.canUndo
        self.toolbar.recordingVC.redoButton.isEnabled = self.renderer.canRedo
    }

    func redo() {
        let timestamp = CFAbsoluteTimeGetCurrent()
        self.recordingIndex.currentRecording.addOp(op: Redo(timestamp: timestamp),
                                                   position: PointInTime(x: 0, y: 0, t: timestamp))
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
