import AVFoundation
import AppKit
import Darwin
import Foundation
import OggDecoder

/* Globals */
#if DEBUG
  let currentDate = Date()
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy-MM-dd_HH_mm_ss"
  let timestamp = dateFormatter.string(from: currentDate)
  let debugLogger = Logger(fileName: "swiftmac-debug-\(timestamp)")
#else
  let debugLogger = Logger()  // No-Op
#endif
let version = "2.2.0"  // think this is first bug free 2.0
let name = "swiftmac"
var ss = await StateStore()  // just create new one to reset
let speaker = AVSpeechSynthesizer()
let tonePlayer = TonePlayerActor()

// notification support
let engine = AVAudioEngine()
let playerNode = AVAudioPlayerNode()
let environmentNode = AVAudioEnvironmentNode()
// Define a closure to handle the output buffer
var outputFormat: AVAudioFormat?
let bufferHandler: (AVAudioBuffer) -> Void = { buffer in
  guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

  if pcmBuffer.frameLength > 0 {
    if outputFormat == nil {
      outputFormat = pcmBuffer.format
      engine.connect(playerNode, to: environmentNode, format: outputFormat)
      engine.connect(environmentNode, to: engine.mainMixerNode, format: nil)
      Task {
        if await ss.audioTarget == "right" {
          playerNode.position = AVAudio3DPoint(x: 1, y: 0, z: 0)
        }
        if await ss.audioTarget == "left" {
          playerNode.position = AVAudio3DPoint(x: -1, y: 0, z: 0)
        }
      }
      engine.prepare()

      do {
        try engine.start()
      } catch {
        print("Error starting audio engine: \(error.localizedDescription)")
        return
      }
    }

    // Schedule the buffer for playback
    playerNode.scheduleBuffer(pcmBuffer)

    if !playerNode.isPlaying {
      playerNode.play()
    }
  }
}

func notificationMode() async -> Bool {
  let at = await ss.audioTarget.lowercased()
  if at == "right" {
    return true
  }
  if at == "left" {
    return true
  }
  return false
}

/* EntryPoint */
func main() async {
  debugLogger.log("Enter: main")

  if await notificationMode() {
    await instantTtsSay("notification mode on")

    // Setup notification audio routing
    engine.attach(playerNode)
    engine.attach(environmentNode)

  } else {
    await instantVersion()
  }

  while let l = readLine() {
    debugLogger.log("got line \(l)")
    let (cmd, params) = await isolateCmdAndParams(l)
    switch cmd {
    case "a": await processAndQueueAudioIcon(params)
    case "c": await doDiscard(cmd, params)
    case "d": await dispatchPendingQueue()
    case "l": await instantLetter(params)
    case "p": await doPlaySound(params)
    case "q": await queueLine(cmd, params)
    case "s": await queueLine(cmd, params)
    case "sh": await queueLine(cmd, params)
    case "t": await queueLine(cmd, params)
    case "tts_allcaps_beep": await queueLine(cmd, params)
    case "set_lang": await ttsSetVoice(params) 
    case "tts_exit": await instantTtsExit()
    case "tts_reset": await instantTtsReset()
    case "tts_say": await instantTtsSay(params)
    case "tts_set_character_scale": await queueLine(cmd, params)
    case "tts_set_pitch_multiplier": await queueLine(cmd, params)
    case "tts_set_punctuations": await queueLine(cmd, params)
    case "tts_set_sound_volume": await queueLine(cmd, params)
    case "tts_set_speech_rate": await instantSetSpeechRate(params)
    case "tts_set_tone_volume": await queueLine(cmd, params)
    case "tts_set_voice": await queueLine(cmd, params)
    case "tts_set_voice_volume": await queueLine(cmd, params)
    case "tts_split_caps": await queueLine(cmd, params)
    case "tts_sync_state": await doDiscard(cmd, params)
    case "version": await instantVersion()
    default: await unknownLine(cmd, params)
    }
  }
}

