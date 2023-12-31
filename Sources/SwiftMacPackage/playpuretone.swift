import AVFoundation
import AppKit
import Darwin
import Foundation

let audioEngine = AVAudioEngine() 

let audioPlayer = AVAudioPlayerNode()

let mixer = audioEngine.mainMixerNode
let sampleRateHz = Float(mixer.outputFormat(forBus: 0).sampleRate) 

let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, 
                           sampleRate: Double(sampleRateHz), 
                           channels: 1, interleaved: false)!
                           

let toneQueue = DispatchQueue(label: "toneQueue")
let semaphore = DispatchSemaphore(value: 1)

/* Generates a tone in pure swift */
func playPureTone(
  frequencyInHz: Int, amplitude: Float,
  durationInMillis: Int
) async {
  #if DEBUG
    debugLogger.log("in playPureTone")
  #endif
  toneQueue.async {
    semaphore.wait()
    audioEngine.attach(audioPlayer)
    audioEngine.connect(audioPlayer, to: mixer, format: format)

    let numberOfSamples = AVAudioFrameCount(
      (Float(durationInMillis)
        / 1000 * sampleRateHz))

    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: numberOfSamples)
    else {
      return
    }
    buffer.frameLength = numberOfSamples

    let channels = UnsafeBufferPointer(
      start: buffer.floatChannelData, count: Int(format.channelCount))
    let floats = UnsafeMutableBufferPointer<Float>(
      start: channels[0], count: Int(numberOfSamples))

    let angularFrequency = Float(frequencyInHz * 2) * .pi

    for i in 0..<Int(numberOfSamples) {
      let waveComponent =
        sinf(Float(i) * angularFrequency / sampleRateHz)
      floats[i] = waveComponent * amplitude
    }
    do {
      try audioEngine.start()
    } catch {
      debugPrint("Error: Engine start failure")
      return
    }

    audioPlayer.play()
    audioPlayer.scheduleBuffer(buffer, at: nil, options: .interrupts) {
      toneQueue.async {
        semaphore.signal()
      }
    }
    semaphore.wait()
    semaphore.signal()
  }
}
