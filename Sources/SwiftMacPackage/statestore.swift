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
    
    private var _deadpanMode: Bool = false
    public var deadpanMode: Bool {
        get { _deadpanMode }
        set { _deadpanMode = newValue }
    }

    private var _pendingQueue: [String] = []
    public var pendingQueue: [String] {
        get { _pendingQueue }
        set { _pendingQueue = newValue }
    }
    
    public func appendToPendingQueue(_ item: String) {
        _pendingQueue.append(item)
    }
    
    public func popFromPendingQueue() -> String? {
        if !_pendingQueue.isEmpty {
            return _pendingQueue.removeFirst()
        }
        return nil
    }
    
    // Clear the pending queue
    public func clearPendingQueue() {
        _pendingQueue.removeAll()
    }
    
    private var _pitchModification: Float = 1.0
    public var pitchModification: Float {
        get { _pitchModification }
        set { _pitchModification = newValue }
    }
    
    private var _postDelay: Float = 0
    public var postDelay: Float {
        get { _postDelay }
        set { _postDelay = newValue }
    }
    
    private var _preDelay: Float = 0
    public var preDelay: Float {
        get { _preDelay }
        set { _preDelay = newValue }
    }
    
    private var _punctuations: String = "all"
    public var punctuations: String {
        get { _punctuations }
        set { _punctuations = newValue }
    }
    
    private var _soundVolume: Float = 1
    public var soundVolume: Float {
        get { _soundVolume }
        set { _soundVolume = newValue }
    }
    
    private var _speechRate: Int = 200
    public var speechRate: Int {
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
    
    private var _voice: String = "default"
    public var voice: String {
        get { _voice }
        set { _voice = newValue }
    }
    
    private var _voiceVolume: Float = 1
    public var voiceVolume: Float {
        get { _voiceVolume }
        set { _voiceVolume = newValue }
    }
    
    public  init() {
        print("E")
        print(self.getEnvironmentVariable("SWIFTMAC_SOUND_VOLUME"))
        self.toneVolume = 1.0
        print("F")
        if let f = Float(self.getEnvironmentVariable("SWIFTMAC_TONE_VOLUME")) {
            self.toneVolume = f
        }
        print("G")
        if let f = Float(self.getEnvironmentVariable("SWIFTMAC_VOICE_VOLUME")) {
            self.voiceVolume = f
        }
        print("H")
        if let f = Bool(self.getEnvironmentVariable("SWIFTMAC_DEADPAN_MODE")) {
            self.deadpanMode = f
        }
        debugLogger.log("TEST")
        print("I")
        debugLogger.log("soundVolume \(self.soundVolume)")
        debugLogger.log("toneVolume \(self.toneVolume)")
        debugLogger.log("voiceVolume \(self.voiceVolume)")
        debugLogger.log("deadpanMode \(self.deadpanMode)")
        
        // Example: Print a message when a new instance is created
        print("SpeechState initialized")
    }
    
    public func getCharacterRate() -> Int {
        return Int(Float(self.speechRate) * self.characterScale)
    }
    
    public func getEnvironmentVariable(_ variable: String) -> String {
        return ProcessInfo.processInfo.environment[variable] ?? ""
    }
}
