#!/usr/bin/env swift

import AVFoundation
import AppKit
import Darwin
import Foundation

// Supporting Classes
class DelegateHandler: NSObject, NSSpeechSynthesizerDelegate {
  func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
    speaker.startSpeaking(ss.popBacklog())
  }
}

class StateStore {
    private var backlog: String = ""
  private var rate: Int = 275
  private var sayRate: Int = 330
  private var speechVolume: Float = 1
  private var toneVolume: Float = 1
  private var soundVolume: Float = 1
  private var voice: String = "Alex"
  private var splitCaps: Bool = false
  private var charScale: Double = 1.2
  private let queue = DispatchQueue(label: "org.emacspeak.server.mac.state", qos: .userInteractive)

  func setVoice(voice: String) {
    queue.async {
      if self.voice != voice {
        self.voice = voice
        let voice = NSSpeechSynthesizer.VoiceName(
          rawValue: "com.apple.speech.synthesis.voice." + voice)
        speaker.setVoice(voice)
      }
    }
  }

  func clearBacklog() {
    queue.async {
      self.backlog = ""
    }
  }

  func pushBacklog(with: String) {
    queue.async {
      self.backlog += with
    }
  }

  func popBacklog() -> String {
    var result: String = ""
    queue.sync {
      result = self.backlog
    }
    self.clearBacklog()
    return result
  }
}

