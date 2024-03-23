import AVFoundation
import AppKit
import Darwin
import Foundation
import OggDecoder

actor SoundManager {
    static let shared = SoundManager()
    
    private var currentSound: NSSound?
    
    func playSound(from url: URL, volume: Float) {
        // Stop the currently playing sound, if any
        if let sound = currentSound, sound.isPlaying {
            sound.stop()
        }
        
        // Create a new sound instance
        let sound = NSSound(contentsOf: url, byReference: true)
        sound?.volume = volume
        
        // Play the new sound
        sound?.play()
        
        // Set the new sound as the current sound
        currentSound = sound
    }
    
    func stopCurrentSound() {
        if let sound = currentSound, sound.isPlaying {
            sound.stop()
        }
    }
}
