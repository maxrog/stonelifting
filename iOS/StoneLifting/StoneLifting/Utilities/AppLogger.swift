//
//  AppLogger.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/15/25.
//

import Foundation
import os.log

// MARK: - App Logger

/// Logging system
/// Each class instantiates its own logger with automatic class name detection
final class AppLogger {
    // MARK: - Properties

    private let logger: Logger
    private let className: String

    // MARK: - Initialization

    /// Initialize logger with automatic class name detection
    /// - Parameter className: Class name for filtering (automatically detected from call site)
    init(className: String = #fileID) {
        self.className = Self.extractClassName(from: className)
        logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Bundle", category: "App")
    }

    // MARK: - Public Logging Methods

    /// Log debug information
    /// - Parameters:
    ///   - message: Debug message
    ///   - function: Calling function name
    func debug(_ message: String, function: String = #function) {
        let formattedMessage = formatMessage(message, function: function)
        logger.debug("\(formattedMessage)")
    }

    /// Log general information
    /// - Parameters:
    ///   - message: Info message
    ///   - function: Calling function name
    func info(_ message: String, function: String = #function) {
        let formattedMessage = formatMessage(message, function: function)
        logger.info("\(formattedMessage)")
    }

    /// Log warnings
    /// - Parameters:
    ///   - message: Warning message
    ///   - function: Calling function name
    func warning(_ message: String, function: String = #function) {
        let formattedMessage = formatMessage(message, function: function)
        logger.warning("\(formattedMessage)")
    }

    /// Log errors
    /// - Parameters:
    ///   - message: Error message
    ///   - error: Optional error object
    ///   - function: Calling function name
    func error(_ message: String, error: Error? = nil, function: String = #function) {
        var fullMessage = message

        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }

        let formattedMessage = formatMessage(fullMessage, function: function)
        logger.error("\(formattedMessage)")
    }

    /// Log critical errors that require immediate attention
    /// - Parameters:
    ///   - message: Critical error message
    ///   - error: Optional error object
    ///   - function: Calling function name
    func critical(_ message: String, error: Error? = nil, function: String = #function) {
        var fullMessage = "🚨 CRITICAL: \(message)"

        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }

        let formattedMessage = formatMessage(fullMessage, function: function)
        logger.critical("\(formattedMessage)")
    }
}

// MARK: - Private Methods

private extension AppLogger {
    /// Format log message with metadata
    /// - Parameters:
    ///   - message: Original message
    ///   - function: Function name
    /// - Returns: Formatted message
    func formatMessage(_ message: String, function: String) -> String {
        return "[\(className)] \(function) - \(message)"
    }

    /// Extract clean class name from file path
    /// - Parameter className: Full file path or class identifier
    /// - Returns: Clean class name
    static func extractClassName(from className: String) -> String {
        // Handle #fileID format (e.g., "MyApp/APIService.swift")
        if className.contains("/") {
            let components = className.split(separator: "/")
            if let last = components.last {
                return String(last.replacingOccurrences(of: ".swift", with: ""))
            }
        }

        return className
    }
}
