import AVFoundation
import AppKit
import Foundation
import OggDecoder

/* Global Constants */
@globalActor
struct gs {
  // gs means global state
  static let shared = AppState()

  actor AppState {
    let apa = AudioPlayerActor()
    let version = "1.1.0"
    let name = "swiftmac"
    let speaker = NSSpeechSynthesizer()
    let defaultRate: Float = 220
    let defaultCharScale: Float = 1.1
    let defaultVoice = NSSpeechSynthesizer.defaultVoice
    let defaultPunct = "all"
    let defaultSplitCaps = false
    let defaultBeepCaps = false
    var soundVolume: Float = 1.0
    var toneVolume: Float = 1.0
    var voiceVolume: Float = 1.0

  }
}

@gs
func main() async {
  await gs.shared.apa.playPureTone(
    frequencyInHz: 500,
    amplitude: 500,
    durationInMillis: 500
  )
  sleep(1)
}

await main()


/*
 struct GlobalState {
 }

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

 let currentDate = Date()
 let dateFormatter = DateFormatter()
 dateFormatter.dateFormat = "yyyy-MM-dd_HH_mm_ss"
 let timestamp = dateFormatter.string(from: currentDate)
 let debugLogger = Logger(fileName: "swiftmac-debug-\(timestamp).log")

 await debugLogger.log("soundVolume \(soundVolume)")
 await debugLogger.log("toneVolume \(toneVolume)")
 await debugLogger.log("voiceVolume \(voiceVolume)")


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
 func speechSynthesizer(
 _ sender: NSSpeechSynthesizer,
 didFinishSpeaking finishedSpeaking: Bool
 ) {
 if finishedSpeaking {
 let s = ss.popBacklog()
 debugLogger.log("didFinishSpeaking:startSpeaking: \(s)")
 speaker.startSpeaking(s)
 await debugLogger.log("Enter: startSpeaking")
 }
 }
 }
 let dh = DelegateHandler()
 speaker.delegate = dh

 let ss = StateStore()

 /* Entry point and main loop */
 func main() async {
 await debugLogger.log("Enter: main")
 #if DEBUG
 await say("Debugging swift mac server for e mac speak \(version)", interupt: true)
 #else
 await say("welcome to e mac speak with swift mac \(version)", interupt: true)
 #endif
 while let l = readLine() {
 #if DEBUG
 await debugLogger.log("got line \(l)")
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
   await debugLogger.log("Enter: replaceBasePuncs")
   let l = replaceCore(line)
   return replaceCore(l)
   .replacingOccurrences(of: "%", with: " percent ")
   .replacingOccurrences(of: "$", with: " dollar ")

   }

   /* this is used for "some" puncts */
   func replaceSomePuncs(_ line: String) -> String {
   await debugLogger.log("Enter: replaceSomePuncs")
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
   await debugLogger.log("Enter: replaceAllPuncs")
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
   await debugLogger.log("Enter: ttsSplitCaps")
   let l = await isolateCommand(line)
   if l == "1" {
   ss.setSplitCaps(true)
   } else {
   ss.setSplitCaps(false)
   }
   }

   @MainActor
   func ttsReset() async {
   await debugLogger.log("Enter: ttsReset")
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
   await debugLogger.log("Enter: sayVersion")
   await say("Running \(name) version \(version)", interupt: true)
   }

   @MainActor
   func sayLetter(_ line: String) async {
   await debugLogger.log("Enter: sayLetter")
   let letter = await isolateParams(line)
   let trimmedLetter = letter.trimmingCharacters(in: .whitespacesAndNewlines)

   let charRate = speaker.rate * ss.getCharScale()
   var pitchShift = 0
   if let singleChar = trimmedLetter.first, singleChar.isUppercase {
   pitchShift = 15
   #if DEBUG
   await debugLogger.log("PitchShift ON")
   #endif
   }

   await say(
   "[[rate \(charRate)]][[pbas +\(pitchShift)]][[char ltrl]]\(letter)[[rset 0]]",
   interupt: true,
   code: true
   )
   }

   func saySilence(_ line: String, duration: Int = 50) async {
   #if DEBUG
   await debugLogger.log("Enter: saySilence")
   #endif
   await say("[[slnc \(duration)]]", interupt: false)
   }

   @MainActor
   func ttsPause() async {
   #if DEBUG
   await debugLogger.log("Enter: ttsPause")
   #endif
   speaker.pauseSpeaking(at: .immediateBoundary)
   }

   @MainActor
   func ttsResume() async {
   await debugLogger.log("Enter: ttsResume")
   speaker.continueSpeaking()
   }

   func ttsSetCharacterScale(_ line: String) async {
   await debugLogger.log("Enter: ttsSetCharacterScale")
   let l = await isolateParams(line)
   if let fl = Float(l) {
   ss.setCharScale(fl)
   }
   }

   func ttsSetPunctuations(_ line: String) async {
   await debugLogger.log("Enter: ttsSetPunctuations")
   let l = await isolateParams(line)
   ss.setPunct(l)
   }

   @MainActor
   func ttsSetRate(_ line: String) async {
   await debugLogger.log("Enter: ttsSetRate")
   let l = await isolateParams(line)
   if let fl = Float(l) {
   speaker.rate = fl
   }
   }

   func ttSplitCaps(_ line: String) async {
   await debugLogger.log("Enter: ttSplitCaps")
   let l = await isolateParams(line)
   if l == "1" {
   ss.setSplitCaps(true)
   } else {
   ss.setSplitCaps(false)
   }
   }

   func ttsAllCapsBeep(_ line: String) async {
   await debugLogger.log("Enter: ttsAllCapsBeep")
   let l = await isolateParams(line)
   if l == "1" {
   ss.setBeepCaps(true)
   } else {
   ss.setBeepCaps(false)
   }
   }

   @MainActor
   func ttsSyncState(_ line: String) async {
   await debugLogger.log("Enter: ttsSyncState")
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
   await debugLogger.log("Enter: playTone")
   let p = await isolateParams(line)
   let ps = p.split(separator: " ")
   await playPureTone(
   frequencyInHz: Int(ps[0]) ?? 500,
   amplitude: toneVolume,
   durationInMillis: Int(ps[1]) ?? 75
   )
   await debugLogger.log("playTone failure")
   }

   func stopSpeaker() async {
   await debugLogger.log("Enter: stopSpeaker")
   ss.clearBacklog()
   speaker.stopSpeaking()
   }

   func dispatchSpeaker() async {
   await debugLogger.log("Enter: dispatchSpeaker")
   if !speaker.isSpeaking {
   let s = " " + ss.popBacklog() + " "
   #if DEBUG
   await debugLogger.log("speaking: \(s)")
   #endif
   let isAllWhitespace = s.allSatisfy { $0.isWhitespace }
   if !isAllWhitespace {
   speaker.startSpeaking(s)
   }
   }
   }

   func queueSpeaker(_ line: String) async {
   await debugLogger.log("Enter: queueSpeaker")
   let p = await isolateParams(line)
   ss.pushBacklog(p)
   }

   func queueCode(_ line: String) async {
   await debugLogger.log("Enter: queueCode")
   let p = await isolateParams(line)
   ss.pushBacklog(p, code: true)
   }

   /* Does the same thing as "p " so route it over to playSound */
   func playAudioIcon(_ line: String) async {
   await debugLogger.log("Enter: playAudioIcon")
   await debugLogger.log("Playing audio icon: '\(line)'")
   await playSound(line)
   }

   func playSound(_ line: String) async {
   await debugLogger.log("Enter: playSound")

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
   continuation.resume(returning: soundURL)  // Directly use the provided URL for non-OGG files
   }
   }

   guard let url = savedWavUrl else {
   print("Failed to get audio file URL")
   return
   }

   let sound = NSSound(contentsOf: url, byReference: true)
   sound?.volume = await soundVolume  // Make sure `soundVolume` is accessible here.
   sound?.play()
   }

   func ttsSay(_ line: String) async {
   await debugLogger.log("Enter: ttsSay")
   await debugLogger.log("ttsSay: \(line)")
   let p = await isolateParams(line)
   await say(p, interupt: true)

   }

   @MainActor
   func say(
   _ what: String,
   interupt: Bool = false,
   code: Bool = false
   ) async {
   await debugLogger.log("Enter: say")
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
   await debugLogger.log("speaking: \(w)")
   speaker.startSpeaking(w)
   } else {
   if speaker.isSpeaking {
   ss.pushBacklog(w)
   } else {
   await debugLogger.log("say:startSpeaking: \(w)")
   speaker.startSpeaking(w)
   }
   }
   }

   func unknownLine(_ line: String) async {
   await debugLogger.log("Enter: unknownLine")
   await debugLogger.log("Unknown Command: \(line)")
   print("Unknown Command: \(line)")
   }

   func ttsExit() async {
   await debugLogger.log("Enter: ttsExit")
   exit(0)
   }

   func stripSpecialEmbeds(_ line: String) -> String {
   await debugLogger.log("Enter: stripSpecialEmbeds")
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
   await debugLogger.log("Enter: isolateCommand")
   var cmd = line.trimmingCharacters(in: .whitespacesAndNewlines)
   if let firstIndex = cmd.firstIndex(of: " ") {
   cmd.replaceSubrange(firstIndex..<cmd.endIndex, with: "")
   return cmd
   }
   return cmd
   }

   func isolateParams(_ line: String) async -> String {
   await debugLogger.log("Enter: isolateParams")
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
   await debugLogger.log("Exit: isolateParams: \(params)")
   return params
   }

   await ttsReset()
   await main()

   // local variables:
   // mode: swift
   // swift-mode:basic-offset: 2
   // end:
   */
