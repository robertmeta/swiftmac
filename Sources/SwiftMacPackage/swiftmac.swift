import AVFoundation
import AppKit
import Darwin
import Foundation

// Global Constants
let version = "0.3"
let name = "swiftmac"
let speaker = NSSpeechSynthesizer()
let defaultRate: Float = 200
let defaultCharScale: Float = 1.1
let defaultVoice = NSSpeechSynthesizer.defaultVoice
let defaultPunct = "all"
let defaultSplitCaps = false
let defaultBeepCaps = false
var soundVolume: Float = 0.1
var toneVolume: Float = 0.1
var voiceVolume: Float = 1.0

func getEnvironmentVariable(_ variable: String) -> String {
  return ProcessInfo.processInfo.environment[variable] ?? ""
}
if let f = Float(getEnvironmentVariable("SWIFTMAC_SOUND_VOLUME")) {
  soundVolume = f
}
if let f = Float(getEnvironmentVariable("SWIFTMAC_TONE_VOLUME")) {
  toneVolume = f
}
if let f = Float(getEnvironmentVariable("SWIFTMAC_VOICE_VOLUME")) {
  voiceVolume = f
}

print("soundVolume \(soundVolume)")
print("toneVolume \(toneVolume)")
print("voiceVolume \(voiceVolume)")

class Logger {
  private let fileURL: URL
  private let backgroundQueue: DispatchQueue

  init(fileName: String) {
    let fileManager = FileManager.default
    let directoryURL = URL(fileURLWithPath: "/tmp", isDirectory: true)

    fileURL = directoryURL.appendingPathComponent(fileName)

    // Create file if it doesn't exist
    if !fileManager.fileExists(atPath: fileURL.path) {
      fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
    }

    backgroundQueue = DispatchQueue(label: "org.emacspeak.server.swiftmac.logger", qos: .background)
  }

  func log(_ m: String) {
    let message = m + "\n"
    backgroundQueue.async { [weak self] in
      guard let self = self else { return }

      do {
        let fileHandle = try FileHandle(forWritingTo: self.fileURL)
        defer { fileHandle.closeFile() }

        fileHandle.seekToEndOfFile()
        if let data = message.data(using: .utf8) {
          fileHandle.write(data)
        }
      } catch {
        print("Error writing to log file: \(error)")
      }
    }
  }
}

#if DEBUG
  let currentDate = Date()
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy-MM-dd_HH_mm_ss"
  let timestamp = dateFormatter.string(from: currentDate)
  let DebugLogger = Logger(fileName: "swiftmac-debug-\(timestamp).log")
#endif

// This delegate class lets us continue speaking with queued data
// after a speech chunk is completed
class DelegateHandler: NSObject, NSSpeechSynthesizerDelegate {
  func speechSynthesizer(
    _ sender: NSSpeechSynthesizer,
    didFinishSpeaking finishedSpeaking: Bool
  ) {
    let s = ss.popBacklog()
    #if DEBUG
      DebugLogger.log("didFinishSpeaking:startSpeaking: \(s)")
    #endif
    speaker.startSpeaking(s)
    #if DEBUG
      DebugLogger.log("Enter: startSpeaking")
    #endif
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
    label: "org.emacspeak.server.swiftmac.state",
    qos: .userInteractive)

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
    #if DEBUG
      DebugLogger.log("Enter: clearBacklog")
    #endif

