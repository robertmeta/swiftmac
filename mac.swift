#!/usr/bin/env swift
import Darwin
import Foundation
import AppKit

// Global Constants
let version = "0.1"
let name = "mac.swift"
let audioIconCmd  = "a "
let ttsSayCmd     = "tts_say "
let playSoundCmd  = "p "
let queueCmd      = "q "
let stopCmd       = "s "
let dispatchCmd   = "d "
let speechSynthesizer = NSSpeechSynthesizer()
@MainActor
var speechQueue: String = ""
@MainActor
let queue = DispatchQueue(label: "com.example.myqueue", attributes: .concurrent)

let semaphore = DispatchSemaphore(value: 1)


// default values
let voice = NSSpeechSynthesizer.VoiceName(rawValue: "com.apple.speech.synthesis.voice.Alex")
speechSynthesizer.setVoice(voice)

// Entry point and main loop
func main() async {
    while let l = readLine() {
        print(await isolateCommand(line: l))
        debugPrint(await stripSpecialEmbeds(l))
        if l.hasPrefix(audioIconCmd) {
            await playAudioIcon(line: l)
        } else if l.hasPrefix(playSoundCmd) {
            await playSound(line: l)
        } else if l.hasPrefix(ttsSayCmd) {
            await ttsSay(line: l)
        } else if l == "exit" {
            await exitApp()
        } else {
            await unknownLine(line: l)
        }
    }
}

// Does the same thing as "p " so route it over to playSound
func playAudioIcon(line: String) async {
    print("Playing audio icon: "+line)
    await playSound(line: line)
}

func playSound(line: String) async {
    print("Playing sound: "+line)
    let p = await isolateParams(line: line, cmd: playSoundCmd)
    let soundURL = URL(fileURLWithPath: p)
    NSSound(contentsOf: soundURL, byReference: true )?.play()
}

func ttsSay(line: String) async {
    print("ttsSay: "+line)
    let p = await isolateParams(line: line, cmd: ttsSayCmd)
    await say(what: p, interupt: true)
    
}

func say(what: String, interupt: Bool) async {
    if interupt {
        speechSynthesizer.startSpeaking(what)
    } else {
        if speechSynthesizer.isSpeaking {
            queue.async {
                semaphore.wait()
                speechQueue += " "+what
                semaphore.signal()
            }
        } else {
            speechSynthesizer.startSpeaking(what)
        }
    }
}

func unknownLine(line: String) async {
    debugPrint("Unknown command: "+line)
}

func exitApp() async {
    print("Exiting "+name)
    exit(0)
}

func stripSpecialEmbeds(_ s: String) async -> String {
    let specialEmbedRegexp = #"\[\{.*?\}\]"#
    return s.replacingOccurrences(of: specialEmbedRegexp, with: "", options: .regularExpression)    
}

func isolateCommand(line: String) async -> String {
    var cmd = line.trimmingCharacters(in: .whitespacesAndNewlines)
    if let firstIndex = cmd.firstIndex(of: " ") {
        cmd.replaceSubrange(firstIndex..<cmd.endIndex, with: "")
        return cmd
    }
    return ""
}

func isolateParams(line: String, cmd: String) async -> String {
    var params = line.replacingOccurrences(of: cmd, with: "")
    params = params.trimmingCharacters(in: .whitespacesAndNewlines)
    if params.hasPrefix("{") && params.hasSuffix("}") {
        if let lastIndex = params.lastIndex(of: "}") {
            params.replaceSubrange(lastIndex...lastIndex, with: "")
        }
        if let firstIndex = params.firstIndex(of: "{") {
            params.replaceSubrange(firstIndex...firstIndex, with: "")
        }
    }
    return params
}

await main()
