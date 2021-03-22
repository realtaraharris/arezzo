//
//  AudioDeviceFinder.swift
//  Arezzo
//
//  Created by Max Harris on 11/10/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import AudioToolbox
import CoreAudio
import Foundation

#if os(macOS)
    class AudioDevice {
        var AudioObjectID: AudioObjectID

        init(deviceID: AudioObjectID) {
            self.AudioObjectID = deviceID
        }

        var hasOutput: Bool {
            var address: AudioObjectPropertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyStreamConfiguration),
                mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
                mElement: 0
            )

            var propsize: UInt32 = UInt32(MemoryLayout<CFString?>.size)
            var result: OSStatus = AudioObjectGetPropertyDataSize(AudioObjectID, &address, 0, nil, &propsize)
            if result != 0 {
                return false
            }

            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(propsize))
            result = AudioObjectGetPropertyData(self.AudioObjectID, &address, 0, nil, &propsize, bufferList)
            if result != 0 {
                return false
            }

            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            for bufferNum in 0 ..< buffers.count {
                if buffers[bufferNum].mNumberChannels > 0 {
                    return true
                }
            }

            return false
        }

        var uid: String? {
            var address: AudioObjectPropertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceUID),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
            )

            var name: CFString?
            var propsize: UInt32 = UInt32(MemoryLayout<CFString?>.size)
            let result: OSStatus = AudioObjectGetPropertyData(AudioObjectID, &address, 0, nil, &propsize, &name)
            if result != 0 {
                return nil
            }

            return name as String?
        }

        var name: String? {
            var address: AudioObjectPropertyAddress = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceNameCFString),
                mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
                mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
            )

            var name: CFString?
            var propsize: UInt32 = UInt32(MemoryLayout<CFString?>.size)
            let result: OSStatus = AudioObjectGetPropertyData(AudioObjectID, &address, 0, nil, &propsize, &name)
            if result != 0 {
                return nil
            }

            return name as String?
        }
    }

    func findDevices() {
        var propsize: UInt32 = 0

        var address: AudioObjectPropertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster)
        )

        var result: OSStatus = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<AudioObjectPropertyAddress>.size), nil, &propsize)

        if result != 0 {
            print("Error \(result) from AudioObjectGetPropertyDataSize")
            return
        }

        let numDevices = Int(propsize / UInt32(MemoryLayout<AudioObjectID>.size))

        var devids = [AudioObjectID]()
        for _ in 0 ..< numDevices {
            devids.append(AudioObjectID())
        }

        result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, &devids)
        if result != 0 {
            print("Error \(result) from AudioObjectGetPropertyData")
            return
        }

        for i in 0 ..< numDevices {
            let audioDevice = AudioDevice(deviceID: devids[i])
            if audioDevice.hasOutput {
                if let name = audioDevice.name,
                    let uid = audioDevice.uid {
                    print("Found device \"\(name)\", uid=\"\(uid)\", AudioObjectID: \"\(audioDevice.AudioObjectID)\"")
                }
            }
        }
    }
#endif