    queue.async {
      self.backlog = ""
    }
  }

  func pushBacklog(_ with: String, code: Bool = false) {
    #if DEBUG
      DebugLogger.log("Enter: pushBacklog")
    #endif
    let punct = self.getPunct().lowercased()
    queue.async { [weak self] in
      guard let self = self else { return }
      var w = stripSpecialEmbeds(with)
      if !code {
        switch punct {
        case "all":
          w = replaceAllPuncs(w)
        case "some":
          w = replaceSomePuncs(w)
        case "none":
          w = replaceBasePuncs(w)
        default:
          w = replaceCore(w)
        }
      }
      self.backlog += w
    }
  }

  func popBacklog() -> String {
    #if DEBUG
      DebugLogger.log("Enter: popBacklog")
    #endif
    var result: String = ""
    queue.sync {
      result = self.backlog
    }
    self.clearBacklog()
    return result
  }

  func setCharScale(_ r: Float) {
    #if DEBUG
      DebugLogger.log("Enter: setCharScale")
    #endif
    queue.async {
      self.charScale = r
    }
  }

  func getCharScale() -> Float {
    #if DEBUG
      DebugLogger.log("Enter: getCharScale")
    #endif
    return queue.sync {
      return self.charScale
    }
  }

  func setPunct(_ s: String) {
    #if DEBUG
      DebugLogger.log("Enter: setPunct")
    #endif
    queue.async {
      self.punct = s
    }
  }

  func getPunct() -> String {
    #if DEBUG
      DebugLogger.log("Enter: getPunct")
    #endif
    return queue.sync {
      return self.punct
    }
  }

  func setSplitCaps(_ b: Bool) {
    #if DEBUG
      DebugLogger.log("Enter: setSplitCaps")
    #endif
    queue.async {
      self.splitCaps = b
    }
  }

  func getSplitCaps() -> Bool {
    #if DEBUG
      DebugLogger.log("Enter: getSplitCaps")
    #endif
    return queue.sync {
      return self.splitCaps
    }
  }

  func setBeepCaps(_ b: Bool) {
    #if DEBUG
      DebugLogger.log("Enter: setBeepCaps")
    #endif
    queue.async {
      self.beepCaps = b
    }
  }

  func getBeepCaps() -> Bool {
    #if DEBUG
      DebugLogger.log("Enter: getBeepCaps")
    #endif
    return queue.sync {
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
  #if DEBUG
    DebugLogger.log("in playPureTone")
  #endif
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

// Entry point and main loop
func main() async {
  #if DEBUG
    DebugLogger.log("Enter: main")
  #endif
  #if DEBUG
    await say("Debugging swift mac server for e mac speak", interupt: true)
  #else
    await say("welcome to e mac speak with swift mac", interupt: true)
  #endif
  while let l = readLine() {
    #if DEBUG
      DebugLogger.log("got line \(l)")
    #endif
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
    case "tts_allcaps_beep": await ttsAllCapsBeep(l)
    default: await unknownLine(l)
    }
  }
}

// This is replacements that always must happen when doing
// replaceements like [*] -> slnc
func replaceCore(_ line: String) -> String {
  #if DEBUG
    DebugLogger.log("Enter: replaceCore")
  #endif
  return
    line
    .replacingOccurrences(of: "[*]", with: " [[slnc 50]] ")
}

// This is used for "none" puncts
func replaceBasePuncs(_ line: String) -> String {
  #if DEBUG
    DebugLogger.log("Enter: replaceBasePuncs")
  #endif
  let l = replaceCore(line)
  return replaceCore(l)
    .replacingOccurrences(of: "$", with: " dollar ")

}

// this is used for "some" puncts
func replaceSomePuncs(_ line: String) -> String {
  #if DEBUG
    DebugLogger.log("Enter: replaceSomePuncs")
  #endif
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

// this is used for "all" puncts
func replaceAllPuncs(_ line: String) -> String {
  #if DEBUG
    DebugLogger.log("Enter: replaceAllPuncs")
  #endif
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
  #if DEBUG
    DebugLogger.log("Enter: ttsSplitCaps")
  #endif
  let l = await isolateCommand(line)
  if l == "1" {
    ss.setSplitCaps(true)
  } else {
    ss.setSplitCaps(false)
  }
}

func ttsReset() async {
  #if DEBUG
    DebugLogger.log("Enter: ttsReset")
  #endif
  speaker.stopSpeaking()
  ss.clearBacklog()
  let voice = NSSpeechSynthesizer.VoiceName(
    rawValue: "com.apple.speech.synthesis.voice.Alex")
  if !speaker.setVoice(voice) {
    speaker.setVoice(defaultVoice)
  }
  speaker.rate = defaultRate
  speaker.volume = await voiceVolume
  ss.setCharScale(defaultCharScale)
  ss.setPunct(defaultPunct)
}

func sayVersion() async {
  #if DEBUG
    DebugLogger.log("Enter: sayVersion")
  #endif
  await say("Running \(name) version \(version)", interupt: true)
}

func sayLetter(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: sayLetter")
  #endif
  let letter = await isolateParams(line)
  let charRate = speaker.rate * ss.getCharScale()

  await say(
    "[[rate \(charRate)]][[char ltrl]]\(letter)[[rset 0]]",
    interupt: true,
    code: true
  )
}

func saySilence(_ line: String, duration: Int = 50) async {
  #if DEBUG
    DebugLogger.log("Enter: saySilence")
  #endif
  await say("[[slnc \(duration)]]", interupt: false)
}

func ttsPause() async {
  #if DEBUG
    DebugLogger.log("Enter: ttsPause")
  #endif
  speaker.pauseSpeaking(at: .immediateBoundary)
}

func ttsResume() async {
  #if DEBUG
    DebugLogger.log("Enter: ttsResume")
  #endif
  speaker.continueSpeaking()
}

func ttsSetCharacterScale(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: ttsSetCharacterScale")
  #endif
  let l = await isolateParams(line)
  if let fl = Float(l) {
    ss.setCharScale(fl)
  }
}

func ttsSetPunctuations(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: ttsSetPunctuations")
  #endif
  let l = await isolateParams(line)
  ss.setPunct(l)
}

func ttsSetRate(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: ttsSetRate")
  #endif
  let l = await isolateParams(line)
  if let fl = Float(l) {
    speaker.rate = fl
  }
}

func ttSplitCaps(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: ttSplitCaps")
  #endif
  let l = await isolateParams(line)
  if l == "1" {
    ss.setSplitCaps(true)
  } else {
    ss.setSplitCaps(false)
  }
}

func ttsAllCapsBeep(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: ttsAllCapsBeep")
  #endif
  let l = await isolateParams(line)
  if l == "1" {
    ss.setBeepCaps(true)
  } else {
    ss.setBeepCaps(false)
  }
}

func ttsSyncState(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: ttsSyncState")
  #endif
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
  #if DEBUG
    DebugLogger.log("Enter: playTone")
  #endif
  let p = await isolateParams(line)
  let ps = p.split(separator: " ")
  await playPureTone(
    frequencyInHz: Int(ps[0]) ?? 500,
    amplitude: toneVolume,
    durationInMillis: Int(ps[1]) ?? 75
  )
  #if DEBUG
    DebugLogger.log("playTone failure")
  #endif
}

func stopSpeaker() async {
  #if DEBUG
    DebugLogger.log("Enter: stopSpeaker")
  #endif
  ss.clearBacklog()
  speaker.stopSpeaking()
}

func dispatchSpeaker() async {
  #if DEBUG
    DebugLogger.log("Enter: dispatchSpeaker")
  #endif
  let s = ss.popBacklog()
  #if DEBUG
    DebugLogger.log("speaking: \(s)")
  #endif
  speaker.startSpeaking(s)
}

func queueSpeaker(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: queueSpeaker")
  #endif
  let p = await isolateParams(line)
  ss.pushBacklog(p)
}

func queueCode(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: queueCode")
  #endif
  let p = await isolateParams(line)
  ss.pushBacklog(p, code: true)
}

// Does the same thing as "p " so route it over to playSound
func playAudioIcon(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: playAudioIcon")
  #endif
  #if DEBUG
    DebugLogger.log("Playing audio icon: " + line)
  #endif
  await playSound(line)
}

func playSound(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: playSound")
  #endif
  let p = await isolateParams(line)
  let soundURL = URL(fileURLWithPath: p)
  let sound = NSSound(contentsOf: soundURL, byReference: true)
  sound?.volume = await soundVolume
  sound?.play()
}

func ttsSay(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: ttsSay")
  #endif
  #if DEBUG
    DebugLogger.log("ttsSay: " + line)
  #endif
  let p = await isolateParams(line)
  await say(p, interupt: true)

}

func say(
  _ what: String,
  interupt: Bool = false,
  code: Bool = false
) async {
  #if DEBUG
    DebugLogger.log("Enter: say")
  #endif
  var w = stripSpecialEmbeds(what)
  if !code {
    switch ss.getPunct().lowercased() {
    case "all":
      w = replaceAllPuncs(w)
    case "some":
      w = replaceSomePuncs(w)
    case "none":
      w = replaceBasePuncs(w)
    default:
      w = replaceCore(w)
    }
  }
  if interupt {
    #if DEBUG
      DebugLogger.log("speaking: \(w)")
    #endif
    speaker.startSpeaking(w)
  } else {
    if speaker.isSpeaking {
      ss.pushBacklog(w)
    } else {
      #if DEBUG
        DebugLogger.log("say:startSpeaking: \(w)")
      #endif
      speaker.startSpeaking(w)
    }
  }
}

func unknownLine(_ line: String) async {
  #if DEBUG
    DebugLogger.log("Enter: unknownLine")
  #endif
  #if DEBUG
    DebugLogger.log("Unknown command: " + line)
  #endif
}

func ttsExit() async {
  #if DEBUG
    DebugLogger.log("Enter: ttsExit")
  #endif
  exit(0)
}

func stripSpecialEmbeds(_ line: String) -> String {
  #if DEBUG
    DebugLogger.log("Enter: stripSpecialEmbeds")
  #endif
  let specialEmbedRegexp = #"\[\{.*?\}\]"#
  return voiceToReset(line).replacingOccurrences(
    of: specialEmbedRegexp,
    with: "", options: .regularExpression)
}

// So, it turns out we get spammed with voice often as a form of a
// reset of the voice engine, good news is we have that command
// built right in
func voiceToReset(_ line: String) -> String {
  #if DEBUG
    DebugLogger.log("Enter: voiceToReset")
  #endif
  let specialEmbedRegexp = #"\[\{voice.*?\}\]"#
  return line.replacingOccurrences(
    of: specialEmbedRegexp,
    with: " [[rset 0]] ", options: .regularExpression)
}

func isolateCommand(_ line: String) async -> String {
  #if DEBUG
    DebugLogger.log("Enter: isolateCommand")
  #endif
  var cmd = line.trimmingCharacters(in: .whitespacesAndNewlines)
  if let firstIndex = cmd.firstIndex(of: " ") {
    cmd.replaceSubrange(firstIndex..<cmd.endIndex, with: "")
    return cmd
  }
  return cmd
}

func isolateParams(_ line: String) async -> String {
  #if DEBUG
    DebugLogger.log("Enter: isolateParams")
  #endif
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
// compile-command: "swift build"
// end:
