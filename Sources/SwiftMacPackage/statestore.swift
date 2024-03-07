import AVFoundation
import AppKit
import Darwin
import Foundation

actor StateStore {
  private var backlog: [String] = []  // Now a vector (array) of strings
  // Assume default values are defined somewhere else
  public var splitCaps: Bool = defaultSplitCaps
  public var voice = defaultVoice
  public var beepCaps: Bool = defaultBeepCaps
  public var charScale: Float = defaultCharScale
  public var punct: String = defaultPunct

  func clearBacklog() {
    debugLogger.log("Enter: clearBacklog")
    self.backlog = []
  }

  func removePmodPatterns(_ inputString: String) -> String {
    // Define the regular expression pattern to match `[[pmod .*?]]`
    let pattern = "\\[\\[pmod .*?\\]\\]"

    // Attempt to create a regular expression
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      print("Invalid regular expression.")
      return inputString
    }

    // Perform the replacement - replace occurrences of the pattern with an empty string
    let range = NSRange(location: 0, length: inputString.utf16.count)
    let modifiedString = regex.stringByReplacingMatches(
      in: inputString, options: [], range: range, withTemplate: "")

    return modifiedString
  }

  func fixupCodes(_ inputString: String) -> String {
    // Regular expression pattern to match `[[pmod <digits>]]`
    let pattern = "\\[\\[pbas (\\d+)\\]\\]"

    // Replacement template adds a plus sign before the digits
    let replacementTemplate = "[[pbas +$1]]"

    // Attempt to create a regular expression
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      print("Invalid regular expression.")
      return inputString
    }

    // Perform the replacement
    let range = NSRange(location: 0, length: inputString.utf16.count)
    let modifiedString = regex.stringByReplacingMatches(
      in: inputString, options: [], range: range, withTemplate: replacementTemplate)

    return modifiedString
  }

  func pushBacklog(_ with: String, code: Bool = false) {
    debugLogger.log("Enter: pushBacklog")
    let punct = self.getPunct().lowercased()
    var w = stripSpecialEmbeds(with)
    if code {
      w = fixupCodes(w)
      w = removePmodPatterns(w)
    } else {
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
    let result = self.backlog.joined(separator: " ")  // Join elements to form a single string
    self.clearBacklog()
    return result
  }
}