func doDiscard(_ cmd: String, _ params: String) async {
  debugLogger.log("Intentionally disposed: \(cmd) \(params)")
}

func dispatchPendingQueue() async {
  while let (cmd, params) = await ss.popFromPendingQueue() {
    debugLogger.log("got queued \(cmd) \(params)")
    switch cmd {
    case "p": await doPlaySound(params)  // just like p in mainloop
    case "q": await doSpeak(params)
    case "s": await doStopSpeaking()
    case "sh": await doSilence(params)
    case "t": await doTone(params)
    case "tts_allcaps_beep": await ttsAllCapsBeep(params)
    case "tts_set_character_scale": await ttsSetCharacterScale(params)
    case "tts_set_pitch_multiplier": await ttsSetPitchMultiplier(params)
    case "tts_set_punctuations": await ttsSetPunctuations(params)
    case "tts_set_sound_volume": await ttsSetSoundVolume(params)
    case "tts_set_tone_volume": await ttsSetToneVolume(params)
    case "tts_set_voice": await ttsSetVoice(params)
    case "tts_set_voice_volume": await ttsSetVoiceVolume(params)
    case "tts_split_caps": await ttsSplitCaps(params)
    default: await impossibleQueue(cmd, params)
    }
  }
}

func queueLine(_ cmd: String, _ params: String) async {
  debugLogger.log("Enter: queueLine")
  await ss.appendToPendingQueue((cmd, params))
}

func splitOnSquareStar(_ input: String) async -> [String] {
  let separator = "[*]"
  var result: [String] = []

  let parts = input.components(separatedBy: separator)
  for (index, part) in parts.enumerated() {
    result.append(part)
    // Add the separator back except after the last part
    if index < parts.count - 1 {
      result.append(separator)
    }
  }

  return result
}

func insertSpaceBeforeUppercase(_ input: String) -> String {
  debugLogger.log("Enter: insertSpaceBeforeUppercase")
  let pattern = "(?<=[a-z])(?=[A-Z])"
  let regex = try! NSRegularExpression(pattern: pattern, options: [])
  let range = NSRange(input.startIndex..., in: input)
  let modifiedString = regex.stringByReplacingMatches(
    in: input, options: [], range: range, withTemplate: " ")
  return modifiedString
}

@MainActor func instantTtsReset() async {
  debugLogger.log("Enter: instantTtsReset")
  await doStopAll()
  ss = await StateStore()
}

func instantVersion() async {
  debugLogger.log("Enter: instantVersion")
  let sayVersion = version.replacingOccurrences(of: ".", with: " dot ")

  await doStopAll()
  #if DEBUG
    await instantTtsSay("\(name) \(sayVersion): debug mode")
  #else
    await instantTtsSay("\(name) \(sayVersion)")
  #endif
}

func doSilence(_ p: String) async {
  debugLogger.log("Enter: doSilence")
  let oldPostDelay = await ss.postDelay
  if let timeInterval = TimeInterval(p) {
    await ss.setPostDelay(timeInterval / 1000)
  }
  await doSpeak("")
  await ss.setPostDelay(oldPostDelay)
}

func instantTtsResume() async {
  debugLogger.log("Enter: instantTtsResume")
  speaker.continueSpeaking()
}

func instantLetter(_ p: String) async {
  debugLogger.log("Enter: unknownLine")
  let oldPitchMultiplier = await ss.pitchMultiplier
  let oldPreDelay = await ss.preDelay
  if isFirstLetterCapital(p) {
    if await ss.allCapsBeep {
      await doTone("500 50")
    } else {
      await ss.setPitchMultiplier(1.5)
    }
  }
  let oldSpeechRate = await ss.speechRate
  await ss.setSpeechRate(await ss.getCharacterRate())
  await doStopSpeaking()
  await doSpeak(p.lowercased())
  await ss.setPitchMultiplier(oldPitchMultiplier)
  await ss.setSpeechRate(oldSpeechRate)
  await ss.setPreDelay(oldPreDelay)
}

