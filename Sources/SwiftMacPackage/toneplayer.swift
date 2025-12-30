import AVFoundation
import CoreAudio
import Foundation

actor TonePlayerActor {
  private let audioPlayer = AVAudioPlayerNode()
  private let audioEngine = AVAudioEngine()
  private var isEngineSetup = false
  private var currentDeviceID: AudioDeviceID = 0
  private var outputFormat: AVAudioFormat?

  private func setupEngineIfNeeded(deviceID: AudioDeviceID) {
    // Reset if device changed
    if isEngineSetup && deviceID != currentDeviceID {
      audioEngine.stop()
      audioEngine.reset()
      isEngineSetup = false
    }

    guard !isEngineSetup else { return }

    audioEngine.attach(audioPlayer)

    // Set output device if specified (0 means system default)
    if deviceID != 0 {
      #if os(macOS)
        do {
          try audioEngine.outputNode.auAudioUnit.setDeviceID(deviceID)
        } catch {
          debugLogger.log("Failed to set tone output device: \(error)")
        }
      #endif
    }

    let mixer = audioEngine.mainMixerNode

    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 44_100,
        channels: AVAudioChannelCount(2),  // Changed to stereo for channel routing
        interleaved: false)
    else { return }

    outputFormat = format
    audioEngine.connect(audioPlayer, to: mixer, format: format)
    audioEngine.prepare()

    currentDeviceID = deviceID
    isEngineSetup = true
  }

  // PCM channel manipulation - copied from main.swift for consistency
  private func applyChannelMode(to inputBuffer: AVAudioPCMBuffer, mode: ChannelMode)
    -> AVAudioPCMBuffer
  {
    let inputFormat = inputBuffer.format
    let frameCount = Int(inputBuffer.frameLength)

    guard
      let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: inputFormat.sampleRate,
        channels: 2,
        interleaved: false
      )
    else {
      return inputBuffer
    }

    guard
      let outputBuffer = AVAudioPCMBuffer(
        pcmFormat: outputFormat,
        frameCapacity: inputBuffer.frameCapacity
      )
    else {
      return inputBuffer
    }

    outputBuffer.frameLength = inputBuffer.frameLength

    guard let inputChannel0 = inputBuffer.floatChannelData?[0],
      let outputLeft = outputBuffer.floatChannelData?[0],
      let outputRight = outputBuffer.floatChannelData?[1]
    else {
      return inputBuffer
    }

    let inputChannel1 = inputFormat.channelCount > 1 ? inputBuffer.floatChannelData?[1] : nil

    switch mode {
    case .left:
      memcpy(outputLeft, inputChannel0, frameCount * MemoryLayout<Float>.size)
      memset(outputRight, 0, frameCount * MemoryLayout<Float>.size)

    case .right:
      memset(outputLeft, 0, frameCount * MemoryLayout<Float>.size)
      if let rightInput = inputChannel1 {
        memcpy(outputRight, rightInput, frameCount * MemoryLayout<Float>.size)
      } else {
        memcpy(outputRight, inputChannel0, frameCount * MemoryLayout<Float>.size)
      }

    case .both:
      if let rightInput = inputChannel1 {
        memcpy(outputLeft, inputChannel0, frameCount * MemoryLayout<Float>.size)
        memcpy(outputRight, rightInput, frameCount * MemoryLayout<Float>.size)
      } else {
        memcpy(outputLeft, inputChannel0, frameCount * MemoryLayout<Float>.size)
        memcpy(outputRight, inputChannel0, frameCount * MemoryLayout<Float>.size)
      }
    }

    return outputBuffer
  }

  func playPureTone(
    frequencyInHz: Int, amplitude: Float, durationInMillis: Int, routing: AudioRouting
  ) async {
    setupEngineIfNeeded(deviceID: routing.deviceID)

    let sampleRateHz: Float = 44_100

    // Generate tone in mono first
    guard
      let monoFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(sampleRateHz),
        channels: AVAudioChannelCount(1),
        interleaved: false)
    else { return }

    let totalDurationSeconds = Float(durationInMillis) / 1000
    let fadeDurationSeconds = totalDurationSeconds / 5
    let numberOfSamples = AVAudioFrameCount(sampleRateHz * totalDurationSeconds)

    guard let monoBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: numberOfSamples)
    else {
      return
    }
    monoBuffer.frameLength = numberOfSamples

    // Generate tone waveform
    if let channelData = monoBuffer.floatChannelData?[0] {
      let angularFrequency = Float(frequencyInHz * 2) * .pi
      for i in 0..<Int(numberOfSamples) {
        let time = Float(i) / sampleRateHz
        var currentAmplitude = amplitude
        // Fade in
        if time < fadeDurationSeconds {
          currentAmplitude *= time / fadeDurationSeconds
        }
        // Fade out
        else if time > totalDurationSeconds - fadeDurationSeconds {
          currentAmplitude *= (totalDurationSeconds - time) / fadeDurationSeconds
        }

        channelData[i] = sinf(Float(i) * angularFrequency / sampleRateHz) * currentAmplitude
      }
    }

    // Apply channel routing to the generated tone
    let routedBuffer = applyChannelMode(to: monoBuffer, mode: routing.channelMode)

    do {
      if !audioEngine.isRunning {
        try audioEngine.start()
      }

      audioPlayer.scheduleBuffer(routedBuffer, completionCallbackType: .dataPlayedBack) { _ in
        Task { [weak self] in
          await self?.handleBufferComplete()
        }
      }

      if !audioPlayer.isPlaying {
        audioPlayer.play()
      }
    } catch {
      print("Error: Engine start failure: \(error)")
    }
  }

  private func handleBufferComplete() {
    // Stop player after buffer completes to clean up resources
    audioPlayer.stop()
    // Stop engine if no more buffers are scheduled
    if audioEngine.isRunning && !audioPlayer.isPlaying {
      audioEngine.stop()
    }
  }

  func stop() {
    audioPlayer.stop()
    if audioEngine.isRunning {
      audioEngine.stop()
    }
  }

  deinit {
    stop()
  }
}
