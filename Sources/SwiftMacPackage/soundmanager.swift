import AVFoundation
import Foundation

actor SoundManager {
    static let shared = SoundManager()
    private var audioPlayers: [UUID: AVAudioPlayer] = [:]
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    func playSound(from url: URL, volume: Float) async {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()

            let playerId = UUID()
            audioPlayers[playerId] = player

            player.play()

            let duration = max(player.duration, 0.1)
            let cleanupDelay = duration + 0.1

            // Store task so it can be cancelled
            let task = Task {
                try? await Task.sleep(nanoseconds: UInt64(cleanupDelay * 1_000_000_000))
                await cleanupPlayer(playerId)
            }
            activeTasks[playerId] = task

            await task.value
        } catch {
            debugLogger.log("Error loading sound: \(error)")
        }
    }

    private func cleanupPlayer(_ playerId: UUID) {
        if let player = audioPlayers[playerId] {
            player.stop()
            audioPlayers[playerId] = nil
        }
        activeTasks[playerId] = nil
    }

    func stop() {
        // Cancel all pending tasks
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()

        // Stop all playing audio
        for (_, player) in audioPlayers {
            player.stop()
        }
        audioPlayers.removeAll()
    }
}
