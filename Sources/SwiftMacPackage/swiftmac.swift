import AVFoundation
/*
HOW TO USE
 Just set your server to swiftmac. Assuming you have the swift command
 line installed via xcode command line tools, you are done, it will
 just work.

 To learn more: https://github.com/robertmeta/swiftmac

Major Issues
 Ignores voice channges, uses Alex is available or default.

License
 Copyright 2023 Robert Melton

 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation files
 (the “Software”), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge,
 publish, distribute, sublicense, and/or sell copies of the Software,
 and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
import AppKit
import Darwin
import Foundation

// Global Constants
let version = "0.3"
let name = "swiftmac"
let speaker = NSSpeechSynthesizer()
let defaultRate: Float = 200
let defaultCharScale: Float = 1.2
let defaultVoice = NSSpeechSynthesizer.defaultVoice
let defaultPunct = "all"
let defaultSplitCaps = false
let defaultBeepCaps = false
let soundVolume: Float = 0.5
let toneVolume: Float = 0.75
let voiceVolume: Float = 1.0

// This delegate class lets us continue speaking with queued data
// after a speech chunk is completed
class DelegateHandler: NSObject, NSSpeechSynthesizerDelegate {
  func speechSynthesizer(
    _ sender: NSSpeechSynthesizer,
    didFinishSpeaking finishedSpeaking: Bool
  ) {
    let s = ss.popBacklog()
    if debug {
      debugPrint("didFinishSpeaking:startSpeaking: \(s)")
    }
    speaker.startSpeaking(s)
  }
}
let dh = DelegateHandler()
speaker.delegate = dh

// Due to being fully async, handling the state is a bit of a pain,
// we have to store it all in a class and gate access to it, the good
// news is the only syncronise bits are on reading the data out.
class StateStore {
  private var backlog: String = ""
  // private var voiceq = defaultVoice
  private var splitCaps: Bool = defaultSplitCaps
  private var voice = defaultVoice
  private var beepCaps: Bool = defaultBeepCaps
  private var charScale: Float = defaultCharScale
  private var punct: String = defaultPunct
  private let queue = DispatchQueue(
    label: "org.emacspeak.server.swiftmac.state", qos: .userInteractive)

  /*
  func setVoice(voice: String) {
    queue.async {
      if self.voice != voice {
        let alex = NSSpeechSynthesizer.VoiceName(
          rawValue: "com.apple.speech.synthesis.voice.Alex")
        if !speaker.setVoice(voice) {
          speaker.setVoice(defaultVoice)
        }
      }
    }
  }
  */

  func clearBacklog() {
    queue.async {
      self.backlog = ""
    }
  }

  func pushBacklog(_ with: String, code: Bool = false) {
    queue.async {
      var w = stripSpecialEmbeds(with)
      if !code {
        w = replaceAllPuncs(w)
      }
      self.backlog += w
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

  func setCharScale(_ r: Float) {
    queue.async {
      self.charScale = r
    }
  }

  func getCharScale() -> Float {
    queue.sync {
      return self.charScale
    }
  }

  func setPunct(_ s: String) {
    queue.async {
      self.punct = s
    }
  }

  func getPunct() -> String {
    queue.sync {
      return self.punct
    }
  }

  func setSplitCaps(_ b: Bool) {
    queue.async {
      self.splitCaps = b
    }
  }

  func getSplitCaps() -> Bool {
    queue.sync {
      return self.splitCaps
    }
  }

  func setBeepCaps(_ b: Bool) {
    queue.async {
      self.beepCaps = b
    }
  }

  func getBeepCaps() -> Bool {
    queue.sync {
      return self.beepCaps
    }
  }
}
let ss = StateStore()

// Generates a tone in pure swift
func playPureTone(
  frequencyInHz: Int, amplitude: Float,
  durationInMillis: Int
) async {
  let toneQueue = DispatchQueue(
    label: "org.emacspeak.server.swiftmac.tone", qos: .userInteractive)
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
        commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
        sampleRate: Double(sampleRateHz),
        channels: AVAudioChannelCount(1), interleaved: false)
    else {
      return
    }

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

// Get DEBUG from ENV
var debug = false
if let debugStr = ProcessInfo.processInfo.environment["DEBUG"] {
  if debugStr.lowercased() == "true" {
    debug = true
    await say("debug mode turned on")
  }
}

// Entry point and main loop
func main() async {
  await say("welcome to e mac speak with swift mac", interupt: true)
  while let l = readLine() {
    let cmd = await isolateCommand(l)
    switch cmd {
    case "a": await playAudioIcon(l)
    case "c": await queueCode(l)
    case "d": await dispatchSpeaker()
    case "l": await sayLetter(l)
    case "p": await playSound(l)
    case "q": await queueSpeaker(l)
    case "s": await stopSpeaker()
    case "sh": await saySilence(l)
    case "t": await playTone(l)
    case "version": await sayVersion()
    case "tts_exit": await ttsExit()
    case "tts_pause": await ttsPause()
    case "tts_reset": await ttsReset()
    case "tts_resume": await ttsResume()
    case "tts_say": await ttsSay(l)
    case "tts_set_character_scale": await ttsSetCharacterScale(l)
    case "tts_set_punctuations": await ttsSetPunctuations(l)
    case "tts_set_speech_rate": await ttsSetRate(l)
    case "tts_split_caps": await ttsSplitCaps(l)
    case "tts_sync_state": await ttsSyncState(l)
    default: await unknownLine(l)
    }
  }
}

// This is replacements that always must happen when doing
// replaceements like [*] -> slnc
func replaceCore(_ line: String) -> String {
  return
    line
    .replacingOccurrences(of: "[*]", with: " [[slnc 50]] ")
}

func replaceBasePuncs(_ line: String) -> String {
  return replaceCore(line)
    .replacingOccurrences(of: "$", with: " dollar ")

}

func replaceSomePuncs(_ line: String) -> String {
  if ss.getPunct().lowercased() == "none" {
    return replaceBasePuncs(line)
  }
  return replaceBasePuncs(line)
    .replacingOccurrences(of: "#", with: " pound ")
    .replacingOccurrences(of: "-", with: " dash ")
    .replacingOccurrences(of: "\"", with: " quote ")
    .replacingOccurrences(of: "(", with: " leftParen ")
    .replacingOccurrences(of: ")", with: " rightParen ")
    .replacingOccurrences(of: "*", with: " star ")
    .replacingOccurrences(of: ";", with: " semi ")
    .replacingOccurrences(of: ":", with: " colon ")
    .replacingOccurrences(of: "\n", with: "")
    .replacingOccurrences(of: "\\", with: " backslash ")
    .replacingOccurrences(of: "/", with: " slash ")
    .replacingOccurrences(of: "+", with: " plus ")
    .replacingOccurrences(of: "=", with: " equals ")
    .replacingOccurrences(of: "~", with: " tilda ")
    .replacingOccurrences(of: "`", with: " backquote ")
    .replacingOccurrences(of: "!", with: " exclamation ")
    .replacingOccurrences(of: "^", with: " caret ")
}

func replaceAllPuncs(_ line: String) -> String {
  return replaceSomePuncs(line)
    .replacingOccurrences(of: "<", with: " less than ")
    .replacingOccurrences(of: ">", with: " greater than ")
    .replacingOccurrences(of: "'", with: " apostrophe ")
    .replacingOccurrences(of: "*", with: " star ")
    .replacingOccurrences(of: "@", with: " at sign ")
    .replacingOccurrences(of: "_", with: " underline ")
    .replacingOccurrences(of: ".", with: " dot ")
    .replacingOccurrences(of: ",", with: " comma ")

}

func ttsSplitCaps(_ line: String) async {
  let l = await isolateCommand(line)
  if l == "1" {
    ss.setSplitCaps(true)
  } else {
    ss.setSplitCaps(false)
  }
}

func ttsReset() async {
  speaker.stopSpeaking()
  ss.clearBacklog()
  let voice = NSSpeechSynthesizer.VoiceName(
    rawValue: "com.apple.speech.synthesis.voice.Alex")
  if !speaker.setVoice(voice) {
    speaker.setVoice(defaultVoice)
  }
  speaker.rate = defaultRate
  speaker.volume = voiceVolume
  ss.setCharScale(defaultCharScale)
  ss.setPunct(defaultPunct)
}

func sayVersion() async {
  await say("Running \(name) version \(version)", interupt: true)
}

func sayLetter(_ line: String) async {
  let letter = await isolateParams(line)
  let charRate = speaker.rate * ss.getCharScale()

  await say(
    "[[rate \(charRate)]][[char ltrl]]\(letter)[[rset 0]]",
    interupt: true,
    code: true
  )
}

func saySilence(_ line: String, duration: Int = 50) async {
  await say("[[slnc \(duration)]]", interupt: false)
}

func ttsPause() async {
  speaker.pauseSpeaking(at: .immediateBoundary)
}

func ttsResume() async {
  speaker.continueSpeaking()
}

func ttsSetCharacterScale(_ line: String) async {
  let l = await isolateParams(line)
  if let fl = Float(l) {
    ss.setCharScale(fl)
  }
}

func ttsSetPunctuations(_ line: String) async {
  let l = await isolateParams(line)
  ss.setPunct(l)
}

func ttsSetRate(_ line: String) async {
  let l = await isolateParams(line)
  if let fl = Float(l) {
    speaker.rate = fl
  }
}

func ttSplitCaps(_ line: String) async {
  let l = await isolateParams(line)
  if l == "1" {
  }
}

func ttsSyncState(_ line: String) async {
  let l = await isolateParams(line)
  let ps = l.split(separator: " ")
  if ps.count == 4 {
    if let r = Float(ps[3]) {
      speaker.rate = r
    }

    let beepCaps = ps[2]
    if beepCaps == "1" {
      ss.setBeepCaps(true)
    } else {
      ss.setBeepCaps(false)
    }

    let splitCaps = ps[1]
    if splitCaps == "1" {
      ss.setSplitCaps(true)
    } else {
      ss.setSplitCaps(false)
    }
    let punct = ps[0]
    ss.setPunct(String(punct))
  }
}

func playTone(_ line: String) async {
  let p = await isolateParams(line)
  let ps = p.split(separator: " ")
  await playPureTone(
    frequencyInHz: Int(ps[0]) ?? 500,
    amplitude: toneVolume,
    durationInMillis: Int(ps[1]) ?? 75
  )
}

func stopSpeaker() async {
  ss.clearBacklog()
  speaker.stopSpeaking()
}

func dispatchSpeaker() async {
  speaker.startSpeaking(ss.popBacklog())
}

func queueSpeaker(_ line: String) async {
  let p = await isolateParams(line)
  ss.pushBacklog(p)
}

func queueCode(_ line: String) async {
  let p = await isolateParams(line)
  ss.pushBacklog(p, code: true)
}

// Does the same thing as "p " so route it over to playSound
func playAudioIcon(_ line: String) async {
  if await debug {
    debugPrint("Playing audio icon: " + line)
  }
  await playSound(line)
}

func playSound(_ line: String) async {
  let p = await isolateParams(line)
  let soundURL = URL(fileURLWithPath: p)
  let sound = NSSound(contentsOf: soundURL, byReference: true)
  sound?.volume = soundVolume
  sound?.play()
}

func ttsSay(_ line: String) async {
  if await debug {
    debugPrint("ttsSay: " + line)
  }
  let p = await isolateParams(line)
  await say(p, interupt: true)

}

func say(_ what: String, interupt: Bool = false, code: Bool = false) async {
  var w = stripSpecialEmbeds(what)
  if !code {
    w = replaceAllPuncs(w)
  }
  if interupt {
    speaker.startSpeaking(w)
  } else {
    if speaker.isSpeaking {
      ss.pushBacklog(w)
    } else {
      if await debug {
        debugPrint("say:startSpeaking: \(w)")
      }
      speaker.startSpeaking(w)
    }
  }
}

func unknownLine(_ line: String) async {
  if await debug {
    debugPrint("Unknown command: " + line)
  }
}

func ttsExit() async {
  if await debug {
    debugPrint("Exiting " + name)
  }
  exit(0)
}

func stripSpecialEmbeds(_ line: String) -> String {
  let specialEmbedRegexp = #"\[\{.*?\}\]"#
  return voiceToReset(line).replacingOccurrences(
    of: specialEmbedRegexp,
    with: "", options: .regularExpression)
}

// So, it turns out we get spammed with voice often as a form of a
// reset of the voice engine, good news is we have that command
// built right in
func voiceToReset(_ line: String) -> String {
  let specialEmbedRegexp = #"\[\{voice.*?\}\]"#
  return line.replacingOccurrences(
    of: specialEmbedRegexp,
    with: " [[rset 0]] ", options: .regularExpression)
}

func isolateCommand(_ line: String) async -> String {
  var cmd = line.trimmingCharacters(in: .whitespacesAndNewlines)
  if let firstIndex = cmd.firstIndex(of: " ") {
    cmd.replaceSubrange(firstIndex..<cmd.endIndex, with: "")
    return cmd
  }
  return cmd
}

func isolateParams(_ line: String) async -> String {
  let cmd = await isolateCommand(line) + " "
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

await ttsReset()
await main()

// local variables:
// mode: swift
// swift-mode:basic-offset: 2
// end:
