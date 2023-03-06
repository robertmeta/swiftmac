#!/usr/bin/env swift
import Darwin
import Foundation
import AppKit

// Supporting Classes
class DelegateHandler: NSObject, NSSpeechSynthesizerDelegate {

    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        speaker.startSpeaking(backLog.pop())
    }
}

class Backlog {
    private var myBacklog: String = ""
    private let queue = DispatchQueue(label: "org.emacspeak.mac.swift")

    func clear()  {
        queue.async {
            self.myBacklog = ""
        }
    }
    
    func push(with: String) {
        queue.async {
            // Access myBacklog here
            self.myBacklog += with
        }
    }

    func pop() -> String {
        var result: String = ""
        queue.sync {
            // Access myBacklog here
            result = self.myBacklog
        }
        self.clear()
        return result
    }
}

// Global Constants
let version = "0.1"
let name = "mac.swift"

let speaker = NSSpeechSynthesizer()
let backLog = Backlog()
let dh = DelegateHandler()

// default values
let voice = NSSpeechSynthesizer.VoiceName(rawValue: "com.apple.speech.synthesis.voice.Alex")
speaker.setVoice(voice)
speaker.delegate = dh

// Entry point and main loop
func main() async {
    while let l = readLine() {
        let cmd = await isolateCommand(line: l)
        debugPrint(cmd)
        switch cmd { 
        case "a":
            await playAudioIcon(line: l)
        case "p":
            await playSound(line: l)
        case "tts_say": 
            await ttsSay(line: l)
        case "exit":
            await exitApp()
        case "q":
            await queueSpeaker(line: l)
        case "d":
            await dispatchSpeaker()
        case "s":
            await stopSpeaker()
        default:
            await unknownLine(line: l)
        }
    }
}

func stopSpeaker() async {
    speaker.stopSpeaking()
}

func dispatchSpeaker () async {
    speaker.startSpeaking(backLog.pop())
}

func queueSpeaker (line: String) async {
    let p = await isolateParams(line: line)
    backLog.push(with: " "+p)
}

// Does the same thing as "p " so route it over to playSound
func playAudioIcon(line: String) async {
    print("Playing audio icon: "+line)
    await playSound(line: line)
}

func playSound(line: String) async {
    print("Playing sound: "+line)
    let p = await isolateParams(line: line)
    let soundURL = URL(fileURLWithPath: p)
    NSSound(contentsOf: soundURL, byReference: true )?.play()
}

func ttsSay(line: String) async {
    print("ttsSay: "+line)
    let p = await isolateParams(line: line)
    await say(what: p, interupt: true)
    
}

func say(what: String, interupt: Bool) async {
    if interupt {
        speaker.startSpeaking(what)
    } else {
        if speaker.isSpeaking {
            backLog.push(with: what)
        } else {
            speaker.startSpeaking(what)
        }
    }
}

func unknownLine(line: String) async {
    debugPrint("Unknown command: "+line)
}

// TODO: make signals call this as well
func exitApp() async {
    print("Exiting "+name)
    exit(0)
}

// TODO: handle these, so far I know it uses voice
// and echo
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
    return cmd
}

func isolateParams(line: String) async -> String {
    let cmd = await isolateCommand(line: line)+" "
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
