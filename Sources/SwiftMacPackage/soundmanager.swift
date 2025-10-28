import AVFoundation
import Foundation

actor SoundManager {
    static let shared = SoundManager()
    private var audioPlayers: [UUID: AVAudioPlayer] = [:]

    func playSound(from url: URL, volume: Float) async {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            
            // Generate a unique ID for each player instance
            let playerId = UUID()
            audioPlayers[playerId] = player
            
            // Set up completion handling before starting playback
            player.play()
            
            // Calculate safe cleanup delay - ensure minimum duration and handle edge cases
            let duration = max(player.duration, 0.1) // Minimum 100ms
            let cleanupDelay = duration + 0.1 // Add 100ms buffer
            
            // Use Task.sleep with safe duration
            try await Task.sleep(nanoseconds: UInt64(cleanupDelay * 1_000_000_000))

            // Cleanup the player after it finishes
            await cleanupPlayer(playerId)
        } catch {
            print("Error loading sound: \(error)")
        }
    }
    
    private func cleanupPlayer(_ playerId: UUID) {
        if let player = audioPlayers[playerId] {
            player.stop()
            audioPlayers[playerId] = nil
        }
    }
}
