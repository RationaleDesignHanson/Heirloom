import Foundation

/// File-based logger for device debugging when Console.app doesn't show logs
/// Writes to Documents/heirloom_debug.log which can be viewed via Files app or Xcode
class DeviceLogger {
    private let logFileName = "heirloom_debug.log"
    private var logFileURL: URL?

    init() {
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

// MARK: - Global Convenience

/// Fallback DeviceLogger used when ServiceContainer hasn't been configured yet
/// This prevents crashes during static initialization or test environments
private let _fallbackDeviceLogger = DeviceLogger()

extension DeviceLogger {
    /// Global accessor that resolves from ServiceContainer for proper DI
    /// Maintains backward compatibility with existing .shared usage
    /// Falls back to a standalone logger if ServiceContainer isn't ready
    /// Note: Safe to use from any context - no MainActor assumption
    nonisolated(unsafe) static var shared: DeviceLogger {
        let container = ServiceContainer.sharedUnsafe

        // Check if DeviceLogger is registered
        if container.isRegistered(DeviceLogger.self) {
            // Service is registered - resolve it
            return container.resolveUnsafe(DeviceLogger.self)
        } else {
            // Service not registered yet - use fallback logger
            // This prevents crashes during static initialization
            return _fallbackDeviceLogger
        }
    }
}
