import Foundation

/// File-based logger for device debugging when Console.app doesn't show logs
/// Writes to Documents/heirloom_debug.log which can be viewed via Files app or Xcode
class DeviceLogger {
    static let shared = DeviceLogger()

    private let logFileName = "heirloom_debug.log"
    private var logFileURL: URL?

    private init() {
        setupLogFile()
    }

    private func setupLogFile() {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        logFileURL = documentsDirectory.appendingPathComponent(logFileName)

        // Create file if it doesn't exist
        if let url = logFileURL, !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        // Log the file location
        if let url = logFileURL {
            log("📁 Log file created at: \(url.path)")
        }
    }

    /// Log a message with timestamp
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "\(timestamp) [\(level.emoji)] \(message)\n"

        // Also print to console (for Xcode debugging)
        print(logMessage.trimmingCharacters(in: .newlines))

        // Write to file
        guard let url = logFileURL else { return }

        do {
            let fileHandle = try FileHandle(forWritingTo: url)
            fileHandle.seekToEndOfFile()
            if let data = logMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } catch {
            // If file doesn't exist, create it
            try? logMessage.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Clear the log file
    func clearLog() {
        guard let url = logFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        setupLogFile()
    }

    /// Get the log file contents
    func getLogContents() -> String? {
        guard let url = logFileURL else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Get the log file URL for sharing
    func getLogFileURL() -> URL? {
        return logFileURL
    }
}

// MARK: - Log Levels

extension DeviceLogger {
    enum LogLevel {
        case info
        case warning
        case error
        case debug

        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .debug: return "🔍"
            }
        }
    }
}
