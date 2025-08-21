import AVFoundation
import AppKit
import Darwin
import Foundation
import Network
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
let version = "2.8.2"
let name = "swiftmac"
let ss = StateStore.shared
let speaker = AVSpeechSynthesizer()
let tonePlayer = TonePlayerActor()

// Audio engine actor for thread-safe notification audio
actor NotificationAudioEngine {
  private let engine = AVAudioEngine()
  private let playerNode = AVAudioPlayerNode()
  private let environmentNode = AVAudioEnvironmentNode()
  private var isSetup = false
  
  func setupIfNeeded() async {
    guard !isSetup else { return }
    
    engine.attach(playerNode)
    engine.attach(environmentNode)
    
    let audioTarget = await ss.audioTarget
    if audioTarget == "right" {
      playerNode.position = AVAudio3DPoint(x: 1, y: 0, z: 0)
    } else if audioTarget == "left" {
      playerNode.position = AVAudio3DPoint(x: -1, y: 0, z: 0)
    }
    
    isSetup = true
  }
  
  func handleBuffer(_ buffer: AVAudioBuffer) {
    guard let pcmBuffer = buffer as? AVAudioPCMBuffer,
          pcmBuffer.frameLength > 0 else { return }
    
    // Setup connections if this is the first buffer
    if !isSetup {
      let format = pcmBuffer.format  
      engine.connect(playerNode, to: environmentNode, format: format)
      engine.connect(environmentNode, to: engine.mainMixerNode, format: nil)
      isSetup = true
    }
    
    do {
      if !engine.isRunning {
        engine.prepare()
        try engine.start()
      }
      
      playerNode.scheduleBuffer(pcmBuffer)
      
      if !playerNode.isPlaying {
        playerNode.play()
      }
    } catch {
      print("Error in notification audio engine: \(error.localizedDescription)")
    }
  }
  
  func stop() {
    if playerNode.isPlaying {
      playerNode.stop()
    }
    if engine.isRunning {
      engine.stop()
    }
  }
  
  deinit {
    stop()
  }
}

// notification support
let notificationEngine = NotificationAudioEngine()

// Safely compiled regexes
struct RegexStore {
  static let uppercaseRegex: Result<NSRegularExpression, Error> = {
    Result { try NSRegularExpression(pattern: "(?<=[a-z])(?=[A-Z])", options: []) }
  }()
  
  static let voiceRegex: Result<NSRegularExpression, Error> = {
    Result { try NSRegularExpression(pattern: "\\[\\{voice\\s+([^\\}]+)\\}\\]", options: []) }
  }()
  
  static let pitchRegex: Result<NSRegularExpression, Error> = {
    Result { try NSRegularExpression(pattern: "\\[\\[pitch\\s+([^\\]]+)\\]\\]", options: []) }
  }()
  
  static let capitalSplitRegex: Result<NSRegularExpression, Error> = {
    Result { try NSRegularExpression(pattern: "(?<=\\s)(?=[A-Z])", options: []) }
  }()
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

func parseCommandLineArguments() -> (port: Int?, shouldListen: Bool) {
  debugLogger.log("in parseCommandLineArguments")
  let arguments = CommandLine.arguments
  var port: Int?
  var shouldListen = false

  if let index = arguments.firstIndex(of: "-p"), index + 1 < arguments.count {
    port = Int(arguments[index + 1])
    shouldListen = true
  }

  return (port, shouldListen)
}

func startNetworkListener(port: NWEndpoint.Port) {
  debugLogger.log("in startNetworkListener")
  let listener: NWListener
  do {
    listener = try NWListener(using: .tcp, on: port)
  } catch {
    debugLogger.log("Failed to create listener on port \(port): \(error)")
    print("Error: Could not bind to port \(port). Port may be in use or insufficient permissions.")
    return
  }

  listener.stateUpdateHandler = { newState in
    switch newState {
    case .ready:
      debugLogger.log("Listener ready")
    case .failed(let error):
      debugLogger.log("Listener failed with error: \(error)")
    case .waiting(let error):
      debugLogger.log("Listener waiting with error: \(error)")
    default:
      break
    }
  }

  listener.newConnectionHandler = { newConnection in
    debugLogger.log("New connection: \(newConnection.endpoint)")
    handleConnection(newConnection)
  }

  listener.start(queue: .main)
}

func handleConnection(_ connection: NWConnection) {
  debugLogger.log("in handleConnection")

  connection.stateUpdateHandler = { newState in
    switch newState {
    case .ready:
      debugLogger.log("Connection ready")
      receiveData(from: connection)
    case .failed(let error):
      debugLogger.log("Connection failed with error: \(error)")
      connection.cancel()
    case .waiting(let error):
      debugLogger.log("Connection waiting with error: \(error)")
    case .cancelled:
      debugLogger.log("Connection cancelled")
    default:
      break
    }
  }

  connection.start(queue: .main)
  
  // Set timeout for idle connections
  DispatchQueue.main.asyncAfter(deadline: .now() + 300) { // 5 minute timeout
    if connection.state != .cancelled {
      debugLogger.log("Connection timeout - cancelling")
      connection.cancel()
    }
  }
}

func receiveData(from connection: NWConnection) {
  debugLogger.log("in receiveData")

  connection.receive(minimumIncompleteLength: 1, maximumLength: 10240) { // Reduced buffer size
    data, _, isComplete, error in
    if let error = error {
      debugLogger.log("Error receiving data: \(error)")
      connection.cancel()
      return
    }

    if let data = data, !data.isEmpty {
      let inputString = String(data: data, encoding: .utf8) ?? ""
      let inputLines = inputString.components(separatedBy: CharacterSet.newlines)
      debugLogger.log("string in \(inputLines)")
      debugLogger.log("lines in \(inputLines)")

      // Process all lines in a single Task to reduce overhead
      let nonEmptyLines = inputLines.compactMap { line in
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
      }
      
      if !nonEmptyLines.isEmpty {
        Task {
          for line in nonEmptyLines {
            await processInputLine(line)
          }
        }
      }
    }

    if isComplete {
      debugLogger.log("Connection closed")
      connection.cancel()
    } else if connection.state == .ready {
      receiveData(from: connection)
    } else {
      debugLogger.log("Connection no longer ready, stopping receive")
    }
  }
}

// I/O Actor to handle stdin reading without blocking main thread
actor IOHandler {
  func startReadingInput() async {
    while let line = readLine() {
      await processInputLine(line)
    }
  }
}

/* EntryPoint */
func main() async {
  debugLogger.log("Enter: main")

  // Audio engines on macOS can coexist with proper configuration

  let (port, shouldListen) = parseCommandLineArguments()

  if shouldListen, let port = port {
    debugLogger.log("Starting network listener on port \(port)")
    guard port >= 0 && port <= 65535, let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
      debugLogger.log("Invalid port number: \(port)")
      print("Error: Invalid port number \(port). Must be between 0 and 65535.")
      return
    }
    startNetworkListener(port: nwPort)
  }

  if await notificationMode() {
    await instantTtsSay("notification mode on")
    await notificationEngine.setupIfNeeded()
  } else {
    await instantVersion()
  }

  let ioHandler = IOHandler()
  await ioHandler.startReadingInput()
}

func processInputLine(_ line: String) async {
  debugLogger.log("Enter: processInputLine")

  debugLogger.log("got line \(line)")
  let (cmd, params) = await isolateCmdAndParams(line)
  switch cmd {
  case "a": await processAndQueueAudioIcon(params)
  case "c": await processAndQueueCodes(params)
  case "d": await dispatchPendingQueue()
  case "l": await instantLetter(params)
  case "p": await doPlaySound(params)
  case "q": await queueLine(cmd, params)
  case "s": await instantStopSpeaking()
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
  case "tts_sync_state": await instantTtsSyncState(params)
  case "version": await instantVersion()
  default: await unknownLine(cmd, params)
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
  guard case .success(let regex) = RegexStore.uppercaseRegex else {
    return input // Fallback to original if regex failed
  }
  let range = NSRange(input.startIndex..., in: input)
  let modifiedString = regex.stringByReplacingMatches(
    in: input, options: [], range: range, withTemplate: " ")
  return modifiedString
}

@MainActor func instantTtsReset() async {
  debugLogger.log("Enter: instantTtsReset")
  await instantStopSpeaking()
  await ss.reset()
}

func instantVersion() async {
  debugLogger.log("Enter: instantVersion")
  let sayVersion = version.replacingOccurrences(of: ".", with: " dot ")

  await instantStopSpeaking()
  #if DEBUG
    await instantTtsSay("\(name) \(sayVersion): debug mode")
  #else
    await instantTtsSay("\(name) \(sayVersion)")
  #endif
}

func doSilence(_ p: String) async {
  // This sets up a delay on next spoken thing
  debugLogger.log("Enter: doSilence")
  if let timeInterval = TimeInterval(p) {
    await ss.setNextPreDelay(timeInterval / 1000)
  }
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
      await doTone("800 50")
    } else {
      await ss.setPitchMultiplier(1.5)
    }
  }
  let oldSpeechRate = await ss.speechRate
  await ss.setSpeechRate(await ss.getCharacterRate())
  await instantStopSpeaking()
  await doSpeak(p.lowercased())
  await ss.setPitchMultiplier(oldPitchMultiplier)
  await ss.setSpeechRate(oldSpeechRate)
  await ss.setPreDelay(oldPreDelay)
}

func instantStopSpeaking() async {
  debugLogger.log("Enter: instantStopSpeaking")
  if speaker.isSpeaking {
    speaker.stopSpeaking(at: .immediate)
  }
  await notificationEngine.stop()
}

func isFirstLetterCapital(_ str: String) -> Bool {
  debugLogger.log("Enter: isFirstLetterCapital")
  guard let firstChar = str.first else {
    return false
  }
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
  guard case .success(let regex) = RegexStore.voiceRegex else {
    return nil
  }
  let matches = regex.matches(
    in: string, options: [], range: NSRange(location: 0, length: string.utf16.count))

  guard let match = matches.first,
        let range = Range(match.range(at: 1), in: string) else {
    return nil
  }

  return String(string[range])
}

