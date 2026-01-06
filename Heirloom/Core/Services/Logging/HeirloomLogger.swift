//
//  HeirloomLogger.swift
//  Heirloom
//
//  Phase 4: Code Quality & Cleanup
//  Production implementation of structured logging service
//

import Foundation
import os.log

/// Production logging implementation using OSLog for performance
final class HeirloomLogger: LoggingService {
    // MARK: - Configuration

    var minimumLevel: LogLevel = .debug

    var enabledCategories: Set<LogCategory> = []

    // MARK: - Private Properties

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private let queue = DispatchQueue(label: "com.heirloom.logging", qos: .utility)

    // MARK: - Initialization

    init() {
        #if DEBUG
        minimumLevel = .debug
        #else
        minimumLevel = .info
        #endif
    }

    // MARK: - LoggingService Implementation

    func debug(
        _ message: String,
        category: LogCategory,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        log(level: .debug, message: message, category: category, error: nil, metadata: metadata, file: file, function: function, line: line)
        #endif
    }

    func info(
        _ message: String,
        category: LogCategory,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, category: category, error: nil, metadata: metadata, file: file, function: function, line: line)
    }

    func warning(
        _ message: String,
        category: LogCategory,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message, category: category, error: nil, metadata: metadata, file: file, function: function, line: line)
    }

    func error(
        _ message: String,
        category: LogCategory,
        error: Error? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, message: message, category: category, error: error, metadata: metadata, file: file, function: function, line: line)
    }

    func critical(
        _ message: String,
        category: LogCategory,
        error: Error? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .critical, message: message, category: category, error: error, metadata: metadata, file: file, function: function, line: line)
    }

    func measure<T>(
        _ label: String,
        category: LogCategory,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            var perfMetadata = metadata ?? [:]
            perfMetadata["duration_ms"] = String(format: "%.2f", duration * 1000)
            log(level: .debug, message: "⏱️ \(label)", category: category, error: nil, metadata: perfMetadata, file: file, function: function, line: line)
        }
        return try block()
    }

    // MARK: - Core Logging

    /// Public convenience method for logging with a specific level
    func log(
        _ message: String,
        category: LogCategory = .general,
        level: LogLevel,
        metadata: LogMetadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level: level,
            message: message,
            category: category,
            error: nil,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    /// Simplified log method without file/function/line (for protocol conformance)
    func log(
        _ message: String,
        category: LogCategory,
        level: LogLevel,
        metadata: LogMetadata?
    ) {
        log(
            level: level,
            message: message,
            category: category,
            error: nil,
            metadata: metadata,
            file: #fileID,
            function: #function,
            line: #line
        )
    }

    private func log(
        level: LogLevel,
        message: String,
        category: LogCategory,
        error: Error?,
        metadata: LogMetadata?,
        file: String,
        function: String,
        line: Int
    ) {
        // Filter by level
        guard level >= minimumLevel else { return }

        // Filter by category (empty set = all enabled)
        guard enabledCategories.isEmpty || enabledCategories.contains(category) else { return }

        // Build log message
        let logMessage = formatLogMessage(
            level: level,
            message: message,
            category: category,
            error: error,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )

        // Output to console
        queue.async {
            self.outputToConsole(level: level, message: logMessage)
        }

        // In production, could also:
        // - Send errors to crash reporting (Sentry, Crashlytics)
        // - Write to file for diagnostics
        // - Send to analytics
    }

    // MARK: - Formatting

    private func formatLogMessage(
        level: LogLevel,
        message: String,
        category: LogCategory,
        error: Error?,
        metadata: LogMetadata?,
        file: String,
        function: String,
        line: Int
    ) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent

        var components: [String] = [
            "[\(timestamp)]",
            "\(level.emoji) \(level.description)",
            "\(category.emoji) \(category.description)",
            "[\(fileName):\(line)]",
            message
        ]

        // Add error details
        if let error = error {
            components.append("Error: \(error.localizedDescription)")
        }

        // Add metadata
        if let metadata = metadata, !metadata.isEmpty {
            let metadataString = formatMetadata(metadata)
            components.append(metadataString)
        }

        return components.joined(separator: " | ")
    }

    private func formatMetadata(_ metadata: LogMetadata) -> String {
        let pairs = metadata.map { key, value in
            "\(key)=\(value)"
        }.sorted()
        return "{\(pairs.joined(separator: ", "))}"
    }

    private func outputToConsole(level: LogLevel, message: String) {
        // Use os_log for better integration with Console.app
        let osLogType: OSLogType = {
            switch level {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }()

        if #available(iOS 14.0, *) {
            let osLogger = os.Logger(subsystem: "com.heirloom.app", category: "general")
            osLogger.log(level: osLogType, "\(message)")
        } else {
            os_log("%{public}@", type: osLogType, message)
        }

        // Also print for Xcode console visibility
        #if DEBUG
        print(message)
        #endif
    }
}

// MARK: - Global Logger Convenience

/// Global logger instance for easy access throughout the app
/// Usage: Log.info("message", category: .sync)
/// Resolves from ServiceContainer for proper DI
/// Note: Safe to use from any context - uses nonisolated accessor
nonisolated(unsafe) var Log: LoggingService {
    // Access container's resolve method without MainActor isolation
    // This is safe because we're just reading from dictionaries that were populated at startup
    ServiceContainer.sharedUnsafe.resolveUnsafe(LoggingService.self)
}
