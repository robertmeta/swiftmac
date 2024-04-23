import AVFoundation

var audioPlayer = AVAudioPlayer()

let oggFile = URL(fileURLWithPath: "/tmp/test.ogg")

do {
    audioPlayer = try AVAudioPlayer(contentsOf: oggFile)
} catch {
    print("Error loading OGG file: \(error)")
}

audioPlayer.play()