func extractPitch(_ string: String) -> String? {
  debugLogger.log("Enter: extractPitch")
  guard case .success(let regex) = RegexStore.pitchRegex else {
    return nil
  }
  let matches = regex.matches(
    in: string, options: [], range: NSRange(location: 0, length: string.utf16.count))

  guard let match = matches.first,
        let range = Range(match.range(at: 1), in: string) else {
    return nil
  }

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
  if let p = extractPitch(p) {
    await ss.appendToPendingQueue(("tts_set_pitch_multiplier", p))
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

// Optimized punctuation replacement using single-pass character iteration
func replacePunctuationsOptimized(_ line: String, mode: String) -> String {
  debugLogger.log("Enter: replacePunctuationsOptimized")
  
  let basePuncs = ["%": " percent ", "$": " dollar "]
  let somePuncs = [
    "#": " pound ", "-": " dash ", "\"": " quote ",
    "(": " leftParen ", ")": " rightParen ", "*": " star ",
    ";": " semi ", ":": " colon ", "\n": "", "\\": " backslash ",
    "/": " slash ", "+": " plus ", "=": " equals ",
    "~": " tilda ", "`": " backquote ", "!": " exclamation ",
    "^": " caret "
  ]
  let allPuncs = [
    "<": " less than ", ">": " greater than ", "'": " apostrophe ",
    "@": " at sign ", "_": " underline ", ".": " dot ",
    ",": " comma "
  ]
  
  var replacements = basePuncs
  
  if mode == "some" || mode == "all" {
    replacements.merge(somePuncs) { _, new in new }
  }
  if mode == "all" {
    replacements.merge(allPuncs) { _, new in new }
    replacements["*"] = " star " // Override for all mode
  }
  
  // Single-pass replacement
  var result = ""
  result.reserveCapacity(line.count * 2) // Pre-allocate for efficiency
  
  for char in line {
    if let replacement = replacements[String(char)] {
      result += replacement
    } else {
      result.append(char)
    }
  }
  
  return result
}

/* This is used for "none" puncts */
func replaceBasePuncs(_ line: String) -> String {
  return replacePunctuationsOptimized(line, mode: "none")
}

/* this is used for "some" puncts */
func replaceSomePuncs(_ line: String) -> String {
  return replacePunctuationsOptimized(line, mode: "some")
}

/* this is used for "all" puncts */
func replaceAllPuncs(_ line: String) -> String {
  return replacePunctuationsOptimized(line, mode: "all")
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

// MainActor because this is explicitly to be atomic
func instantTtsSyncState(_ p: String) async {
  debugLogger.log("Enter: processAndQueueSync")
  let ps = p.split(separator: " ")
  if ps.count == 4 {
    let punct = String(ps[0])
    await ttsSetPunctuations(punct)
    let splitCaps = String(ps[1])
    await ttsSplitCaps(splitCaps)
    let beepCaps = String(ps[2])
    await ttsAllCapsBeep(beepCaps)
    let rate = String(ps[3])
    await instantSetSpeechRate(rate)

  }
}

func doTone(_ p: String) async {
  debugLogger.log("Enter: doTone")
  let ps = p.split(separator: " ")
  await tonePlayer.playPureTone(
    frequencyInHz: Int(ps[0]) ?? 500,
    amplitude: await ss.toneVolume,
    durationInMillis: Int(ps[1]) ?? 75
  )
}

func doPlaySound(_ path: String) async {
  debugLogger.log("Enter: doPlaySound")
  let soundURL = URL(fileURLWithPath: path)

  do {
    let decodedURL: URL? = try await decodeIfNeeded(soundURL)
    guard let url = decodedURL else {
      debugLogger.log("Failed to get audio file URL from path: \(path)")
      return
    }

    debugLogger.log("Playing sound from URL: \(url)")
    let volume = await ss.soundVolume
    await SoundManager.shared.playSound(from: url, volume: volume)
  } catch {
    debugLogger.log("An error occurred while trying to play sound: \(error)")
    // Handle error or simply log it to allow continuation of program execution
  }
}

/// Helper function to decode OGG files if necessary
private func decodeIfNeeded(_ url: URL) async throws -> URL? {
  if url.pathExtension.lowercased() == "ogg" {
    debugLogger.log("Decoding OGG file at URL: \(url)")
    let decoder = OGGDecoder()
    return await withCheckedContinuation { continuation in
      decoder.decode(url) { decodedUrl in
        continuation.resume(returning: decodedUrl)
      }
    }
  } else {
    return url
  }
}

func instantTtsSay(_ p: String) async {
  debugLogger.log("Enter: instantTtsSay")
  debugLogger.log("ttsSay: \(p)")
  await instantStopSpeaking()
  await doSpeak(p)
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
  // Use the regular expression to find matches, which are the split points in the string
  guard case .success(let regex) = RegexStore.capitalSplitRegex else {
    return [input] // Fallback to original string if regex failed
  }
  
  let range = NSRange(input.startIndex..., in: input)
  let matches = regex.matches(in: input, options: [], range: range)

  var results = [String]()
  var lastEndIndex = input.startIndex
  // Iterate through the matches to split the string
  for match in matches {
    guard let matchRange = Range(match.range, in: input) else { continue }
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

  // Batch read all speech settings in one actor call for better performance
  let settings = await ss.getSpeechSettings()
  
  var temp: String
  if settings.splitCaps {
    temp = insertSpaceBeforeUppercase(what)
  } else {
    temp = what
  }
  let utterance = AVSpeechUtterance(string: temp)

  // Set all speech parameters from batched read
  utterance.rate = settings.speechRate
  utterance.pitchMultiplier = settings.pitchMultiplier
  utterance.volume = settings.voiceVolume
  utterance.preUtteranceDelay = settings.nextPreDelay
  utterance.postUtteranceDelay = settings.postDelay
  utterance.voice = settings.voice

  // Start speaking - AVSpeechSynthesizer must be used on main thread
  if await notificationMode() {
    await MainActor.run {
      speaker.write(utterance) { buffer in
        Task {
          await notificationEngine.handleBuffer(buffer)
        }
      }
    }
  } else {
    await MainActor.run {
      speaker.speak(utterance)
    }
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
