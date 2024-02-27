import AVFoundation
import AppKit
import Darwin
import Foundation
import OggDecoder

/* Global Constants */
let version = "1.0.8"
let name = "swiftmac"
let speaker = NSSpeechSynthesizer()
let defaultRate: Float = 200
let defaultCharScale: Float = 1.1
let defaultVoice = NSSpeechSynthesizer.defaultVoice
let defaultPunct = "all"
let defaultSplitCaps = false
let defaultBeepCaps = false
var soundVolume: Float = 1.0
var toneVolume: Float = 1.0
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

#if DEBUG
  let currentDate = Date()
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy-MM-dd_HH_mm_ss"
  let timestamp = dateFormatter.string(from: currentDate)
  let debugLogger = Logger(fileName: "swiftmac-debug-\(timestamp).log")

  debugLogger.log("soundVolume \(soundVolume)")
  debugLogger.log("toneVolume \(toneVolume)")
  debugLogger.log("voiceVolume \(voiceVolume)")
#else
  let debugLogger = Logger()
#endif

/* Used in the class below, so defiend here */
func splitStringBySpaceAfterLimit(_ str: String, limit: Int) -> (before: String, after: String) {
  if str.count <= limit {
    return (str, "")
  } else {
    var limitIndex = str.index(str.startIndex, offsetBy: limit)
    while limitIndex < str.endIndex {
      if str[limitIndex] == " " {
        let before = String(str[str.startIndex..<limitIndex])
        let after = String(str[limitIndex..<str.endIndex])
        return (before, after)
      }
      limitIndex = str.index(after: limitIndex)
    }
  }
  return (str, "")
}

/* This delegate class lets us continue speaking with queued data
   after a speech chunk is completed */
class DelegateHandler: NSObject, NSSpeechSynthesizerDelegate {
  @MainActor
  func speechSynthesizer(
    _ sender: NSSpeechSynthesizer,
    didFinishSpeaking finishedSpeaking: Bool
  ) async {
    if finishedSpeaking {
      let s = await ss.popBacklog()
      debugLogger.log("didFinishSpeaking:startSpeaking: \(s)")
      speaker.startSpeaking(s)
      debugLogger.log("Enter: startSpeaking")
    }
  }
}
let dh = DelegateHandler()
speaker.delegate = dh

let ss = StateStore()