func playPureTone(frequencyInHz: Int, amplitude: Float, durationInMillis: Int) async {
  let toneQueue = DispatchQueue(label: "org.emacspeak.server.mac.tone", qos: .userInteractive)
  let semaphore = DispatchSemaphore(value: 1)
  toneQueue.async {
    let audioPlayer = AVAudioPlayerNode()
    let audioEngine = AVAudioEngine()
    semaphore.wait()
    audioEngine.attach(audioPlayer)
    let mixer = audioEngine.mainMixerNode
    let sampleRateHz = Float(mixer.outputFormat(forBus: 0).sampleRate)

    guard
      let format = AVAudioFormat(
        commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: Double(sampleRateHz),
        channels: AVAudioChannelCount(1), interleaved: false)
    else {
      return
    }

    audioEngine.connect(audioPlayer, to: mixer, format: format)

    let numberOfSamples = AVAudioFrameCount((Float(durationInMillis) / 1000 * sampleRateHz))

    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: numberOfSamples) else {
      return
    }
    buffer.frameLength = numberOfSamples

    let channels = UnsafeBufferPointer(
      start: buffer.floatChannelData, count: Int(format.channelCount))
    let floats = UnsafeMutableBufferPointer<Float>(start: channels[0], count: Int(numberOfSamples))

    let angularFrequency = Float(frequencyInHz * 2) * .pi

    for i in 0..<Int(numberOfSamples) {
      let waveComponent = sinf(Float(i) * angularFrequency / sampleRateHz)
      floats[i] = waveComponent * amplitude
    }
    do {
      try audioEngine.start()
    } catch {
      print("Error: Engine start failure")
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

// Global Constants
let version = "0.1"
let name = "mac.swift"

let speaker = NSSpeechSynthesizer()
let ss = StateStore()
let dh = DelegateHandler()

// default values
let voice = NSSpeechSynthesizer.VoiceName(rawValue: "com.apple.speech.synthesis.voice.Alex")
speaker.setVoice(voice)
speaker.rate = 275
speaker.volume = 1
speaker.delegate = dh

// Entry point and main loop
func main() async {
  while let l = readLine() {
    let cmd = await isolateCommand(line: l)
    debugPrint(cmd)
    switch cmd {
    case "a":
      await playAudioIcon(line: l)
    case "c":
      await queueCode(line: l)
    case "d":
      await dispatchSpeaker()
    case "l":
      await sayLetter(line: l)
    case "p":
      await playSound(line: l)
    case "q":
      await queueSpeaker(line: l)
    case "s":
      await stopSpeaker()
    case "sh":
      await saySilence(line: l)
    case "t":
      await playTone(line: l)
    case "version":
      await sayVersion()
    case "tts_exit":
      await ttsExit()
    case "tts_pause":
      await ttsPause()
    case "tts_reset":
      await ttsReset()
    case "tts_resume":
      await ttsResume()
    case "tts_say":
      await ttsSay(line: l)
    case "tts_set_character_scale":
      await ttsSetCharacterScale(line: l)
    case "tts_set_punctuations":
      await ttsSetPunctuations(line: l)
    case "tts_set_speech_rate":
      await ttsSetRate(line: l)
    case "tts_split_caps":
      await ttsSplitCaps(line: l)
    case "tts_sync_state":
      await ttsSyncState(line: l)
    default:
      await unknownLine(line: l)
    }
  }
}

func ttsSplitCaps(line: String) async {
  debugPrint("Not Implemented Yet")
}

func ttsReset() async {
  debugPrint("Not Implemented Yet")
}

func sayVersion() async {
    await say(what: "Running \(name) version \(version)", interupt: true)
}

func sayLetter(line: String) async {
    let letter = "S"
    await say(what:"[[ltrl]]\(letter)[[norm]]", interupt: true)
}

func saySilence(line: String) async {
  await say(what: "[[slic]]", interupt: false)
}

func ttsPause() async {
  
}

func ttsResume() async {
  
}

func ttsSetCharacterScale(line: String) async {
  debugPrint("Not Implemented Yet")
}

func ttsSetPunctuations(line: String) async {
  debugPrint("Not Implemented Yet")
}

func ttsSetRate(line: String) async {
  debugPrint("Not Implemented Yet")
}

func ttSplitCaps(line: String) async {
  debugPrint("Not Implemented Yet")
}

func ttsSyncState(line: String) async {
  debugPrint("Not Implemented Yet")
}

func playTone(line: String) async {
    let toneVolume:Float = 1.0
  await playPureTone(frequencyInHz: 440, amplitude: toneVolume, durationInMillis: 1000)
}

func stopSpeaker() async {
  ss.clearBacklog()
  speaker.stopSpeaking()
}

func dispatchSpeaker() async {
  speaker.startSpeaking(ss.popBacklog())
}

func queueSpeaker(line: String) async {
  let p = await isolateParams(line: line)
  ss.pushBacklog(with: " " + p)
}

func queueCode(line: String) async {
  let p = await isolateParams(line: line)
  ss.pushBacklog(with: " " + p)
}

// Does the same thing as "p " so route it over to playSound
func playAudioIcon(line: String) async {
  print("Playing audio icon: " + line)
  await playSound(line: line)
}

func playSound(line: String) async {
  print("Playing sound: " + line)
  let p = await isolateParams(line: line)
  let soundURL = URL(fileURLWithPath: p)
  NSSound(contentsOf: soundURL, byReference: true)?.play()
}

func ttsSay(line: String) async {
  print("ttsSay: " + line)
  let p = await isolateParams(line: line)
  await say(what: p, interupt: true)

}

func say(what: String, interupt: Bool) async {
  let w = await stripSpecialEmbeds(what)
  if interupt {
    speaker.startSpeaking(w)
  } else {
    if speaker.isSpeaking {
      ss.pushBacklog(with: w)
    } else {
      speaker.startSpeaking(w)
    }
  }
}

func unknownLine(line: String) async {
  debugPrint("Unknown command: " + line)
}

// TODO: make signals call this as well
func ttsExit() async {
  print("Exiting " + name)
  exit(0)
}

// TODO: handle these, so far I know it uses voice
// and echo
// voice is straightforward, call setVoice but
// dealing with echo is trickier but possible with
// a customized NSVoiceSynth
func stripSpecialEmbeds(_ s: String) async -> String {
  let specialEmbedRegexp = #"\[\{.*?\}\]"#
  return s.replacingOccurrences(of: specialEmbedRegexp, with: "", options: .regularExpression)
}

func isolateCommand(line: String) async -> String {
  var cmd = line.trimmingCharacters(in: .whitespacesAndNewlines)
  if let firstIndex = cmd.firstIndex(of: " ") {
    cmd.replaceSubrange(firstIndex..<cmd.endIndex, with: "")
    return cmd
  }
  return cmd
}

func isolateParams(line: String) async -> String {
  let cmd = await isolateCommand(line: line) + " "
  var params = line.replacingOccurrences(of: cmd, with: "")
  params = params.trimmingCharacters(in: .whitespacesAndNewlines)
  if params.hasPrefix("{") && params.hasSuffix("}") {
    if let lastIndex = params.lastIndex(of: "}") {
      params.replaceSubrange(lastIndex...lastIndex, with: "")
    }
    if let firstIndex = params.firstIndex(of: "{") {
      params.replaceSubrange(firstIndex...firstIndex, with: "")
    }
  }
  return params
}

await main()
