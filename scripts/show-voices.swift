import AVFoundation

// List all available voices and their identifiers
let voices = AVSpeechSynthesisVoice.speechVoices()
print("Available Voices and Their Identifiers:")

for voice in voices {
    print("Language: \(voice.language), Identifier: \(voice.identifier), Name: \(voice.name), Quality: \(voice.quality.rawValue)")
}