func doStopSpeaking() async {
  debugLogger.log("Enter: doStopSpeaking")
  speaker.stopSpeaking(at: .immediate)
  playerNode.stop()
}

func isFirstLetterCapital(_ str: String) -> Bool {
  debugLogger.log("Enter: isFirstLetterCapital")
  guard str.count > 0 else {
    return false
  }

  let firstChar = str.first!
  return firstChar.isUppercase && firstChar.isLetter
}

func instantTtsPause() async {
  debugLogger.log("Enter: instantTtsPause")
  speaker.pauseSpeaking(at: .immediate)
}

func unknownLine(_ cmd: String, _ params: String) async {
  debugLogger.log("Enter: unknownLine")
  debugLogger.log("Unknown command: '\(cmd)' '\(params)'")
  print("Unknown command: '\(cmd)' '\(params)'")
}

func impossibleQueue(_ cmd: String, _ params: String) async {
  debugLogger.log("Enter: impossibleQueue")
  debugLogger.log("Impossible queue item '\(cmd)' '\(params)'")
  print("Impossible queue item '\(cmd)' '\(params)'")
}

func extractVoice(_ string: String) -> String? {
  debugLogger.log("Enter: extractVoice")
  let pattern = "\\[\\{voice\\s+([^\\}]+)\\}\\]"
  let regex = try! NSRegularExpression(pattern: pattern, options: [])

  let matches = regex.matches(
    in: string, options: [], range: NSRange(location: 0, length: string.utf16.count))

  guard let match = matches.first else {
    return nil
  }

  let range = Range(match.range(at: 1), in: string)!
  return String(string[range])
}

func processAndQueueAudioIcon(_ p: String) async {
  debugLogger.log("Enter: processAndQueueAudioIcon")
  await ss.appendToPendingQueue(("p", p))
  await ss.appendToPendingQueue(("d", ""))
}

func processAndQueueCodes(_ p: String) async {
  debugLogger.log("Enter: processAndQueueCodes")
  if let v = extractVoice(p) {
    await ss.appendToPendingQueue(("tts_set_voice", v))
  }
}

func replacePunctuations(_ s: String) async -> String {
  if await ss.punctuations == "all" {
    return replaceAllPuncs(s)
  }
  if await ss.punctuations == "some" {
    return replaceSomePuncs(s)
  }
  return replaceBasePuncs(s)
}

/* This is used for "none" puncts */
func replaceBasePuncs(_ line: String) -> String {
  debugLogger.log("Enter: replaceBasePuncs")
  return
    line
    .replacingOccurrences(of: "%", with: " percent ")
    .replacingOccurrences(of: "$", with: " dollar ")

}

