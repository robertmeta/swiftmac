import AVFoundation
import AppKit
import Darwin
import Foundation

actor StateStore {
  private var backlog: [String] = []  // Now a vector (array) of strings
  // Assume default values are defined somewhere else
  private var splitCaps: Bool = defaultSplitCaps
  private var voice = defaultVoice
  private var beepCaps: Bool = defaultBeepCaps
  private var charScale: Float = defaultCharScale
  private var punct: String = defaultPunct

  func clearBacklog() {
    debugLogger.log("Enter: clearBacklog")
    self.backlog = []
  }

  func pushBacklog(_ with: String, code: Bool = false) {
    debugLogger.log("Enter: pushBacklog")
    let punct = self.getPunct().lowercased()
    var w = stripSpecialEmbeds(with)
    if !code {
      switch punct {
      case "all":
        w = replaceAllPuncs(w)
      case "some":
        w = replaceSomePuncs(w)
      case "none":
        w = replaceBasePuncs(w)
      default:
        w = replaceCore(w)
      }
    }
    self.backlog.append(w)  // Append the processed string as a new element
  }

  func popBacklog() -> String {
    debugLogger.log("Enter: popBacklog")
    guard !self.backlog.isEmpty else { return "" }
    let result = self.backlog.joined(separator: " ") // Join elements to form a single string
    self.clearBacklog()
    return result
  }

  func setCharScale(_ r: Float) {
    debugLogger.log("Enter: setCharScale")
    self.charScale = r
  }

  func getCharScale() -> Float {
    debugLogger.log("Enter: getCharScale")
    return self.charScale
  }

  func setPunct(_ s: String) {
    debugLogger.log("Enter: setPunct")
    self.punct = s
  }

  func getPunct() -> String {
    debugLogger.log("Enter: getPunct")
    return self.punct
  }

  func setSplitCaps(_ b: Bool) {
    debugLogger.log("Enter: setSplitCaps")
    self.splitCaps = b
  }

  func getSplitCaps() -> Bool {
    debugLogger.log("Enter: getSplitCaps")
    return self.splitCaps
  }

  func setBeepCaps(_ b: Bool) {
    debugLogger.log("Enter: setBeepCaps")
    self.beepCaps = b
  }

  func getBeepCaps() -> Bool {
    debugLogger.log("Enter: getBeepCaps")
    return self.beepCaps
  }
}