/* Entry point and main loop */
func main() async {
  debugLogger.log("Enter: main")
  #if DEBUG
    await say("Debugging swift mac server for e mac speak \(version)", interupt: true)
  #else
    await say("welcome to e mac speak with swift mac \(version)", interupt: true)
  #endif
  while let l = readLine() {
    debugLogger.log("got line \(l)")
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

@MainActor
func ttsSplitCaps(_ line: String) async {
  debugLogger.log("Enter: ttsSplitCaps")
  let l = await isolateCommand(line)
  if l == "1" {
    await ss.setSplitCaps(true)
  } else {
    await ss.setSplitCaps(false)
  }
}

@MainActor
func ttsReset() async {
  debugLogger.log("Enter: ttsReset")
  speaker.stopSpeaking()
  await ss.clearBacklog()
  let voice = NSSpeechSynthesizer.VoiceName(
    rawValue: "com.apple.speech.synthesis.voice.Alex")
  if !speaker.setVoice(voice) {
    speaker.setVoice(defaultVoice)
  }
  speaker.rate = defaultRate
  speaker.volume = await voiceVolume
  await ss.setCharScale(defaultCharScale)
  await ss.setPunct(defaultPunct)
}

func sayVersion() async {
  debugLogger.log("Enter: sayVersion")
  await say("Running \(name) version \(version)", interupt: true)
}

@MainActor
func sayLetter(_ line: String) async {
  debugLogger.log("Enter: sayLetter")
  let letter = await isolateParams(line)
  let trimmedLetter = letter.trimmingCharacters(in: .whitespacesAndNewlines)
  let cs = await ss.getCharScale()
  let charRate = speaker.rate * cs
  var pitchShift = 0
  if let singleChar = trimmedLetter.first, singleChar.isUppercase {
    pitchShift = 15
    debugLogger.log("PitchShift ON")
  }

  await say(
    "[[rate \(charRate)]][[pbas +\(pitchShift)]][[char ltrl]]\(letter)[[rset 0]]",
    interupt: true,
    code: true
  )
}

func saySilence(_ line: String, duration: Int = 50) async {
  debugLogger.log("Enter: saySilence")
  await say("[[slnc \(duration)]]", interupt: false)
}

@MainActor
func ttsPause() async {
  debugLogger.log("Enter: ttsPause")
  speaker.pauseSpeaking(at: .immediateBoundary)
}

@MainActor
func ttsResume() async {
  debugLogger.log("Enter: ttsResume")
  speaker.continueSpeaking()
}

func ttsSetCharacterScale(_ line: String) async {
  debugLogger.log("Enter: ttsSetCharacterScale")
  let l = await isolateParams(line)
  if let fl = Float(l) {
    await ss.setCharScale(fl)
  }
}

func ttsSetPunctuations(_ line: String) async {
  debugLogger.log("Enter: ttsSetPunctuations")
  let l = await isolateParams(line)
  await ss.setPunct(l)
}

@MainActor
func ttsSetRate(_ line: String) async {
  debugLogger.log("Enter: ttsSetRate")
  let l = await isolateParams(line)
  if let fl = Float(l) {
    speaker.rate = fl
  }
}

func ttSplitCaps(_ line: String) async {
  debugLogger.log("Enter: ttSplitCaps")
  let l = await isolateParams(line)
  if l == "1" {
    await ss.setSplitCaps(true)
  } else {
    await ss.setSplitCaps(false)
  }
}

func ttsAllCapsBeep(_ line: String) async {
  debugLogger.log("Enter: ttsAllCapsBeep")
  let l = await isolateParams(line)
  if l == "1" {
    await ss.setBeepCaps(true)
  } else {
    await ss.setBeepCaps(false)
  }
}

@MainActor
func ttsSyncState(_ line: String) async {
  debugLogger.log("Enter: ttsSyncState")
  let l = await isolateParams(line)
  let ps = l.split(separator: " ")
  if ps.count == 4 {
    if let r = Float(ps[3]) {
      speaker.rate = r
    }

    let beepCaps = ps[2]
    if beepCaps == "1" {
      await ss.setBeepCaps(true)
    } else {
      await ss.setBeepCaps(false)
    }

    let splitCaps = ps[1]
    if splitCaps == "1" {
      await ss.setSplitCaps(true)
    } else {
      await ss.setSplitCaps(false)
    }
    let punct = ps[0]
    await ss.setPunct(String(punct))
  }
}

func playTone(_ line: String) async {
  debugLogger.log("Enter: playTone")
  let p = await isolateParams(line)
  let ps = p.split(separator: " ")
  let apa = AudioPlayerActor()
  await apa.playPureTone(
    frequencyInHz: Int(ps[0]) ?? 500,
    amplitude: toneVolume,
    durationInMillis: Int(ps[1]) ?? 75
  )
  debugLogger.log("playTone failure")
}

func stopSpeaker() async {
  debugLogger.log("Enter: stopSpeaker")
  await ss.clearBacklog()
  speaker.stopSpeaking()
}

func dispatchSpeaker() async {
  debugLogger.log("Enter: dispatchSpeaker")
  if !speaker.isSpeaking {
    let pb = await ss.popBacklog()
    let s = " " + pb + " "
    debugLogger.log("speaking: \(s)")
    let isAllWhitespace = s.allSatisfy { $0.isWhitespace }
    if !isAllWhitespace {
      speaker.startSpeaking(s)
    }
  }
}

func queueSpeaker(_ line: String) async {
  debugLogger.log("Enter: queueSpeaker")
  let p = await isolateParams(line)
  await ss.pushBacklog(p)
}

func queueCode(_ line: String) async {
  debugLogger.log("Enter: queueCode")
  let p = await isolateParams(line)
  await ss.pushBacklog(p, code: true)
}

/* Does the same thing as "p " so route it over to playSound */
func playAudioIcon(_ line: String) async {
  debugLogger.log("Enter: playAudioIcon")
  debugLogger.log("Playing audio icon: " + line)
  await playSound(line)
}

func playSound(_ line: String) async {
  debugLogger.log("Enter: playSound")
  let p = await isolateParams(line)
  let trimmedP = p.trimmingCharacters(in: .whitespacesAndNewlines)
  let soundURL = URL(fileURLWithPath: trimmedP)

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

  let sound = NSSound(contentsOf: url, byReference: true)
  sound?.volume = await soundVolume
  sound?.play()
}

func ttsSay(_ line: String) async {
  debugLogger.log("Enter: ttsSay")
  debugLogger.log("ttsSay: " + line)
  let p = await isolateParams(line)
  await say(p, interupt: true)

}

func say(
  _ what: String,
  interupt: Bool = false,
  code: Bool = false
) async {
  debugLogger.log("Enter: say")
  var w = stripSpecialEmbeds(what)
  if !code {
    switch await ss.getPunct().lowercased() {
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
    debugLogger.log("speaking: \(w)")
    speaker.startSpeaking(w)
  } else {
    if speaker.isSpeaking {
      await ss.pushBacklog(w)
    } else {
      debugLogger.log("say:startSpeaking: \(w)")
      speaker.startSpeaking(w)
    }
  }
}

func unknownLine(_ line: String) async {
  debugLogger.log("Enter: unknownLine")
  debugLogger.log("Unknown command: " + line)
}

func ttsExit() async {
  debugLogger.log("Enter: ttsExit")
  exit(0)
}

func stripSpecialEmbeds(_ line: String) -> String {
  debugLogger.log("Enter: stripSpecialEmbeds")
  let specialEmbedRegexp = #"\[\{.*?\}\]"#
  return voiceToReset(line).replacingOccurrences(
    of: specialEmbedRegexp,
    with: "", options: .regularExpression)
}

/* So, it turns out we get spammed with voice often as a form of a
   reset of the voice engine, good news is we have that command
   built right in */
func voiceToReset(_ line: String) -> String {
  debugLogger.log("Enter: voiceToReset")
  let specialEmbedRegexp = #"\[\{voice.*?\}\]"#
  return line.replacingOccurrences(
    of: specialEmbedRegexp,
    with: " [[rset 0]] ", options: .regularExpression)
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

func isolateParams(_ line: String) async -> String {
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
  return params
}

await ttsReset()
await main()

// local variables:
// mode: swift
// swift-mode:basic-offset: 2
// end:
