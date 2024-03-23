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

  #if DEBUG
    await instantTtsSay("Debugging \(name) server for e mac speak \(version)")
  #else
    await instantTtsSay("welcome to e mac speak with \(name) \(version)")
  #endif

  print("Entering mainloop")
  await mainLoop()
  print("Exiting \(name) \(version)")
}

func mainLoop() async {
  while let l = readLine() {
    debugLogger.log("got line \(l)")
    let (cmd, params) = await isolateCmdAndParams(l)
    // TODO: if tts_discard and! tts_discard command
    // log and continue
    switch cmd {
    case "a": await processAndQueueAudioIcon(params)
    // case "c": await processAndQueueCodes(l)
    case "d": await dispatchPendingQueue()
    case "l": await instantSayLetter(params)
    case "p": await doPlaySound(params)
    //case "q": await processAndQueueSpeech(cmd, params)
    case "s": await queueLine(cmd, params)
    case "sh": await queueLine(cmd, params)
    case "t": await queueLine(cmd, params)
    // case "version": await instantTtsSayVersion()
    case "tts_exit": await instantTtsExit()
    case "tts_pause": await instantTtsPause()
    case "tts_reset": await queueLine(cmd, params)
    case "tts_resume": await instantTtsResume()
    case "tts_say": await instantTtsSay(params)
    case "tts_set_character_scale": await queueLine(cmd, params)
    case "tts_set_punctuations": await queueLine(cmd, params)
    case "tts_set_speech_rate": await queueLine(cmd, params)
    case "tts_split_caps": await queueLine(cmd, params)
    case "tts_set_discard": await queueLine(cmd, params)
    // case "tts_sync_state": await processAndQueueSync(l)
    case "tts_allcaps_beep": await queueLine(cmd, params)
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
    // case "sh": await doSilence(l)
    case "t": await doPlayTone(params)
    // case "tts_reset": await doTtsReset()
    // case "tts_set_character_scale": await setCharScale(l)
    // case "tts_set_punctuations": await setPunct(l)
    // case "tts_set_speech_rate": await setSpeechRate(l)
    // case "tts_split_caps": await setSplitCaps(l)
    // case "tts_set_discard": await setDiscard(l)
    // case "tts_sync_state": impossibleQueue()
    // case "tts_allcaps_beep": await setBeepCaps(l)
    default: await impossibleQueue(cmd, params)
    }
  }
}

func queueLine(_ cmd: String, _ params: String) async {
  debugLogger.log("Enter: queueLine")
  await ss.appendToPendingQueue((cmd, params))
}

func instantTtsResume() async {
  speaker.continueSpeaking()
}

func instantSayLetter(_ p: String) async {
  let oldPitchMultiplier = await ss.pitchMultiplier
  if isCapitalLetter(p) {
    await ss.setPitchMultiplier(1.5)
  }
  let oldSpeechRate = await ss.speechRate
  await ss.setSpeechRate(await ss.getCharacterRate())
  await instantTtsSay(p.lowercased())
  await ss.setPitchMultiplier(oldPitchMultiplier)
  await ss.setSpeechRate(oldSpeechRate)
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
}

func impossibleQueue(_ cmd: String, _ params: String) async {
  debugLogger.log("Enter: impossibleQueue")
  print("Impossible queue item \(cmd) \(params)")
}

func processAndQueueAudioIcon(_ p: String) async {
  debugLogger.log("Enter: processAndQueueAudioIcon")
  await ss.appendToPendingQueue(("p", p))
}

// func processAndQueueCodes(l) async {
//   debugLogger.log("Enter: processAndQueueCodes")

// }

// /* This is replacements that always must happen when doing
//    replaceements like [*] -> slnc */
// func replaceCore(_ line: String) -> String {
//   debugLogger.log("Enter: replaceCore")
//   return
//     line
//     .replacingOccurrences(of: "[*]", with: " [[slnc 50]] ")
// }

// /* This is used for "none" puncts */
// func replaceBasePuncs(_ line: String) -> String {
//   debugLogger.log("Enter: replaceBasePuncs")
//   let l = replaceCore(line)
//   return replaceCore(l)
//     .replacingOccurrences(of: "%", with: " percent ")
//     .replacingOccurrences(of: "$", with: " dollar ")

// }

// /* this is used for "some" puncts */
// func replaceSomePuncs(_ line: String) -> String {
//   debugLogger.log("Enter: replaceSomePuncs")
//   return replaceBasePuncs(line)
//     .replacingOccurrences(of: "#", with: " pound ")
//     .replacingOccurrences(of: "-", with: " dash ")
//     .replacingOccurrences(of: "\"", with: " quote ")
//     .replacingOccurrences(of: "(", with: " leftParen ")
//     .replacingOccurrences(of: ")", with: " rightParen ")
//     .replacingOccurrences(of: "*", with: " star ")
//     .replacingOccurrences(of: ";", with: " semi ")
//     .replacingOccurrences(of: ":", with: " colon ")
//     .replacingOccurrences(of: "\n", with: "")
//     .replacingOccurrences(of: "\\", with: " backslash ")
//     .replacingOccurrences(of: "/", with: " slash ")
//     .replacingOccurrences(of: "+", with: " plus ")
//     .replacingOccurrences(of: "=", with: " equals ")
//     .replacingOccurrences(of: "~", with: " tilda ")
//     .replacingOccurrences(of: "`", with: " backquote ")
//     .replacingOccurrences(of: "!", with: " exclamation ")
//     .replacingOccurrences(of: "^", with: " caret ")
// }

