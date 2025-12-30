import AVFoundation
import AppKit
import CoreAudio
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
let version = "4.3.2"
let name = "swiftmac"
var ss = StateStore()  // just create new one to reset

@MainActor
final class SpeakerManager {
  static let shared = SpeakerManager()
  let synthesizer = AVSpeechSynthesizer()

  private init() {}
}

// Track active audio tasks so they can be cancelled
actor AudioTaskManager {
  static let shared = AudioTaskManager()
  private var activeTasks: Set<Task<Void, Never>> = []

  func addTask(_ task: Task<Void, Never>) {
    activeTasks.insert(task)
  }

  func removeTask(_ task: Task<Void, Never>) {
    activeTasks.remove(task)
  }

  func cancelAll() {
    for task in activeTasks {
      task.cancel()
    }
    activeTasks.removeAll()
  }
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
var cachedSpeechRouting: AudioRouting = AudioRouting()
var cachedNotificationRouting: AudioRouting = AudioRouting(channelMode: .left)
var currentAudioMode: String = "both"
var isNotificationServer: Bool = false

// Chunk queue for sequential playback
class ChunkQueue {
  private var chunks: [AVSpeechUtterance] = []
  private var isProcessing = false
  private let lock = NSLock()

  func enqueue(_ utterances: [AVSpeechUtterance]) {
    lock.lock()
    chunks.append(contentsOf: utterances)
    lock.unlock()
    processNext()
  }

  func processNext() {
    lock.lock()
    guard !isProcessing, !chunks.isEmpty else {
      lock.unlock()
      return
    }

    isProcessing = true
    let utterance = chunks.removeFirst()
    lock.unlock()

    // Synthesize this chunk
    DispatchQueue.global().async {
      SpeakerManager.shared.synthesizer.write(utterance, toBufferCallback: bufferHandler)
    }
  }

  func notifyComplete() {
    lock.lock()
    isProcessing = false
    lock.unlock()
    processNext()
  }

  func clear() {
    lock.lock()
    chunks.removeAll()
    isProcessing = false
    lock.unlock()
  }
}

let chunkQueue = ChunkQueue()

// Aggressive silence trimming - safe now because chunks are single-buffer units
func detectSilenceBounds(buffer: AVAudioPCMBuffer, threshold: Float = 0.01) -> (
  start: Int, end: Int
)? {
  guard let channelData = buffer.floatChannelData?[0] else { return nil }
  let frameLength = Int(buffer.frameLength)

  // Find first non-silent sample
  var start = 0
  for i in 0..<frameLength {
    if abs(channelData[i]) > threshold {
      start = i
      break
    }
  }

  // Find last non-silent sample
  var end = frameLength - 1
  for i in stride(from: frameLength - 1, through: 0, by: -1) {
    if abs(channelData[i]) > threshold {
      end = i
      break
    }
  }

  if start >= end {
    return nil
  }

  return (start, end)
}

func trimSilence(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
  guard let bounds = detectSilenceBounds(buffer: buffer) else {
    return buffer
  }

  let trimmedLength = bounds.end - bounds.start + 1
  guard let format = buffer.format as? AVAudioFormat,
    let trimmedBuffer = AVAudioPCMBuffer(
      pcmFormat: format, frameCapacity: AVAudioFrameCount(trimmedLength))
  else {
    return buffer
  }

  trimmedBuffer.frameLength = AVAudioFrameCount(trimmedLength)

  // Copy non-silent audio data
  for channel in 0..<Int(buffer.format.channelCount) {
    guard let sourceData = buffer.floatChannelData?[channel],
      let destData = trimmedBuffer.floatChannelData?[channel]
    else {
      continue
    }

    for i in 0..<trimmedLength {
      destData[i] = sourceData[bounds.start + i]
    }
  }

  return trimmedBuffer
}

// Apply channel mode to buffer via PCM manipulation
func applyChannelMode(to inputBuffer: AVAudioPCMBuffer, mode: ChannelMode) -> AVAudioPCMBuffer {
  let inputFormat = inputBuffer.format
  let frameCount = Int(inputBuffer.frameLength)

  // Create stereo output format
  guard
    let outputFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: inputFormat.sampleRate,  // Preserve sample rate!
      channels: 2,
      interleaved: false
    )
  else {
    return inputBuffer
  }

  guard
    let outputBuffer = AVAudioPCMBuffer(
      pcmFormat: outputFormat,
      frameCapacity: inputBuffer.frameCapacity
    )
  else {
    return inputBuffer
  }

  outputBuffer.frameLength = inputBuffer.frameLength

  guard let inputChannel0 = inputBuffer.floatChannelData?[0],
    let outputLeft = outputBuffer.floatChannelData?[0],
    let outputRight = outputBuffer.floatChannelData?[1]
  else {
    return inputBuffer
  }

  let inputChannel1 = inputFormat.channelCount > 1 ? inputBuffer.floatChannelData?[1] : nil

  switch mode {
  case .left:
    memcpy(outputLeft, inputChannel0, frameCount * MemoryLayout<Float>.size)
    memset(outputRight, 0, frameCount * MemoryLayout<Float>.size)

  case .right:
    memset(outputLeft, 0, frameCount * MemoryLayout<Float>.size)
    if let rightInput = inputChannel1 {
      memcpy(outputRight, rightInput, frameCount * MemoryLayout<Float>.size)
    } else {
      memcpy(outputRight, inputChannel0, frameCount * MemoryLayout<Float>.size)
    }

  case .both:
    if let rightInput = inputChannel1 {
      memcpy(outputLeft, inputChannel0, frameCount * MemoryLayout<Float>.size)
      memcpy(outputRight, rightInput, frameCount * MemoryLayout<Float>.size)
    } else {
      memcpy(outputLeft, inputChannel0, frameCount * MemoryLayout<Float>.size)
      memcpy(outputRight, inputChannel0, frameCount * MemoryLayout<Float>.size)
    }
  }

  return outputBuffer
}

