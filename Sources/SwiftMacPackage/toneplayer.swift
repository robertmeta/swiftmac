import AVFoundation
import Foundation

actor TonePlayerActor {
  private let audioPlayer = AVAudioPlayerNode()
  private let audioEngine = AVAudioEngine()
  private var isEngineSetup = false

  private func setupEngineIfNeeded() {
    guard !isEngineSetup else { return }
    
    audioEngine.attach(audioPlayer)
    let mixer = audioEngine.mainMixerNode
    
    guard let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32, 
      sampleRate: mixer.outputFormat(forBus: 0).sampleRate,
      channels: AVAudioChannelCount(1), 
      interleaved: false) else { return }
    
    audioEngine.connect(audioPlayer, to: mixer, format: format)
    audioEngine.prepare()
    
    isEngineSetup = true
  }

  func playPureTone(frequencyInHz: Int, amplitude: Float, durationInMillis: Int) async {
    setupEngineIfNeeded()
    
    let mixer = audioEngine.mainMixerNode
    let sampleRateHz = Float(mixer.outputFormat(forBus: 0).sampleRate)

    guard let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32, 
      sampleRate: Double(sampleRateHz),
      channels: AVAudioChannelCount(1), 
      interleaved: false) else { return }

    let totalDurationSeconds = Float(durationInMillis) / 1000
    let fadeDurationSeconds = totalDurationSeconds / 5
    let numberOfSamples = AVAudioFrameCount(sampleRateHz * totalDurationSeconds)

    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: numberOfSamples) else {
      return
    }
    buffer.frameLength = numberOfSamples

    if let channelData = buffer.floatChannelData?[0] {
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

    do {
      if !audioEngine.isRunning {
        try audioEngine.start()
      }
      
      audioPlayer.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in
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