// /* this is used for "all" puncts */
// func replaceAllPuncs(_ line: String) -> String {
//   debugLogger.log("Enter: replaceAllPuncs")
//   return replaceSomePuncs(line)
//     .replacingOccurrences(of: "<", with: " less than ")
//     .replacingOccurrences(of: ">", with: " greater than ")
//     .replacingOccurrences(of: "'", with: " apostrophe ")
//     .replacingOccurrences(of: "*", with: " star ")
//     .replacingOccurrences(of: "@", with: " at sign ")
//     .replacingOccurrences(of: "_", with: " underline ")
//     .replacingOccurrences(of: ".", with: " dot ")
//     .replacingOccurrences(of: ",", with: " comma ")

// }

// func ttsSplitCaps(_ line: String) async {
//   debugLogger.log("Enter: ttsSplitCaps")
//   let l = await isolateParams(line)
//   if l == "1" {
//     await setSplitCaps = true
//   } else {
//     await sssetSplitCaps = false
//   }
// }

// func doTtsReset() async {
//   debugLogger.log("Enter: ttsReset")
//   stopAll()
//   ss = StateStore()
// }

// func sayVersion() async {
//   debugLogger.log("Enter: sayVersion")
//   await say("Running \(name) version \(version)", interupt: true)
// }

// func sayLetter(_ line: String) async {
//   debugLogger.log("Enter: sayLetter")
//   let letter = await isolateParams(line)
//   let trimmedLetter = letter.trimmingCharacters(in: .whitespacesAndNewlines)
//   let cs = await ss.getCharacterRate()
//   let charRate = speaker.rate * cs
//   var pitchShift = 0
//   if let singleChar = trimmedLetter.first, singleChar.isUppercase {
//     pitchShift = 15
//     debugLogger.log("PitchShift ON")
//   }

//   await say(
//     "[[rate \(charRate)]][[pbas +\(pitchShift)]][[char ltrl]]\(letter)[[rset 0]]",
//     interupt: true,
//     code: true
//   )
// }

// func saySilence(_ line: String, duration: Int = 50) async {
//   debugLogger.log("Enter: saySilence")
//   await say("[[slnc \(duration)]]", interupt: false)
// }

// func ttsPause() async {
//   debugLogger.log("Enter: ttsPause")
//   speaker.pauseSpeaking(at: .immediateBoundary)
// }

// func ttsResume() async {
//   debugLogger.log("Enter: ttsResume")
//   speaker.continueSpeaking()
// }

// func ttsSetCharacterScale(_ line: String) async {
//   debugLogger.log("Enter: ttsSetCharacterScale")
//   let l = await isolateParams(line)
//   if let fl = Float(l) {
//     await ss.setCharScale(fl)
//   }
// }

// func ttsSetPunctuations(_ line: String) async {
//   debugLogger.log("Enter: ttsSetPunctuations")
//   let l = await isolateParams(line)
//   await ss.setPunct(l)
// }

// func ttsSetRate(_ line: String) async {
//   debugLogger.log("Enter: ttsSetRate")
//   let l = await isolateParams(line)
//   if let fl = Float(l) {
//     speaker.rate = fl
//   }
// }

// func ttSplitCaps(_ line: String) async {
//   debugLogger.log("Enter: ttSplitCaps")
//   let l = await isolateParams(line)
//   if l == "1" {
//     await ss.setSplitCaps(true)
//   } else {
//     await ss.setSplitCaps(false)
//   }
// }

// func ttsAllCapsBeep(_ line: String) async {
//   debugLogger.log("Enter: ttsAllCapsBeep")
//   let l = await isolateParams(line)
//   if l == "1" {
//     await ss.setBeepCaps(true)
//   } else {
//     await ss.setBeepCaps(false)
//   }
// }

// func ttsSyncState(_ line: String) async {
//   debugLogger.log("Enter: ttsSyncState")
//   let l = await isolateParams(line)
//   let ps = l.split(separator: " ")
//   if ps.count == 4 {
//     if let r = Float(ps[3]) {
//       speaker.rate = r
//     }

//     let beepCaps = ps[2]
//     if beepCaps == "1" {
//       await ss.setBeepCaps(true)
//     } else {
//       await ss.setBeepCaps(false)
//     }

//     let splitCaps = ps[1]
//     if splitCaps == "1" {
//       await ss.setSplitCaps(true)
//     } else {
//       await ss.setSplitCaps(false)
//     }
//     let punct = ps[0]
//     await ss.setPunct(String(punct))
//   }
// }

func doPlayTone(_ p: String) async {
  debugLogger.log("Enter: doPlayTone")
  let ps = p.split(separator: " ")
  await tonePlayer.playPureTone(
    frequencyInHz: Int(ps[0]) ?? 500,
    amplitude: await ss.toneVolume,
    durationInMillis: Int(ps[1]) ?? 75
  )
  debugLogger.log("playTone failure")
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
  let voice = AVSpeechSynthesisVoice()
  utterance.voice = voice

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