let bufferHandler: (AVAudioBuffer) -> Void = { buffer in
  guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

  // Detect end of utterance - notify chunk queue to process next
  if pcmBuffer.frameLength == 0 {
    chunkQueue.notifyComplete()
    return
  }

  // Trim silence aggressively (safe because chunks are single-buffer units)
  guard let trimmedBuffer = trimSilence(buffer: pcmBuffer) else { return }

  // Determine routing (device + channel) based on server type
  let routing = isNotificationServer ? cachedNotificationRouting : cachedSpeechRouting

  // Apply PCM channel manipulation (synchronous)
  let channelBuffer = applyChannelMode(to: trimmedBuffer, mode: routing.channelMode)

  setupLock.lock()
  let needsSetup = outputFormat == nil
  if needsSetup {
    outputFormat = channelBuffer.format

    // Set output device if specified (0 means system default)
    if routing.deviceID != 0 {
      #if os(macOS)
        do {
          try engine.outputNode.auAudioUnit.setDeviceID(routing.deviceID)
          debugLogger.log("Set output device to \(routing.deviceID)")
        } catch {
          debugLogger.log("Failed to set output device: \(error)")
        }
      #endif
    }

    engine.connect(playerNode, to: environmentNode, format: outputFormat)
    engine.connect(environmentNode, to: engine.mainMixerNode, format: nil)

    if currentAudioMode == "right" {
      environmentNode.position = AVAudio3DPoint(x: 1, y: 0, z: 0)
    } else if currentAudioMode == "left" {
      environmentNode.position = AVAudio3DPoint(x: -1, y: 0, z: 0)
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

  // Schedule the channel-processed buffer for playback
  playerNode.scheduleBuffer(channelBuffer)

  if !playerNode.isPlaying {
    playerNode.play()
  }
}

func notificationMode() async -> Bool {
  return await ss.isNotificationServer
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

  // Setup audio engine for buffer-based playback (needed for all modes now)
  engine.attach(playerNode)
  engine.attach(environmentNode)

  // Cache routing configs and mode for sync access in bufferHandler
  cachedSpeechRouting = await ss.speechRouting
  cachedNotificationRouting = await ss.notificationRouting
  currentAudioMode = await ss.audioTarget.lowercased()
  isNotificationServer = await ss.isNotificationServer

  if await notificationMode() {
    await Task { @MainActor in
      await instantTtsSay("notification mode on")
    }.value
  } else {
    await Task { @MainActor in
      await instantVersion()
    }.value
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
      try? await Task.sleep(nanoseconds: 1_000_000_000)  // Sleep for 1 second
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
  case "l": await Task { @MainActor in await instantLetter(params) }.value
  case "p": await doPlaySound(params)
  case "q": await queueLine(cmd, params)
  case "s": await Task { @MainActor in await instantStopSpeaking() }.value
  case "sh": await queueLine(cmd, params)
  case "t": await queueLine(cmd, params)
  case "tts_allcaps_beep": await queueLine(cmd, params)
  case "set_lang": await ttsSetVoice(params)
  case "tts_exit": await instantTtsExit()
  case "tts_reset": await Task { @MainActor in await instantTtsReset() }.value
  case "tts_say": await Task { @MainActor in await instantTtsSay(params) }.value
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
  case "version": await Task { @MainActor in await instantVersion() }.value
  // Channel control commands
  case "tts_set_speech_channel": await setSpeechChannel(params)
  case "tts_set_notification_channel": await setNotificationChannel(params)
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
    case "q": await Task { @MainActor in await doSpeak(params) }.value
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

// Split text into small chunks (15 words) to ensure single-buffer utterances
func chunkText(_ text: String, maxWords: Int = 15) -> [String] {
  let words = text.split(separator: " ", omittingEmptySubsequences: true)

  guard words.count > maxWords else {
    return [text]
  }

  var chunks: [String] = []
  var currentChunk: [String.SubSequence] = []

  for word in words {
    currentChunk.append(word)
    if currentChunk.count >= maxWords {
      chunks.append(currentChunk.joined(separator: " "))
      currentChunk = []
    }
  }

  if !currentChunk.isEmpty {
    chunks.append(currentChunk.joined(separator: " "))
  }

  return chunks
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

@MainActor
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

@MainActor
func instantLetter(_ p: String) async {
  debugLogger.log("Enter: instantLetter")
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
  // Reset playerNode to flush all scheduled buffers
  // This prevents old audio from playing after stop
  playerNode.reset()

  // Clear any pending chunks
  chunkQueue.clear()

  debugLogger.log("Speech stopped and buffers flushed")
  // NOTE: We do NOT cancel audio icons and tones here
  // This allows beeps/audio to overlap with speech
  // Only speech itself is stopped
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
    .replacingOccurrences(of: "~", with: " tilde ")
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

// MARK: - Channel Control Commands

func setSpeechChannel(_ params: String) async {
  debugLogger.log("Enter: setSpeechChannel with params: \(params)")
  guard let mode = ChannelMode(rawValue: params.lowercased()) else {
    debugLogger.log("Invalid channel mode: \(params). Use: left, right, or both")
    return
  }

  var routing = await ss.speechRouting
  routing.channelMode = mode
  await ss.setSpeechRouting(routing)

  // Update cached config for immediate effect
  cachedSpeechRouting = routing

  debugLogger.log("Switched speech channel to \(mode)")
}

func setNotificationChannel(_ params: String) async {
  debugLogger.log("Enter: setNotificationChannel with params: \(params)")
  guard let mode = ChannelMode(rawValue: params.lowercased()) else {
    debugLogger.log("Invalid channel mode: \(params). Use: left, right, or both")
    return
  }

  var routing = await ss.notificationRouting
  routing.channelMode = mode
  await ss.setNotificationRouting(routing)

  // Update cached config for immediate effect
  cachedNotificationRouting = routing

  debugLogger.log("Switched notification channel to \(mode)")
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
  let volume = await ss.toneVolume
  let routing = await ss.toneRouting

  let task = Task {
    await tonePlayer.playPureTone(
      frequencyInHz: Int(ps[0]) ?? 500,
      amplitude: volume,
      durationInMillis: Int(ps[1]) ?? 75,
      routing: routing
    )
  }
  await AudioTaskManager.shared.addTask(task)

  // Clean up after task completes
  Task {
    _ = await task.value
    await AudioTaskManager.shared.removeTask(task)
  }
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
    let routing = await ss.soundEffectRouting

    let task = Task {
      await SoundManager.shared.playSound(from: url, volume: volume, routing: routing)
    }
    await AudioTaskManager.shared.addTask(task)

    // Clean up after task completes
    Task {
      _ = await task.value
      await AudioTaskManager.shared.removeTask(task)
    }
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

@MainActor
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

  // Split into chunks for single-buffer utterances
  let textChunks = chunkText(textToSpeak)
  debugLogger.log("Split text into \(textChunks.count) chunks")

  // Create utterances for each chunk
  var utterances: [AVSpeechUtterance] = []
  for (index, chunk) in textChunks.enumerated() {
    let utterance = AVSpeechUtterance(string: chunk)

    utterance.rate = settings.speechRate
    utterance.pitchMultiplier = settings.pitchMultiplier
    utterance.volume = settings.voiceVolume

    // Only first chunk gets pre-delay, only last gets post-delay
    utterance.preUtteranceDelay = (index == 0) ? settings.nextPreDelay : 0
    utterance.postUtteranceDelay = (index == textChunks.count - 1) ? settings.postDelay : 0
    utterance.voice = settings.voice

    utterances.append(utterance)
  }

  // Enqueue all chunks for sequential playback
  chunkQueue.enqueue(utterances)
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
