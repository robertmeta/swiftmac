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
var ss = StateStore() // just create new one to reset
let speaker = AVSpeechSynthesizer()

/* EntryPoint */
func main() async {
  debugLogger.log("Enter: main")
  #if DEBUG
    await instantSay("Debugging \(name) server for e mac speak \(version)")
  #else
    await instantSay("welcome to e mac speak with \(name) \(version)")
  #endif


  print("Entering mainloop")
  await mainLoop()
  print("Exiting \(name) \(version)")
}

@MainActor
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
    // case "l": await instantSayLetter(l)
    // case "p": await doPlaySound(l)
    // case "q": await queueLine(l)
    // case "s": await queueLine(l)
    // case "sh": await queueLine(l)
    // case "t": await queueLine(l)
    // case "version": await instantSayVersion()
    // case "tts_exit": await instantTtsExit()
    // case "tts_pause": await instantTtsPause()
    // case "tts_reset": await queueTtsReset()
    // case "tts_resume": await instantTtsResume()
    // case "tts_say": await instantTtsSay(l)
    // case "tts_set_character_scale": await queueLine(l)
    // case "tts_set_punctuations": await queueLine(l)
    // case "tts_set_speech_rate": await queueLine(l)
    // case "tts_split_caps": await queueLine(l)
    // case "tts_set_discard": await queueLine(l)
    // case "tts_sync_state": await processAndQueueSync(l)
    // case "tts_allcaps_beep": await queueLine(l)
    default: await unknownLine(l) 
    }
  }
}

func dispatchPendingQueue() async {
  let sspq = await ss.pendingQueue
  for l in sspq {
    debugLogger.log("got queued \(l)")
    let (cmd, params) = await isolateCmdAndParams(l)
    switch cmd {
    case "p": await doPlaySound(params) // just like p in mainloop
    // case "l": await doSayLetter(l)
    // case "s": await doStopAll(l)
    // case "sh": await doSilence(l)
    // case "t": await doPlaySound(l)
    // case "tts_reset": await doTtsReset()
    // case "tts_set_character_scale": await setCharScale(l)
    // case "tts_set_punctuations": await setPunct(l)
    // case "tts_set_speech_rate": await setSpeechRate(l)
    // case "tts_split_caps": await setSplitCaps(l)
    // case "tts_set_discard": await setDiscard(l)
    // case "tts_sync_state": impossibleQueue()
    // case "tts_allcaps_beep": await setBeepCaps(l)
    default: await impossibleQueue(l) 
    }
  }
}

func queueLine(_ line: String) async {
  debugLogger.log("Enter: queueLine")
  await ss.appendToPendingQueue(line)
}

func unknownLine(_ line: String) async {
  debugLogger.log("Enter: unknownLine")
  debugLogger.log("Unknown command: \(line)")
}

func impossibleQueue(_ l: String) async {
  debugLogger.log("Enter: impossibleQueue")
  print("Impossible queue item \(l)")
}

func processAndQueueAudioIcon(_ p: String) async {
  debugLogger.log("Enter: processAndQueueAudioIcon")
  await ss.appendToPendingQueue("p \(p)")
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

// func doPlayTone(_ line: String) async {
//   debugLogger.log("Enter: doPlayTone")
//   let p = await isolateParams(line)
//   let ps = p.split(separator: " ")
//   let apa = AudioPlayerActor()
//   await apa.playPureTone(
//     frequencyInHz: Int(ps[0]) ?? 500,
//     amplitude: await ss.toneVolume,
//     durationInMillis: Int(ps[1]) ?? 75
//   )
//   debugLogger.log("playTone failure")
// }

// func doStopAll() async {
//   debugLogger.log("Enter: doStopAll")
//   ss.pendingQueue = []
//   await doStopSpeaking()
// }

// func doStopSpeaking() async {
//   debugLogger.log("Enter: doStopSpeaking")
//   // TODO Stop Speaking
// }

func doPlaySound(_ p: String) async {
  debugLogger.log("Enter: doPlaySound")
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
  sound?.volume = await ss.soundVolume
  sound?.play()
}


func instantSay(_ line: String) async {
  debugLogger.log("Enter: instantSay")
  debugLogger.log("ttsSay: " + line)
  //await doStopAll()
  print("instantSay")
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

// func instantTtsExit() async {
//   debugLogger.log("Enter: instantTtsExit")
//   exit(0)
// }

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
// // local variables:
// // mode: swift
// // swift-mode:basic-offset: 2
// // end:
