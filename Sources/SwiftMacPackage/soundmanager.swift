import AVFoundation
import CoreAudio
import Foundation

actor SoundManager {
  static let shared = SoundManager()

  // Each sound effect gets its own player node and engine for independent playback
  private struct SoundPlayer {
    let playerNode: AVAudioPlayerNode
    let engine: AVAudioEngine
    let id: UUID
  }

  private var activePlayers: [UUID: SoundPlayer] = [:]
  private var activeTasks: [UUID: Task<Void, Never>] = [:]

  func playSound(from url: URL, volume: Float, routing: AudioRouting) async {
    let playerId = UUID()

    do {
      // Load audio file into PCM buffer (standard formats only - OGG already decoded to WAV)
      guard let buffer = try loadAudioBuffer(from: url) else {
        debugLogger.log("Failed to load audio buffer from \(url.path)")
        return
      }

      // Apply channel routing to the buffer
      let routedBuffer = applyChannelMode(to: buffer, mode: routing.channelMode, volume: volume)

      // Create dedicated engine and player for this sound
      let engine = AVAudioEngine()
      let playerNode = AVAudioPlayerNode()

      engine.attach(playerNode)

      // Set output device if specified (0 means system default)
      if routing.deviceID != 0 {
        #if os(macOS)
          do {
            try engine.outputNode.auAudioUnit.setDeviceID(routing.deviceID)
          } catch {
            debugLogger.log("Failed to set sound effect output device: \(error)")
          }
        #endif
      }

      // Connect to mixer
      let mixer = engine.mainMixerNode
      engine.connect(playerNode, to: mixer, format: routedBuffer.format)
      engine.prepare()

      // Store player info
      let player = SoundPlayer(playerNode: playerNode, engine: engine, id: playerId)
      activePlayers[playerId] = player

      // Start engine and play
      try engine.start()

      playerNode.scheduleBuffer(routedBuffer, completionCallbackType: .dataPlayedBack) { _ in
        Task { [weak self] in
          await self?.cleanupPlayer(playerId)
        }
      }

      playerNode.play()

    } catch {
      debugLogger.log("Error playing sound: \(error)")
      await cleanupPlayer(playerId)
    }
  }

  private func loadAudioBuffer(from url: URL) throws -> AVAudioPCMBuffer? {
    // Load standard audio formats (WAV, AIFF, etc.) - OGG files are already decoded to WAV
    let file = try AVAudioFile(forReading: url)

    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: file.processingFormat,
        frameCapacity: AVAudioFrameCount(file.length)
      )
    else {
      return nil
    }

    try file.read(into: buffer)
    return buffer
  }

  // PCM channel manipulation - copied from toneplayer.swift for consistency
  private func applyChannelMode(to inputBuffer: AVAudioPCMBuffer, mode: ChannelMode, volume: Float)
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
      for i in 0..<frameCount {
        outputLeft[i] = inputChannel0[i] * volume
        outputRight[i] = 0
      }

    case .right:
      for i in 0..<frameCount {
        outputLeft[i] = 0
        if let rightInput = inputChannel1 {
          outputRight[i] = rightInput[i] * volume
        } else {
          outputRight[i] = inputChannel0[i] * volume
        }
      }

    case .both:
      if let rightInput = inputChannel1 {
        for i in 0..<frameCount {
          outputLeft[i] = inputChannel0[i] * volume
          outputRight[i] = rightInput[i] * volume
        }
      } else {
        for i in 0..<frameCount {
          outputLeft[i] = inputChannel0[i] * volume
          outputRight[i] = inputChannel0[i] * volume
        }
      }
    }

    return outputBuffer
  }

  private func cleanupPlayer(_ playerId: UUID) {
    if let player = activePlayers[playerId] {
      player.playerNode.stop()
      if player.engine.isRunning {
        player.engine.stop()
      }
      activePlayers[playerId] = nil
    }
    activeTasks[playerId] = nil
  }

  func stop() {
    // Cancel all pending tasks
    for (_, task) in activeTasks {
      task.cancel()
    }
    activeTasks.removeAll()

    // Stop all active players and engines
    for (_, player) in activePlayers {
      player.playerNode.stop()
      if player.engine.isRunning {
        player.engine.stop()
      }
    }
    activePlayers.removeAll()
  }
}
