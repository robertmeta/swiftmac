/*import AVFoundation
import AppKit
import Darwin
import Foundation

actor Logger {
  private let fileURL: URL

  init(fileName: String) {
    let fileManager = FileManager.default
    let directoryURL = URL(fileURLWithPath: "/tmp", isDirectory: true)

    fileURL = directoryURL.appendingPathComponent(fileName)

    // Create file if it doesn't exist
    if !fileManager.fileExists(atPath: fileURL.path) {
      fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
    }

  }

  func log(_ m: String) {
    #if DEBUG
    let message = m + "\n"

      do {
        let fileHandle = try FileHandle(forWritingTo: self.fileURL)
        defer { fileHandle.closeFile() }

        fileHandle.seekToEndOfFile()
        if let data = message.data(using: .utf8) {
          fileHandle.write(data)
        }
      } catch {
        print("Error writing to log file: \(error)")
      }
    #endif
    }
  }
*/
