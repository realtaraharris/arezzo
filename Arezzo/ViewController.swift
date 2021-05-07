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
    var nextRenderTimer: CFRunLoopTimer?
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
    var endPosition: Double = 1.0
    var playingState: PlayingState = PlayingState(running: false, lastIndexRead: 0, audioData: [])
    var runNumber: Int = 0
    var currentRunNumber: Int = 0

    var recordingIndex: RecordingIndex = RecordingIndex()

    var recordingThread: Thread = Thread() // TODO: get rid of this

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

        self.renderer.renderToScreen(shapeList: self.recordingIndex.currentRecording.shapeList, endTimestamp: timestamp)
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

        self.renderer.renderToScreen(shapeList: self.recordingIndex.currentRecording.shapeList, endTimestamp: timestamp)
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

        self.renderer.renderToScreen(shapeList: self.recordingIndex.currentRecording.shapeList, endTimestamp: timestamp)
    }

    override open func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        self.recordingIndex.currentRecording.cancelProvisionalOps()
        guard self.isRecording else { return }

        let timestamp = CFAbsoluteTimeGetCurrent()
        self.renderer.renderToScreen(shapeList: self.recordingIndex.currentRecording.shapeList, endTimestamp: timestamp)
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

        let (startIndex, endIndex) = self.recordingIndex.currentRecording.getTimestampIndices(startPosition: self.startPosition, endPosition: self.endPosition)
        var timestampIterator = self.recordingIndex.currentRecording.getTimestampIterator(startIndex: startIndex, endIndex: endIndex)

        let firstPlaybackTimestamp = self.recordingIndex.currentRecording.timestamps[startIndex]
        let firstTimestamp = self.recordingIndex.currentRecording.timestamps[0]
        let timeOffset = firstPlaybackTimestamp - firstTimestamp

        videoRecorder.startRecording(firstTimestamp)

        self.playingState.lastIndexRead = calcBufferOffset(timeOffset: timeOffset)

        let frameCount: Float = Float(self.recordingIndex.currentRecording.timestamps.count)
        var framesRendered = 0

        func renderNext() {
            let (currentTime, nextTime) = timestampIterator.next()!

            if nextTime == -1 {
                self.playingState.running = false
                return
            }

            self.renderer.renderToVideo(shapeList: self.recordingIndex.currentRecording.shapeList, firstTimestamp: firstPlaybackTimestamp, endTimestamp: currentTime, videoRecorder: videoRecorder)

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

    func startPlaying() {
        if self.isPlaying { return }

        self.isPlaying = true
        self.playingState.audioData = self.recordingIndex.currentRecording.audioData
        self.playingState.lastIndexRead = 0
        self.playback(runNumber: self.runNumber)
        self.runNumber += 1
    }

    func stopPlaying() {
        guard self.nextRenderTimer != nil else {
            self.isPlaying = false
            return
        }
        CFRunLoopTimerInvalidate(self.nextRenderTimer)
        check(AudioQueueStop(self.queue!, true))
        check(AudioQueueDispose(self.queue!, true))
        self.isPlaying = false
    }

    func playback(runNumber: Int) {
        guard self.recordingIndex.currentRecording.timestamps.count > 0 else {
            return
        }

        check(AudioQueueNewOutput(&audioFormat, outputCallback, &self.playingState, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue, 0, &self.queue))

        var buffers: [AudioQueueBufferRef?] = Array<AudioQueueBufferRef?>.init(repeating: nil, count: BUFFER_COUNT)

        self.playingState.running = true

        for i in 0 ..< BUFFER_COUNT {
            check(AudioQueueAllocateBuffer(self.queue!, UInt32(bufferByteSize), &buffers[i]))
            outputCallback(inUserData: &self.playingState, inAQ: self.queue!, inBuffer: buffers[i]!)

            if !self.playingState.running {
                break
            }
        }

        let (startIndex, endIndex) = self.recordingIndex.currentRecording.getTimestampIndices(startPosition: self.startPosition, endPosition: self.endPosition)
        var timestampIterator = self.recordingIndex.currentRecording.getTimestampIterator(startIndex: startIndex, endIndex: endIndex)

        let recordedCursor = self.recordingIndex.currentRecording.timestamps[startIndex]
        let recordedStart = self.recordingIndex.currentRecording.timestamps[0]
        let timeOffset = recordedCursor - recordedStart

        self.playingState.lastIndexRead = calcBufferOffset(timeOffset: timeOffset)

        guard timestampIterator.count > 0 else { return }

        let timeStart = self.recordingIndex.currentRecording.timestamps[0]
        let timeEnd = self.recordingIndex.currentRecording.timestamps[self.recordingIndex.currentRecording.timestamps.count - 1]

        let timeDelta = timeEnd - timeStart

        let (firstTime, _) = timestampIterator.next()!
        let playbackStart = CFAbsoluteTimeGetCurrent()

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

        func renderNext(_: CFRunLoopTimer?) {
            let playbackCursor = CFAbsoluteTimeGetCurrent()
            let position: Float = Float((playbackCursor - playbackStart + recordedCursor - recordedStart) / timeDelta)

            self.toolbar.playbackVC.playbackSlider.setValueEx(value: position)

            if !self.isPlaying {
                return
            }
            let (currentTime, nextTime) = timestampIterator.next()!

            if nextTime == -1 {
                self.toolbar.playbackVC.playbackSlider.setValueEx(value: 1.0)
                self.playingState.running = false
                return
            }

            if runNumber < self.currentRunNumber { return }
            self.currentRunNumber = runNumber

            self.renderer.renderToScreen(shapeList: self.recordingIndex.currentRecording.shapeList, endTimestamp: currentTime)

            let fireDate = playbackStart + nextTime - firstTime

            self.nextRenderTimer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, renderNext)
            RunLoop.current.add(self.nextRenderTimer!, forMode: .common)
        }

        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, playbackStart, 0, 0, 0, renderNext)
        RunLoop.current.add(timer!, forMode: .common)

        check(AudioQueueStart(self.queue!, nil))

        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, BUFFER_DURATION, false)
    }

    func startRecording() {
        self.recordingIndex.currentRecording.addOp(op: Viewport(bounds: [Float(self.view.frame.width), Float(self.view.frame.height)], timestamp: CFAbsoluteTimeGetCurrent()))

        self.isRecording = true
        self.recordingThread = Thread(target: self, selector: #selector(self.recording(thread:)), object: nil)
        self.recordingThread.start()
    }

    func stopRecording() {
        self.isRecording = false
        self.recordingThread.cancel()
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
        self.renderer.renderToScreen(shapeList: self.recordingIndex.currentRecording.shapeList, endTimestamp: timestamp)
    }

    func setLineWidth(_ lineWidth: Float) {
        self.lineWidth = lineWidth
    }

    func setPlaybackPosition(_ playbackPosition: Float) {
        let wasPlaying = self.isPlaying
        if self.isPlaying {
            self.stopPlaying()
        }
        if self.recordingIndex.currentRecording.timestamps.count == 0 { return }
        self.renderer.renderToScreen(shapeList: self.recordingIndex.currentRecording.shapeList, endTimestamp: self.recordingIndex.currentRecording.getTimestamp(position: Double(playbackPosition)))
        self.startPosition = Double(playbackPosition)
        self.endPosition = 1.0
        if wasPlaying {
            self.startPlaying()
        }
    }

    func getPlaybackTimestamp() -> Double {
        self.recordingIndex.currentRecording.getTimestamp(position: self.startPosition)
    }

    func enterPortal(destination: String) {
        self.recordingIndex.pushRecording(name: destination)
        self.renderer.renderToScreen(shapeList: self.recordingIndex.currentRecording.shapeList, endTimestamp: CFAbsoluteTimeGetCurrent())
        self.portalControls.view.isHidden = true
        self.portalControls.view.setNeedsDisplay()
    }

    func exitPortal() {
        let pathStack = self.recordingIndex.pathStack

        for index in (1 ... pathStack.count).reversed() {
            if index > 1 {
                let source = pathStack[index - 1]
                let target = pathStack[index - 2]
                renderPortalPreview(source: source, target: target)
            }
        }

        self.recordingIndex.popRecording()
        self.renderer.renderToScreen(shapeList: self.recordingIndex.currentRecording.shapeList, endTimestamp: CFAbsoluteTimeGetCurrent())
    }

    func renderPortalPreview(source: String, target: String) {
        let sourceRecording = self.recordingIndex.getRecordingByUrl(name: source)!
        let destRecording = self.recordingIndex.getRecordingByUrl(name: target)!
        let destShape = self.findPortalShape(destRecording.shapeList, source)
        if destShape == nil { return }

        let boundingRect = destShape?.getBoundingRect(endTimestamp: CFAbsoluteTimeGetCurrent())!

        destShape!.setTexture(texture: self.renderer.renderToBitmap(shapeList: sourceRecording.shapeList, firstTimestamp: 0, endTimestamp: CFAbsoluteTimeGetCurrent(), size: CGSize(width: CGFloat(boundingRect![2]) * 2.0, height: CGFloat(boundingRect![3]) * 2.0)))
    }

    func findPortalShape(_ shapeList: [Shape], _ name: String) -> Shape? {
        guard let shapeIndex = shapeList.firstIndex(where: { $0.type == .portal && $0.name == name }) else {
            print("error - failed to find portal shape", name)
            return nil
        }

        return shapeList[shapeIndex]
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
