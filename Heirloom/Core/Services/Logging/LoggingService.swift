//
//  LoggingService.swift
//  Heirloom
//
//  Phase 4: Code Quality & Cleanup
//  Structured logging service to replace 634 print statements
//

import Foundation

// MARK: - Log Level

/// Severity levels for log messages
enum LogLevel: Int, Comparable, CustomStringConvertible {
    case debug = 0      // Detailed diagnostic information
    case info = 1       // Significant events (user actions, sync)
    case warning = 2    // Potentially harmful situations
    case error = 3      // Error conditions
    case critical = 4   // Critical failures requiring immediate attention

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

// MARK: - Log Category

/// Categorical organization of log messages
enum LogCategory: String, CustomStringConvertible {
    case firebase = "Firebase"
    case sync = "Sync"
    case crdt = "CRDT"
    case network = "Network"
    case ui = "UI"
    case auth = "Auth"
    case storage = "Storage"
    case ocr = "OCR"
    case performance = "Performance"
    case database = "Database"
    case store = "Store"
    case video = "Video"
    case heritage = "Heritage"
    case migration = "Migration"
    case general = "General"

    var description: String { rawValue }

    var emoji: String {
        switch self {
        case .firebase: return "🔥"
        case .sync: return "🔄"
        case .crdt: return "📝"
        case .network: return "🌐"
        case .ui: return "🎨"
        case .auth: return "🔐"
        case .storage: return "💾"
        case .ocr: return "📸"
        case .performance: return "⚡️"
        case .database: return "🗄️"
        case .store: return "💳"
        case .video: return "🎥"
        case .heritage: return "🏛️"
        case .migration: return "🚀"
        case .general: return "ℹ️"
        }
    }
}

// MARK: - Log Metadata

/// Key-value pairs for structured log context
typealias LogMetadata = [String: Any]

// MARK: - Logging Service Protocol

/// Protocol for structured logging throughout the app
protocol LoggingService {
    /// Current minimum log level to output (logs below this are filtered)
    var minimumLevel: LogLevel { get set }

    /// Categories to filter (empty = all categories enabled)
    var enabledCategories: Set<LogCategory> { get set }

    /// Log a debug message (compiled out in release builds)
    func debug(
        _ message: String,
        category: LogCategory,
        metadata: LogMetadata?,
        file: String,
        function: String,
        line: Int
    )

    /// Log an informational message
    func info(
        _ message: String,
        category: LogCategory,
        metadata: LogMetadata?,
        file: String,
        function: String,
        line: Int
    )

    /// Log a warning message
    func warning(
        _ message: String,
        category: LogCategory,
        metadata: LogMetadata?,
        file: String,
        function: String,
        line: Int
    )

    /// Log an error message with optional Error object
    func error(
        _ message: String,
        category: LogCategory,
        error: Error?,
        metadata: LogMetadata?,
        file: String,
        function: String,
        line: Int
    )

    /// Convenience method to log with a specific level
    func log(
        _ message: String,
        category: LogCategory,
        level: LogLevel,
        metadata: LogMetadata?,
        file: String,
        function: String,
        line: Int
    )

    /// Convenience method to log with a specific level (with defaults)
    func log(
        _ message: String,
        category: LogCategory,
        level: LogLevel,
        metadata: LogMetadata?
    )

    /// Log a critical failure
    func critical(
        _ message: String,
        category: LogCategory,
        error: Error?,
        metadata: LogMetadata?,
        file: String,
        function: String,
        line: Int
    )

    /// Log performance timing for a block of code
    func measure<T>(
        _ label: String,
        category: LogCategory,
        metadata: LogMetadata?,
        file: String,
        function: String,
        line: Int,
        block: () throws -> T
    ) rethrows -> T
}

// MARK: - Logging Service Extensions

extension LoggingService {
    /// Debug log with default parameters
    func debug(
        _ message: String,
        category: LogCategory = .general,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        debug(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Info log with default parameters
    func info(
        _ message: String,
        category: LogCategory = .general,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        info(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Warning log with default parameters
    func warning(
        _ message: String,
        category: LogCategory = .general,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        warning(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Error log with default parameters
    func error(
        _ message: String,
        category: LogCategory = .general,
        error: Error? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.error(message, category: category, error: error, metadata: metadata, file: file, function: function, line: line)
    }

    /// Critical log with default parameters
    func critical(
        _ message: String,
        category: LogCategory = .general,
        error: Error? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.critical(message, category: category, error: error, metadata: metadata, file: file, function: function, line: line)
    }

    /// Measure performance with default parameters
    func measure<T>(
        _ label: String,
        category: LogCategory = .performance,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: () throws -> T
    ) rethrows -> T {
        try measure(label, category: category, metadata: metadata, file: file, function: function, line: line, block: block)
    }
}
