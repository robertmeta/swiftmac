import AVFoundation
import AppKit
import Darwin
import Foundation

class Logger {
  #if DEBUG
    private let fileURL: URL
    private let backgroundQueue: DispatchQueue
    private var fileHandle: FileHandle?

    init(fileName: String) {
      let fileManager = FileManager.default
      let directoryURL = URL(fileURLWithPath: "/tmp", isDirectory: true)

      // Get the process ID (PID)
      let pid = ProcessInfo.processInfo.processIdentifier

      // Append the PID to the filename
      let fileNameWithPID = "\(fileName)_\(pid).log"

      fileURL = directoryURL.appendingPathComponent(fileNameWithPID)

      // Create file if it doesn't exist
      if !fileManager.fileExists(atPath: fileURL.path) {
        fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
      }

      backgroundQueue = DispatchQueue(
        label: "org.emacspeak.server.swiftmac.logger", qos: .background)
      
      // Initialize persistent file handle
      do {
        fileHandle = try FileHandle(forWritingTo: fileURL)
      } catch {
        print("Error opening log file handle: \(error)")
      }
    }
    
    deinit {
      fileHandle?.closeFile()
    }

    func log(_ m: String) {
      let message = m + "\n"
      backgroundQueue.async { [weak self] in
        guard let self = self,
              let handle = self.fileHandle,
              let data = message.data(using: .utf8) else { return }

        handle.seekToEndOfFile()
        handle.write(data)
      }
    }
  #else
    func log(_ m: String) {
    }
  #endif
}
