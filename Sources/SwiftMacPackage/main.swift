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
let version = "3.1.0"
let name = "swiftmac"
var ss = await StateStore()  // just create new one to reset

@MainActor
final class SpeakerManager {
  static let shared = SpeakerManager()
  let synthesizer = AVSpeechSynthesizer()

  private init() {}
}

let tonePlayer = TonePlayerActor()

let networkQueue = DispatchQueue(label: "org.emacspeak.server.swiftmac.network")
let commandLineChannel = CommandLineChannel()
let connectionBufferManager = ConnectionBufferManager()

actor ConnectionBufferManager {
  private var buffers: [ObjectIdentifier: Data] = [:]

  func extractLines(from data: Data, for connection: NWConnection) -> [String] {
    let connectionID = ObjectIdentifier(connection)
    var buffer = buffers[connectionID] ?? Data()
    buffer.append(data)

    var lines: [String] = []
    let newline: UInt8 = 0x0A

    while let newlineIndex = buffer.firstIndex(of: newline) {
      let lineSlice = buffer[..<newlineIndex]
      var lineData = Data(lineSlice)
      if let lastByte = lineData.last, lastByte == 0x0D {
        lineData.removeLast()
      }

      let lineString = String(decoding: lineData, as: UTF8.self)
      lines.append(lineString)

      let removeEndIndex = buffer.index(after: newlineIndex)
      buffer.removeSubrange(..<removeEndIndex)
    }

    buffers[connectionID] = buffer
    return lines
  }

  func clear(for connection: NWConnection) {
    buffers.removeValue(forKey: ObjectIdentifier(connection))
  }
}

final class CommandLineChannel: Sendable {
  private let continuation: AsyncStream<String>.Continuation
  let stream: AsyncStream<String>

  init() {
    var tempContinuation: AsyncStream<String>.Continuation!
    stream = AsyncStream<String> { continuation in
      tempContinuation = continuation
    }
    continuation = tempContinuation
  }

  func emit(_ line: String) {
    continuation.yield(line)
  }

  func finish() {
    continuation.finish()
  }
}

// notification support
let engine = AVAudioEngine()
let playerNode = AVAudioPlayerNode()
let environmentNode = AVAudioEnvironmentNode()

// Thread-safe setup for notification audio
let setupLock = NSLock()
var outputFormat: AVAudioFormat?

let bufferHandler: (AVAudioBuffer) -> Void = { buffer in
  guard let pcmBuffer = buffer as? AVAudioPCMBuffer, pcmBuffer.frameLength > 0 else { return }

  setupLock.lock()
  let needsSetup = outputFormat == nil
  if needsSetup {
    outputFormat = pcmBuffer.format
    engine.connect(playerNode, to: environmentNode, format: outputFormat)
    engine.connect(environmentNode, to: engine.mainMixerNode, format: nil)
    Task {
      let target = await ss.audioTarget
      if target == "right" {
        playerNode.position = AVAudio3DPoint(x: 1, y: 0, z: 0)
      } else if target == "left" {
        playerNode.position = AVAudio3DPoint(x: -1, y: 0, z: 0)
      }
    }
    engine.prepare()

    do {
      try engine.start()
    } catch {
      print("Error starting audio engine: \(error.localizedDescription)")
      setupLock.unlock()
      return
    }
  }
  setupLock.unlock()

  // Schedule the buffer for playback
  playerNode.scheduleBuffer(pcmBuffer)

  if !playerNode.isPlaying {
    playerNode.play()
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
  let listener = try! NWListener(using: .tcp, on: port)

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

  listener.start(queue: networkQueue)
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
    case .waiting(let error):
      debugLogger.log("Connection waiting with error: \(error)")
    default:
      break
    }
  }

  connection.start(queue: networkQueue)
}

func receiveData(from connection: NWConnection) {
  debugLogger.log("in receiveData")

  connection.receive(minimumIncompleteLength: 1, maximumLength: 101024) {
    data, _, isComplete, error in
    if let error = error {
      debugLogger.log("Error receiving data: \(error)")
      connection.cancel()
      Task {
        await connectionBufferManager.clear(for: connection)
      }
      return
    }

    if let data = data, !data.isEmpty {
      Task {
        let lines = await connectionBufferManager.extractLines(from: data, for: connection)
        debugLogger.log("received batch of \(lines.count) line(s)")

        for inputLine in lines {
          let trimmedLine = inputLine.trimmingCharacters(in: .whitespacesAndNewlines)
          if !trimmedLine.isEmpty {
            commandLineChannel.emit(trimmedLine)
          }
        }
      }
    }

    if isComplete {
      debugLogger.log("Connection closed")
      connection.cancel()
      Task {
        await connectionBufferManager.clear(for: connection)
      }
    } else {
      receiveData(from: connection)
    }
  }
}

/* EntryPoint */
func main() async {
  debugLogger.log("Enter: main")

  let (port, shouldListen) = parseCommandLineArguments()

  Task {
    for await line in commandLineChannel.stream {
      await processInputLine(line)
    }
  }

  if shouldListen, let port = port {
    debugLogger.log("Starting network listener on port \(port)")
    startNetworkListener(port: NWEndpoint.Port(rawValue: UInt16(port))!)
  }

  if await notificationMode() {
    await instantTtsSay("notification mode on")

    // Setup notification audio routing
    engine.attach(playerNode)
    engine.attach(environmentNode)
  } else {
    await instantVersion()
  }

  // Only read from stdin if NOT in network listening mode
  if !shouldListen {
    while let line = readLine() {
      commandLineChannel.emit(line)
    }
    commandLineChannel.finish()
  } else {
    // Keep the program running for network mode
    // Use a continuous async sleep to keep the async context alive
    while true {
      try? await Task.sleep(nanoseconds: 1_000_000_000) // Sleep for 1 second
    }
  }
}


