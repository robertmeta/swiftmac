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
  let debugLogger = Logger(fileName: "swiftmac-debug-\(timestamp).log")
#else
  let debugLogger = Logger()  // No-Op
#endif
let version = "2.0.0"
let name = "swiftmac"
var ss = await StateStore()  // just create new one to reset
let speaker = AVSpeechSynthesizer()
let tonePlayer = TonePlayerActor()

/* EntryPoint */
func main() async {
  debugLogger.log("Enter: main")
  await instantSayVersion()

  while let l = readLine() {
    debugLogger.log("got line \(l)")
    let (cmd, params) = await isolateCmdAndParams(l)
    switch cmd {
    case "a": await processAndQueueAudioIcon(params)
    case "c": await processAndQueueCodes(l)
    case "d": await dispatchPendingQueue()
    case "l": await instantSayLetter(params)
    case "p": await doPlaySound(params)
    case "q": await processAndQueueSpeech(params)
    case "s": await queueLine(cmd, params)
    case "sh": await queueLine(cmd, params)
    case "t": await queueLine(cmd, params)
    case "version": await instantSayVersion()
    case "tts_exit": await instantTtsExit()
    case "tts_pause": await instantTtsPause()
    case "tts_reset": await instantTtsReset()
    case "tts_resume": await instantTtsResume()
    case "tts_say": await instantTtsSay(params)
    case "tts_set_character_scale": await queueLine(cmd, params)
    case "tts_set_punctuations": await queueLine(cmd, params)
    case "tts_set_speech_rate": await queueLine(cmd, params)
    case "tts_split_caps": await queueLine(cmd, params)
    case "tts_sync_state": await processAndQueueSync(l)
    case "tts_allcaps_beep": await queueLine(cmd, params)
    case "tts_set_voice": await queueLine(cmd, params)
    case "tts_set_pitch_multiplier": await queueLine(cmd, params)
    default: await unknownLine(l)
    }
  }
}

func dispatchPendingQueue() async {
  while let (cmd, params) = await ss.popFromPendingQueue() {
    debugLogger.log("got queued \(cmd) \(params)")
    switch cmd {
    case "p": await doPlaySound(params)  // just like p in mainloop
    case "s": await doStopAll()
    case "sh": await doSilence(params)
    case "t": await doPlayTone(params)
    case "tts_set_character_scale": await setCharacterScale(params)
    case "tts_set_punctuations": await setPunctuations(params)
    case "tts_set_speech_rate": await setSpeechRate(params)
    case "tts_set_voice": await setVoice(params)
    case "tts_set_pitch_multiplier": await setPitchMultiplier(params)
    case "tts_split_caps": await setSplitCaps(params)
    case "tts_allcaps_beep": await setAllCapsBeep(params)
    default: await impossibleQueue(cmd, params)
    }
  }
}

func queueLine(_ cmd: String, _ params: String) async {
  debugLogger.log("Enter: queueLine")
  await ss.appendToPendingQueue((cmd, params))
}

func processAndQueueSpeech(_ p: String) async {

}

@MainActor func instantTtsReset() async {
  await doStopAll()
  ss = await StateStore()
}

func instantSayVersion() async {
  let sayVersion = version.replacingOccurrences(of: ".", with: " dot ")

  await doStopAll()
  #if DEBUG
    await instantTtsSay("\(name) \(sayVersion): debug mode")
  #else
    await instantTtsSay("\(name) \(sayVersion)")
  #endif
}

func doSilence(_ p: String) async {
  let oldPostDelay = await ss.postDelay
  if let timeInterval = TimeInterval(p) {
    await ss.setPostDelay(timeInterval / 1000)
  }
  await doSpeak("")
  await ss.setPostDelay(oldPostDelay)
}

func instantTtsResume() async {
  speaker.continueSpeaking()
}

func instantSayLetter(_ p: String) async {
  let oldPitchMultiplier = await ss.pitchMultiplier
  let oldPreDelay = await ss.preDelay
  print("acb: ", await ss.allCapsBeep)
  if isCapitalLetter(p) {
    // TODO: Remove this hardcoding
    if await ss.allCapsBeep {
      await doPlayTone("500 50")
    } else {
      await ss.setPitchMultiplier(1.5)
    }
  }
  let oldSpeechRate = await ss.speechRate
  await ss.setSpeechRate(await ss.getCharacterRate())
  await stopSpeaking()
  await doSpeak(p.lowercased())
  await ss.setPitchMultiplier(oldPitchMultiplier)
  await ss.setSpeechRate(oldSpeechRate)
  await ss.setPreDelay(oldPreDelay)
}

func stopSpeaking() async {
  speaker.stopSpeaking(at: .immediate)
}

func isCapitalLetter(_ str: String) -> Bool {
  guard str.count == 1 else {
    return false
  }

  let firstChar = str.first!
  return firstChar.isUppercase && firstChar.isLetter
}

func instantTtsPause() async {
  speaker.pauseSpeaking(at: .immediate)
}

func unknownLine(_ line: String) async {
  debugLogger.log("Enter: unknownLine")
  debugLogger.log("Unknown command: \(line)")
  print("Unknown command: \(line)")
}