/* this is used for "some" puncts */
func replaceSomePuncs(_ line: String) -> String {
  debugLogger.log("Enter: replaceSomePuncs")
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

/* this is used for "all" puncts */
func replaceAllPuncs(_ line: String) -> String {
  debugLogger.log("Enter: replaceAllPuncs")
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

func ttsSplitCaps(_ p: String) async {
  debugLogger.log("Enter: ttsSplitCaps")
  if p == "1" {
    await ss.setSplitCaps(true)
  } else {
    await ss.setSplitCaps(false)
  }
}

func ttsSetVoice(_ p: String) async {
  debugLogger.log("Enter: ttsSetVoice")
  let ps = p.split(separator: " ")
  if ps.count == 1 {
    let langvoice = String(ps[0])
    await ss.setVoice(langvoice)
  }
  if ps.count == 2 {
    let langvoice = String(ps[0])
    await ss.setVoice(langvoice)
    if ps[1] == "t" {
      await doSpeak("Switched to \(langvoice)")
    }
  }
}

func ttsSetToneVolume(_ p: String) async {
  debugLogger.log("Enter: ttsSetToneVolume")
  if let f = Float(p) {
    await ss.setToneVolume(f)
  }
}

func ttsSetSoundVolume(_ p: String) async {
  debugLogger.log("Enter: ttsSetSoundVolume")
  if let f = Float(p) {
    await ss.setSoundVolume(f)
  }
}

func ttsSetVoiceVolume(_ p: String) async {
  debugLogger.log("Enter: ttsSetVoiceVolume")
  if let f = Float(p) {
    await ss.setVoiceVolume(f)
  }
}

func instantSetSpeechRate(_ p: String) async {
  debugLogger.log("Enter: instantSetSpeechRate")
  if let f = Float(p) {
    await ss.setSpeechRate(f)
  }
}

func ttsSetPitchMultiplier(_ p: String) async {
  debugLogger.log("Enter: ttsSetPitchMultiplier")
  if let f = Float(p) {
    await ss.setPitchMultiplier(f)
  }
}

func ttsSetPunctuations(_ p: String) async {
  debugLogger.log("Enter: ttsSetPunctuations")
  await ss.setPunctuations(p)
}

func ttsSetCharacterScale(_ p: String) async {
  debugLogger.log("Enter: ttsSetCharacterScale")
  if let f = Float(p) {
    await ss.setCharacterScale(f)
  }
}

func ttsAllCapsBeep(_ p: String) async {
  debugLogger.log("Enter: ttsAllCapsBeep")
  if p == "1" {
    await ss.setAllCapsBeep(true)
  } else {
    await ss.setAllCapsBeep(false)
  }
}

func processAndQueueSync(_ p: String) async {
  debugLogger.log("Enter: processAndQueueSync")
  let ps = p.split(separator: " ")
  if ps.count == 4 {
    let punct = String(ps[0])
    await ss.appendToPendingQueue(("tts_set_punctuations", punct))

    let splitCaps = String(ps[1])
    await ss.appendToPendingQueue(("tts_split_caps", splitCaps))

    let beepCaps = String(ps[2])
    await ss.appendToPendingQueue(("tts_allcaps_beep", beepCaps))

    let rate = String(ps[3])
    await ss.appendToPendingQueue(("tts_set_speech_rate", rate))
  }
}

func doTone(_ p: String) async {
  debugLogger.log("Enter: doTone")
  let ps = p.split(separator: " ")
  Task {
    await tonePlayer.playPureTone(
      frequencyInHz: Int(ps[0]) ?? 500,
      amplitude: await ss.toneVolume,
      durationInMillis: Int(ps[1]) ?? 75
    )
  }
}

func doPlaySound(_ p: String) async {
  debugLogger.log("Enter: doPlaySound")
  let soundURL = URL(fileURLWithPath: p)

  let savedWavUrl: URL? = await withCheckedContinuation { continuation in
    if soundURL.pathExtension.lowercased() == "ogg" {
      debugLogger.log("Decoding OGG file at URL: \(soundURL)")
      let decoder = OGGDecoder()
      decoder.decode(soundURL) { savedWavUrl in
        continuation.resume(returning: savedWavUrl)
      }
    } else {
      continuation.resume(returning: soundURL)
    }
  }

  guard let url = savedWavUrl else {
    debugLogger.log("Failed to get audio file URL from path: \(p)")
    return
  }

  let volume = await ss.soundVolume  // Assuming this is efficient to call frequently.
  await SoundManager.shared.playSound(from: url, volume: volume)
}

func instantTtsSay(_ p: String) async {
  debugLogger.log("Enter: instantTtsSay")
  debugLogger.log("ttsSay: \(p)")
  await doStopAll()
  await doSpeak(p)
}

func doStopAll() async {
  debugLogger.log("Enter: doStopAll")
  await doStopSpeaking()
  await tonePlayer.stop()
  await SoundManager.shared.stopCurrentSound()
}

// Because all speaking must handle [*]
func doSpeak(_ what: String) async {
  let parts = await splitOnSquareStar(what)
  for part in parts {
    if part == "[*]" {
      await doSilence("0")
    } else {
      let speakPart = await replacePunctuations(part)
      await _doSpeak(speakPart)
    }
  }
}

func splitStringAtSpaceBeforeCapitalLetter(_ input: String) async -> [String] {
  // Regular expression pattern to match a space followed by an uppercase letter
  // Using lookbehind and lookahead to ensure the uppercase letter is not consumed during split
  let pattern = "(?<=\\s)(?=[A-Z])"

  // Attempt to create a regular expression
  guard let regex = try? NSRegularExpression(pattern: pattern) else {
    // If regex can't be created, return the original string in an array as a fallback
    return [input]
  }

  // Use the regular expression to find matches, which are the split points in the string
  let range = NSRange(input.startIndex..., in: input)
  let matches = regex.matches(in: input, options: [], range: range)

  var results = [String]()
  var lastEndIndex = input.startIndex
  // Iterate through the matches to split the string
  for match in matches {
    let matchRange = Range(match.range, in: input)!
    // Add substring from last match end to current match start
    results.append(String(input[lastEndIndex..<matchRange.lowerBound]))
    lastEndIndex = matchRange.lowerBound
  }
  // Add the remaining part of the string after the last match
  results.append(String(input[lastEndIndex...]))

  return results
}

func _doSpeak(_ what: String) async {
  debugLogger.log("Enter: _doSpeak :: '\(what)'")

  var temp: String
  if await ss.splitCaps {
    temp = insertSpaceBeforeUppercase(what)
  } else {
    temp = what
  }
  let utterance = AVSpeechUtterance(string: temp)

  // Set the rate of speech (0.5 to 1.0)
  utterance.rate = await ss.speechRate

  // Set the pitch multiplier (0.5 to 2.0)
  utterance.pitchMultiplier = await ss.pitchMultiplier

  // Set the volume (0.0 to 1.0)
  utterance.volume = await ss.voiceVolume

  // Set the pre-utterance delay (in seconds)
  utterance.preUtteranceDelay = await ss.preDelay

  // Set the post-utterance delay (in seconds)
  utterance.postUtteranceDelay = await ss.postDelay

  // Set the voice
  utterance.voice = await ss.voice

  // Start speaking
  if await notificationMode() {
    DispatchQueue.global().async {
      speaker.write(utterance, toBufferCallback: bufferHandler)
    }
  } else {
    speaker.speak(utterance)
  }

}

func instantTtsExit() async {
  debugLogger.log("Enter: instantTtsExit")
  exit(0)
}

func isolateCommand(_ line: String) async -> String {
  debugLogger.log("Enter: isolateCommand")
  var cmd = line.trimmingCharacters(in: .whitespacesAndNewlines)
  if let firstIndex = cmd.firstIndex(of: " ") {
    cmd.replaceSubrange(firstIndex..<cmd.endIndex, with: "")
    return cmd
  }
  return cmd
}

func isolateCmdAndParams(_ line: String) async -> (String, String) {
  debugLogger.log("Enter: isolateParams")
  let justCmd = await isolateCommand(line)
  let cmd = justCmd + " "

  var params = line.replacingOccurrences(of: "^" + cmd, with: "", options: .regularExpression)
  params = params.trimmingCharacters(in: .whitespacesAndNewlines)
  if params.hasPrefix("{") && params.hasSuffix("}") {
    if let lastIndex = params.lastIndex(of: "}") {
      params.replaceSubrange(lastIndex...lastIndex, with: "")
    }
    if let firstIndex = params.firstIndex(of: "{") {
      params.replaceSubrange(firstIndex...firstIndex, with: "")
    }
  }
  debugLogger.log("Exit: isolateParams: \(params)")
  return (justCmd, params)
}

await main()
