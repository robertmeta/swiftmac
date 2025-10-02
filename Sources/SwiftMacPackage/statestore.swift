import AVFoundation
import AppKit
import Darwin
import Foundation
import OggDecoder

public actor StateStore {
  private var _allCapsBeep: Bool = false
  public var allCapsBeep: Bool {
    get { _allCapsBeep }
    set { _allCapsBeep = newValue }
  }

  private var _characterScale: Float = 1.2
  public var characterScale: Float {
    get { _characterScale }
    set { _characterScale = newValue }
  }

  private var _pendingQueue: [(String, String)] = []
  private var pendingQueueHead: Int = 0
  public var pendingQueue: [(String, String)] {
    get {
      guard pendingQueueHead < _pendingQueue.count else { return [] }
      return Array(_pendingQueue[pendingQueueHead...])
    }
    set {
      _pendingQueue = newValue
      pendingQueueHead = 0
    }
  }

  public func appendToPendingQueue(_ item: (String, String)) {
    _pendingQueue.append(item)
  }

  public func popFromPendingQueue() -> (String, String)? {
    guard pendingQueueHead < _pendingQueue.count else { return nil }
    let item = _pendingQueue[pendingQueueHead]
    pendingQueueHead += 1

    if pendingQueueHead == _pendingQueue.count {
      _pendingQueue.removeAll(keepingCapacity: true)
      pendingQueueHead = 0
    } else if pendingQueueHead > 32 && pendingQueueHead > _pendingQueue.count / 2 {
      _pendingQueue.removeFirst(pendingQueueHead)
      pendingQueueHead = 0
    }

    return item
  }

  // Clear the pending queue
  public func clearPendingQueue() {
    _pendingQueue.removeAll(keepingCapacity: true)
    pendingQueueHead = 0
  }

  private var _pitchMultiplier: Float = 1.0
  public var pitchMultiplier: Float {
    get { _pitchMultiplier }
    set { _pitchMultiplier = newValue }
  }

  private var _postDelay: TimeInterval = 0
  public var postDelay: TimeInterval {
    get { _postDelay }
    set { _postDelay = newValue }
  }

  private var _preDelay: TimeInterval = 0
  public var preDelay: TimeInterval {
    get { _preDelay }
    set { _preDelay = newValue }
  }

  private var _punctuations: String = "all"
  public var punctuations: String {
    get { _punctuations }
    set { _punctuations = newValue }
  }

  private var _audioTarget: String = "None"
  public var audioTarget: String {
    get { _audioTarget.lowercased() }
    set { _audioTarget = newValue }
  }

  private var _soundVolume: Float = 1
  public var soundVolume: Float {
    get { _soundVolume }
    set { _soundVolume = newValue }
  }

  private var _speechRate: Float = 0.5
  public var speechRate: Float {
    get { _speechRate }
    set { _speechRate = newValue }
  }

  private var _splitCaps: Bool = false
  public var splitCaps: Bool {
    get { _splitCaps }
    set { _splitCaps = newValue }
  }

  private var _toneVolume: Float = 1
  public var toneVolume: Float {
    get { _toneVolume }
    set { _toneVolume = newValue }
  }

  private var _ttsDiscard: Bool = false
  public var ttsDiscard: Bool {
    get { _ttsDiscard }
    set { _ttsDiscard = newValue }
  }

  private var _voice: AVSpeechSynthesisVoice = AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first ?? AVSpeechSynthesisVoice()
  public var voice: AVSpeechSynthesisVoice {
    get { _voice }
    set { _voice = newValue }
  }

  private var _voiceVolume: Float = 1
  public var voiceVolume: Float {
    get { _voiceVolume }
    set { _voiceVolume = newValue }
  }

  private var _nextPreDelay: TimeInterval = 0

  public func consumeNextPreDelay() -> TimeInterval {
    let value = _nextPreDelay
    _nextPreDelay = 0
    return value
  }

  public var nextPreDelay: TimeInterval {
    get { _nextPreDelay }
    set { _nextPreDelay = newValue }
  }

  public init() {
    self.soundVolume = 1.0
    if let f = Float(self.getEnvironmentVariable("SWIFTMAC_SOUND_VOLUME")) {
      self.soundVolume = f
    }

    self.toneVolume = 1.0
    if let f = Float(self.getEnvironmentVariable("SWIFTMAC_TONE_VOLUME")) {
      self.toneVolume = f
    }

    if let f = Float(self.getEnvironmentVariable("SWIFTMAC_VOICE_VOLUME")) {
      self.voiceVolume = f
    }

    self.audioTarget = self.getEnvironmentVariable("SWIFTMAC_AUDIO_TARGET")

    debugLogger.log("soundVolume \(self.soundVolume)")
    debugLogger.log("toneVolume \(self.toneVolume)")
    debugLogger.log("voiceVolume \(self.voiceVolume)")
  }

  public func getCharacterRate() async -> Float {
    return Float(Float(self.speechRate) * self.characterScale)
  }

  private func getEnvironmentVariable(_ variable: String) -> String {
    return ProcessInfo.processInfo.environment[variable] ?? ""
  }

  public func setAllCapsBeep(_ value: Bool) {
    self._allCapsBeep = value
  }

  public func setCharacterScale(_ value: Float) {
    self._characterScale = value
  }

  public func setPitchMultiplier(_ value: Float) {
    self._pitchMultiplier = value
  }

  public func setPostDelay(_ value: TimeInterval) {
    self._postDelay = value
  }

  public func setPreDelay(_ value: TimeInterval) {
    self._preDelay = value
  }

  public func setPunctuations(_ value: String) {
    self._punctuations = value
  }

  public func setSoundVolume(_ value: Float) {
    self._soundVolume = value
  }

  public func setSpeechRate(_ value: Float) {
    self._speechRate = value
  }

  public func setSplitCaps(_ value: Bool) {
    self._splitCaps = value
  }

  public func setToneVolume(_ value: Float) {
    self._toneVolume = value
  }

  public func setTtsDiscard(_ value: Bool) {
    self._ttsDiscard = value
  }

  func parseLang(_ input: String) -> (String, String) {
    let components = input.split(separator: ":", maxSplits: 1)

    switch components.count {
    case 1:
      if input.hasPrefix(":") {
        return ("none", String(components[0]))
      } else {
        return (String(components[0]), "none")
      }
    case 2:
      return (String(components[0]), String(components[1]))
    default:
      return ("none", "none")
    }
  }

  private var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

  public func setVoice(_ value: String) {
    let (language, voiceName) = parseLang(value)
    let cacheKey = "\(language)_\(voiceName)"

    if let cachedVoice = voiceCache[cacheKey] {
      self._voice = cachedVoice
    } else {
      let voiceIdentifier = self.getVoiceIdentifier(language: language, voiceName: voiceName)

      if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
        self._voice = voice
        voiceCache[cacheKey] = voice
      } else {
        self._voice = AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first ?? AVSpeechSynthesisVoice()
      }
    }
  }

  private func getVoiceIdentifier(language: String?, voiceName: String?) -> String {
    debugLogger.log("Enter: getVoiceIdentifier")

    let defaultVoice = AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first ?? AVSpeechSynthesisVoice()

    let voices = AVSpeechSynthesisVoice.speechVoices()

    // Check if an exact identifier match is provided
    if let voiceName = voiceName, voiceName.contains(".") {
      if let voice = voices.first(where: { $0.identifier == voiceName }) {
        return voice.identifier
      }
    }

    // Check if both language and voiceName are provided
    if let language = language, let voiceName = voiceName {
      if let voice = voices.first(where: { $0.language == language && $0.name == voiceName }) {
        return voice.identifier
      }
    }

    // Check if only language is provided
    if let language = language {
      if let voice = voices.first(where: { $0.language == language }) {
        return voice.identifier
      }
    }

    // Check if only voiceName is provided
    if let voiceName = voiceName {
      if let voice = voices.first(where: { $0.name == voiceName }) {
        return voice.identifier
      }
    }

    // If no matching voice is found, return the default voice identifier
    return defaultVoice.identifier
  }

  public func setVoiceVolume(_ value: Float) {
    self._voiceVolume = value
  }

  public func setNextPreDelay(_ value: TimeInterval) {
    self._nextPreDelay = value
  }
  
  // Batch read for speech settings to reduce actor calls
  public func getSpeechSettings() -> (
    splitCaps: Bool,
    speechRate: Float,
    pitchMultiplier: Float,
    voiceVolume: Float,
    nextPreDelay: TimeInterval,
    postDelay: TimeInterval,
    voice: AVSpeechSynthesisVoice,
    audioTarget: String
  ) {
    let preDelay = consumeNextPreDelay()
    return (
      splitCaps: _splitCaps,
      speechRate: _speechRate,
      pitchMultiplier: _pitchMultiplier,
      voiceVolume: _voiceVolume,
      nextPreDelay: preDelay,
      postDelay: _postDelay,
      voice: _voice,
      audioTarget: _audioTarget
    )
  }

  public func reset() async {
    _allCapsBeep = false
    _characterScale = 1.2
    _pendingQueue.removeAll()
    pendingQueueHead = 0
    _pitchMultiplier = 1.0
    _postDelay = 0
    _preDelay = 0
    _punctuations = "all"
    _audioTarget = "None"
    _soundVolume = 1.0
    _speechRate = 0.5
    _splitCaps = false
    _toneVolume = 1.0
    _ttsDiscard = false
    _voice = AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first ?? AVSpeechSynthesisVoice()
    _voiceVolume = 1.0
    _nextPreDelay = 0
    voiceCache.removeAll()
    
    // Reapply environment variables
    if let f = Float(self.getEnvironmentVariable("SWIFTMAC_SOUND_VOLUME")) {
      self._soundVolume = f
    }
    if let f = Float(self.getEnvironmentVariable("SWIFTMAC_TONE_VOLUME")) {
      self._toneVolume = f
    }
    if let f = Float(self.getEnvironmentVariable("SWIFTMAC_VOICE_VOLUME")) {
      self._voiceVolume = f
    }
    self._audioTarget = self.getEnvironmentVariable("SWIFTMAC_AUDIO_TARGET")
  }
}
