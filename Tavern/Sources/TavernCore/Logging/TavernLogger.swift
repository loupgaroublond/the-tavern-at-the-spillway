import os.log

// MARK: - Provenance: REQ-INV-007, REQ-OBS-008, REQ-OBS-009

/// Centralized logging for The Tavern at the Spillway
///
/// Uses a sink-based dispatch system. All log calls flow through the
/// `TavernLogDispatcher` which routes to registered sinks:
/// - `OSLogSink`: Always active, forwards to os.log (Console.app compatible)
/// - `BufferSink`: DEBUG only, feeds the in-app debug log panel
///
/// View logs in Console.app or via terminal:
///
/// ```bash
/// log stream --predicate 'subsystem == "com.tavern.spillway"' --level debug
/// ```
///
/// Log levels:
/// - `.debug`: Verbose development info (stripped from release builds)
/// - `.info`: Key events for understanding app flow
/// - `.error`: Failures that need attention
public enum TavernLogger {

    /// Subsystem for all Tavern logs
    private static let subsystem = "com.tavern.spillway"

    // MARK: - Shared Infrastructure

    #if DEBUG
    /// Shared log buffer for the debug panel (DEBUG only)
    public static let logBuffer = LogBuffer()

    /// The shared dispatcher that routes to all sinks
    public static let dispatcher: TavernLogDispatcher = {
        let osLogSink = OSLogSink(subsystem: subsystem)
        let bufferSink = BufferSink(buffer: logBuffer)
        return TavernLogDispatcher(sinks: [osLogSink, bufferSink])
    }()
    #else
    /// The shared dispatcher that routes to all sinks
    public static let dispatcher: TavernLogDispatcher = {
        let osLogSink = OSLogSink(subsystem: subsystem)
        return TavernLogDispatcher(sinks: [osLogSink])
    }()
    #endif

    // MARK: - Category Loggers

    /// All known log categories
    public static let allCategories: [String] = [
        "agents", "chat", "coordination", "claude",
        "resources", "permissions", "commands"
    ]

    /// Agent lifecycle, state transitions, session management
    public static let agents = CategoryLogger(category: "agents", dispatcher: dispatcher)

    /// Message flow, conversation state
    public static let chat = CategoryLogger(category: "chat", dispatcher: dispatcher)

    /// Agent spawn/dismiss, selection changes
    public static let coordination = CategoryLogger(category: "coordination", dispatcher: dispatcher)

    /// SDK calls, API interactions, responses
    public static let claude = CategoryLogger(category: "claude", dispatcher: dispatcher)

    /// Resource panel, file tree scanning, file content loading
    public static let resources = CategoryLogger(category: "resources", dispatcher: dispatcher)

    /// Permission checks, rule evaluation, mode changes
    public static let permissions = CategoryLogger(category: "permissions", dispatcher: dispatcher)

    /// Slash command parsing, dispatch, execution
    public static let commands = CategoryLogger(category: "commands", dispatcher: dispatcher)
}

// MARK: - CategoryLogger

/// A logger bound to a specific category that dispatches through the sink system.
///
/// Provides the same API surface as `os.log.Logger` for the methods used
/// throughout the codebase: `debug()`, `info()`, `error()`, and the
/// `debugError()` / `debugInfo()` / `debugLog()` extensions.
public struct CategoryLogger: Sendable {

    public let category: String
    private let dispatcher: TavernLogDispatcher

    public init(category: String, dispatcher: TavernLogDispatcher) {
        self.category = category
        self.dispatcher = dispatcher
    }

    // MARK: - os.log-compatible API

    /// Log at debug level with string interpolation
    public func debug(_ message: String) {
        dispatcher.debug(category: category, message)
    }

    /// Log at info level with string interpolation
    public func info(_ message: String) {
        dispatcher.info(category: category, message)
    }

    /// Log at error level with string interpolation
    public func error(_ message: String) {
        dispatcher.error(category: category, message)
    }

    /// Log at warning level (mapped to info in the sink system)
    public func warning(_ message: String) {
        dispatcher.info(category: category, message)
    }

    // MARK: - Debug-Only Public Logging (replaces Logger extension)

    /// Log error — public in DEBUG, private in release.
    public func debugError(_ message: String) {
        dispatcher.error(category: category, message)
    }

    /// Log info — public in DEBUG, private in release.
    public func debugInfo(_ message: String) {
        dispatcher.info(category: category, message)
    }

    /// Log debug — public in DEBUG, private in release.
    public func debugLog(_ message: String) {
        dispatcher.debug(category: category, message)
    }
}