func processInputLine(_ line: String) async {
  debugLogger.log("Enter: processInputLine")

  debugLogger.log("got line \(line)")
  let (cmd, params) = isolateCmdAndParams(line)
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

func splitOnSquareStar(_ input: String) -> [String] {
  let separator = "[*]"
  let parts = input.components(separatedBy: separator)

  var result: [String] = []
  for (index, part) in parts.enumerated() {
    result.append(part)
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

@MainActor
func instantTtsReset() async {
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

@MainActor
func instantTtsResume() async {
  debugLogger.log("Enter: instantTtsResume")
  SpeakerManager.shared.synthesizer.continueSpeaking()
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

@MainActor
func instantStopSpeaking() async {
  debugLogger.log("Enter: instantStopSpeaking")
  let speaker = SpeakerManager.shared.synthesizer
  if speaker.isSpeaking {
    speaker.stopSpeaking(at: .immediate)
  }
  if playerNode.isPlaying {
    playerNode.stop()
  }
}

func isFirstLetterCapital(_ str: String) -> Bool {
  debugLogger.log("Enter: isFirstLetterCapital")
  guard let firstChar = str.first else {
    return false
  }
  return firstChar.isUppercase && firstChar.isLetter
}

@MainActor
func instantTtsPause() async {
  debugLogger.log("Enter: instantTtsPause")
  SpeakerManager.shared.synthesizer.pauseSpeaking(at: .immediate)
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

func extractPitch(_ string: String) -> String? {
  debugLogger.log("Enter: extractPitch")
  let pattern = "\\[\\[pitch\\s+([^\\]]+)\\]\\]"
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
    let decodedURL = try await decodeIfNeeded(soundURL)
    guard let url = decodedURL else {
      debugLogger.log("Failed to get audio file URL from path: \(path)")
      return
    }

    debugLogger.log("Playing sound from URL: \(url)")
    let volume = await ss.soundVolume
    await SoundManager.shared.playSound(from: url, volume: volume)
  } catch {
    debugLogger.log("An error occurred while trying to play sound: \(error)")
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
@MainActor
func doSpeak(_ what: String) async {
  let parts = splitOnSquareStar(what)
  for part in parts {
    if part == "[*]" {
      await doSilence("0")
    } else {
      let speakPart = await replacePunctuations(part)
      await _doSpeak(speakPart)
    }
  }
}

func splitStringAtSpaceBeforeCapitalLetter(_ input: String) -> [String] {
  let pattern = "(?<=\\s)(?=[A-Z])"

  guard let regex = try? NSRegularExpression(pattern: pattern) else {
    return [input]
  }

  let range = NSRange(input.startIndex..., in: input)
  let matches = regex.matches(in: input, options: [], range: range)

  var results = [String]()
  var lastEndIndex = input.startIndex

  for match in matches {
    guard let matchRange = Range(match.range, in: input) else { continue }
    results.append(String(input[lastEndIndex..<matchRange.lowerBound]))
    lastEndIndex = matchRange.lowerBound
  }
  results.append(String(input[lastEndIndex...]))

  return results
}

@MainActor
func _doSpeak(_ what: String) async {
  debugLogger.log("Enter: _doSpeak :: '\(what)'")

  let settings = await ss.getSpeechSettings()

  let textToSpeak = settings.splitCaps ? insertSpaceBeforeUppercase(what) : what
  let utterance = AVSpeechUtterance(string: textToSpeak)

  utterance.rate = settings.speechRate
  utterance.pitchMultiplier = settings.pitchMultiplier
  utterance.volume = settings.voiceVolume
  utterance.preUtteranceDelay = settings.nextPreDelay
  utterance.postUtteranceDelay = settings.postDelay
  utterance.voice = settings.voice

  let speaker = SpeakerManager.shared.synthesizer
  // Use audioTarget from settings to determine notification mode
  let isNotificationMode = settings.audioTarget == "right" || settings.audioTarget == "left"
  if isNotificationMode {
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

func isolateCommand(_ line: String) -> String {
  debugLogger.log("Enter: isolateCommand")
  let cmd = line.trimmingCharacters(in: .whitespacesAndNewlines)
  if let firstIndex = cmd.firstIndex(of: " ") {
    return String(cmd[..<firstIndex])
  }
  return cmd
}

func isolateCmdAndParams(_ line: String) -> (String, String) {
  debugLogger.log("Enter: isolateParams")
  let justCmd = isolateCommand(line)
  let cmd = justCmd + " "

  var params = line.replacingOccurrences(of: "^" + cmd, with: "", options: .regularExpression)
  params = params.trimmingCharacters(in: .whitespacesAndNewlines)
  if params.hasPrefix("{") && params.hasSuffix("}") {
    params = String(params.dropFirst().dropLast())
  }
  debugLogger.log("Exit: isolateParams: \(params)")
  return (justCmd, params)
}

await main()
