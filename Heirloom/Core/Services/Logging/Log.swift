//
//  Log.swift
//  Heirloom
//
//  Global logging accessor for convenient logging throughout the app
//

import Foundation

/// Global logging accessor
/// Usage: Log.info("Message", category: .general)
enum Log {
    private static var service: LoggingService {
        ServiceContainer.sharedUnsafe.resolveUnsafe(LoggingService.self)
    }

    static func debug(
        _ message: String,
        category: LogCategory = .general,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        service.debug(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    static func info(
        _ message: String,
        category: LogCategory = .general,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        service.info(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    static func warning(
        _ message: String,
        category: LogCategory = .general,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        service.warning(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    static func error(
        _ message: String,
        category: LogCategory = .general,
        error: Error? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        service.error(message, category: category, error: error, metadata: metadata, file: file, function: function, line: line)
    }

    static func critical(
        _ message: String,
        category: LogCategory = .general,
        error: Error? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        service.critical(message, category: category, error: error, metadata: metadata, file: file, function: function, line: line)
    }
}
