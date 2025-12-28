#!/usr/bin/env swift

import CoreAudio
import Foundation

// MARK: - Audio Device Enumeration Tool

/// Lists all available audio output devices with their IDs, names, and configuration strings
/// This tool helps users identify device IDs for configuring swiftmac audio routing

// MARK: - Helper Functions

func getDefaultOutputDevice() -> AudioDeviceID {
    var deviceID = AudioDeviceID(0)
    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &propertySize,
        &deviceID
    )

    guard status == noErr else {
        return 0
    }

    return deviceID
}

func getAllDeviceIDs() -> [AudioDeviceID] {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize
    )

    guard status == noErr else {
        return []
    }

    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0,
        nil,
        &dataSize,
        &deviceIDs
    )

    guard status == noErr else {
        return []
    }

    return deviceIDs
}

func getDeviceName(deviceID: AudioDeviceID) -> String? {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize = UInt32(MemoryLayout<CFString>.size)
    let deviceName = withUnsafeMutablePointer(to: &dataSize) { dataSizePtr -> String? in
        var name: Unmanaged<CFString>?
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            dataSizePtr,
            &name
        )

        guard status == noErr, let cfString = name?.takeRetainedValue() else {
            return nil
        }

        return cfString as String
    }

    return deviceName
}

func getDeviceUID(deviceID: AudioDeviceID) -> String? {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize = UInt32(MemoryLayout<CFString>.size)
    let deviceUID = withUnsafeMutablePointer(to: &dataSize) { dataSizePtr -> String? in
        var uid: Unmanaged<CFString>?
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            dataSizePtr,
            &uid
        )

        guard status == noErr, let cfString = uid?.takeRetainedValue() else {
            return nil
        }

        return cfString as String
    }

    return deviceUID
}

func getDeviceChannelCount(deviceID: AudioDeviceID) -> UInt32 {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &dataSize
    )

    guard status == noErr else {
        return 0
    }

    let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
    defer {
        bufferListPointer.deallocate()
    }

    status = AudioObjectGetPropertyData(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &dataSize,
        bufferListPointer
    )

    guard status == noErr else {
        return 0
    }

    let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
    var channelCount: UInt32 = 0

    for buffer in bufferList {
        channelCount += buffer.mNumberChannels
    }

    return channelCount
}

func isOutputDevice(deviceID: AudioDeviceID) -> Bool {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    let status = AudioObjectGetPropertyDataSize(
        deviceID,
        &propertyAddress,
        0,
        nil,
        &dataSize
    )

    guard status == noErr else {
        return false
    }

    // If dataSize > 0, device has output streams
    return dataSize > 0
}

// MARK: - Main

func main() {
    print("Available Audio Output Devices:")
    print("================================\n")

    let defaultDeviceID = getDefaultOutputDevice()
    let allDeviceIDs = getAllDeviceIDs()

    // Filter for output devices only
    let outputDevices = allDeviceIDs.filter { isOutputDevice(deviceID: $0) }

    if outputDevices.isEmpty {
        print("No output devices found.")
        return
    }

    for deviceID in outputDevices {
        guard let deviceName = getDeviceName(deviceID: deviceID) else {
            continue
        }

        let channelCount = getDeviceChannelCount(deviceID: deviceID)
        let isDefault = deviceID == defaultDeviceID

        let prefix = isDefault ? "[DEFAULT] " : "          "

        print("\(prefix)DeviceID: \(deviceID) | \"\(deviceName)\" | Channels: \(channelCount)")

        // Show example configurations
        if channelCount >= 2 {
            print("          Config (both channels): \(deviceID):both")
            print("          Config (left only):     \(deviceID):left")
            print("          Config (right only):    \(deviceID):right")
        } else if channelCount == 1 {
            print("          Config (mono):          \(deviceID):both")
        }

        if let uid = getDeviceUID(deviceID: deviceID) {
            print("          UID: \(uid)")
        }

        print("")
    }

    print("Usage:")
    print("------")
    print("Set environment variables to route audio to specific devices/channels:")
    print("")
    print("export SWIFTMAC_SPEECH_DEVICE_AND_CHANNEL=\"\(defaultDeviceID):both\"")
    print("export SWIFTMAC_NOTIFICATION_DEVICE_AND_CHANNEL=\"\(defaultDeviceID):left\"")
    print("export SWIFTMAC_TONE_DEVICE_AND_CHANNEL=\"\(defaultDeviceID):both\"")
    print("export SWIFTMAC_SOUNDEFFECT_DEVICE_AND_CHANNEL=\"\(defaultDeviceID):both\"")
    print("")
    print("Note: DeviceID 0 means system default device")
}

main()