func getVoiceIdentifier(voiceName: String) -> String {
  let defaultVoiceIdentifier = "com.apple.speech.voice.Alex"

  let voices = AVSpeechSynthesisVoice.speechVoices()

  // Check if the voiceName is in the long format (e.g., com.apple.ttsbundle.Samantha-compact)
  if let voice = voices.first(where: { $0.identifier == voiceName }) {
    return voice.identifier
  }

  // Check if the voiceName is in the short format (e.g., Samantha)
  if let voice = voices.first(where: { $0.name == voiceName }) {
    return voice.identifier
  }

  // If the voiceName is not found, return the default voice identifier
  return defaultVoiceIdentifier
}

func impossibleQueue(_ cmd: String, _ params: String) async {
  debugLogger.log("Enter: impossibleQueue")
  debugLogger.log("Impossible queue item '\(cmd)' '\(params)'")
  print("Impossible queue item '\(cmd)' '\(params)'")
}

func extractVoice(_ string: String) -> String? {
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
}

func processAndQueueCodes(_ p: String) async {
  debugLogger.log("Enter: processAndQueueCodes")
  if let v = extractVoice(p) {
      await ss.appendToPendingQueue(("tts_set_voice", v))
  }
}

/* This is replacements that always must happen when doing
   replaceements like [*] -> slnc */
func replaceCore(_ line: String) -> String {
  debugLogger.log("Enter: replaceCore")
  return
    line
    .replacingOccurrences(of: "[*]", with: " [[slnc 50]] ")
}

/* This is used for "none" puncts */
func replaceBasePuncs(_ line: String) -> String {
  debugLogger.log("Enter: replaceBasePuncs")
  let l = replaceCore(line)
  return replaceCore(l)
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

func setSplitCaps(_ p: String) async {
  debugLogger.log("Enter: setSplitCaps")
  if p == "1" {
    await ss.setSplitCaps(true)
  } else {
    await ss.setSplitCaps(false)
  }
}

func setVoice(_ p: String) async {
  debugLogger.log("Enter: setVoice")
  await ss.setVoice(p)
}

func setSpeechRate(_ p: String) async {
  debugLogger.log("Enter: setSpeechRate")
  if let f = Float(p) {
    await ss.setSpeechRate(f)
  }
}

func setPitchMultiplier(_ p: String) async {
  debugLogger.log("Enter: setPitchMultiplier")
  if let f = Float(p) {
    await ss.setPitchMultiplier(f)
  }
}


func setPunctuations(_ p: String) async {
  debugLogger.log("Enter: setPunctuations")
  await ss.setPunctuations(p)
}

func setCharacterScale(_ p: String) async {
  debugLogger.log("Enter: setCharacterScale")
  if let f = Float(p) {
    await ss.setCharacterScale(f)
  }
}

func setAllCapsBeep(_ p: String) async {
  debugLogger.log("Enter: setAllCapsBeep")
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

func doPlayTone(_ p: String) async {
  print("Enter: doPlayTone")
  debugLogger.log("Enter: doPlayTone")
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
      let decoder = OGGDecoder()
      decoder.decode(soundURL) { savedWavUrl in
        continuation.resume(returning: savedWavUrl)
      }
    } else {
      continuation.resume(returning: soundURL)
    }
  }

  guard let url = savedWavUrl else {
    print("Failed to get audio file URL")
    return
  }

  await SoundManager.shared.playSound(from: url, volume: await ss.soundVolume)
}

func instantTtsSay(_ p: String) async {
  debugLogger.log("Enter: instantTtsSay")
  debugLogger.log("ttsSay: \(p)")
  await doStopAll()
  await doSpeak(p)
  print("instantTtsSay")
}

func doStopAll() async {
  speaker.stopSpeaking(at: .immediate)
  await tonePlayer.stop()
  await SoundManager.shared.stopCurrentSound()

}

func doSpeak(_ what: String) async {
  let utterance = AVSpeechUtterance(string: what)

  // Set the rate of speech (0.5 to 1.0)
  utterance.rate = await ss.speechRate

  // Set the pitch multiplier (0.5 to 2.0)
  utterance.pitchMultiplier = await ss.pitchMultiplier
  print("Utterance pm: \(utterance.pitchMultiplier)")

  // Set the volume (0.0 to 1.0)
  utterance.volume = await ss.voiceVolume

  // Set the pre-utterance delay (in seconds)
  utterance.preUtteranceDelay = await ss.preDelay

  // Set the post-utterance delay (in seconds)
  utterance.postUtteranceDelay = await ss.postDelay

  // Set the voice
  // TODO: Move this to statestore and change type to a voice
  let voiceIdentifier = getVoiceIdentifier(voiceName: await ss.voice)
  if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
    utterance.voice = voice
  }

  // Start speaking
  speaker.speak(utterance)

}

// func doSay(
//   _ what: String,
// ) async {
//   debugLogger.log("Enter: doSay")
//   switch await ss.getPunct().lowercased() {
//     case "all":
//       w = replaceAllPuncs(w)
//     case "some":
//       w = replaceSomePuncs(w)
//     case "none":
//       w = replaceBasePuncs(w)
//     default:
//       w = replaceCore(w)
//     }
//   }
//   # TODO Speak w
// }

func instantTtsExit() async {
  debugLogger.log("Enter: instantTtsExit")
  exit(0)
}

// func stripSpecialEmbeds(_ line: String) -> String {
//   debugLogger.log("Enter: stripSpecialEmbeds")
//   let specialEmbedRegexp = #"\[\{.*?\}\]"#
//   return voiceToReset(line).replacingOccurrences(
//     of: specialEmbedRegexp,
//     with: "", options: .regularExpression)
// }

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
