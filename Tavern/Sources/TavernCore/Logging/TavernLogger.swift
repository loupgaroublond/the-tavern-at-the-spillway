import os.log

/// Centralized logging for The Tavern at the Spillway
///
/// Uses Apple's unified logging system (os.log) with the subsystem
/// `com.tavern.spillway`. View logs in Console.app or via terminal:
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

    /// Agent lifecycle, state transitions, session management
    public static let agents = Logger(subsystem: subsystem, category: "agents")

    /// Message flow, conversation state
    public static let chat = Logger(subsystem: subsystem, category: "chat")

    /// Agent spawn/dismiss, selection changes
    public static let coordination = Logger(subsystem: subsystem, category: "coordination")

    /// SDK calls, API interactions, responses
    public static let claude = Logger(subsystem: subsystem, category: "claude")

    /// Resource panel, file tree scanning, file content loading
    public static let resources = Logger(subsystem: subsystem, category: "resources")

    /// Permission checks, rule evaluation, mode changes
    public static let permissions = Logger(subsystem: subsystem, category: "permissions")

    /// Slash command parsing, dispatch, execution
    public static let commands = Logger(subsystem: subsystem, category: "commands")
}

// MARK: - Debug-Only Public Logging

/// Extension providing logging methods that are visible (public privacy) in DEBUG builds
/// but redacted (private privacy) in release builds.
///
/// macOS os.log redacts interpolated strings as `<private>` by default.
/// These methods make error details visible during development.
extension Logger {

    /// Log error - public in DEBUG, private in release
    /// Use this when you need to see the actual error content in logs during development.
    public func debugError(_ message: String) {
        #if DEBUG
        self.error("\(message, privacy: .public)")
        #else
        self.error("\(message, privacy: .private)")
        #endif
    }

    /// Log info - public in DEBUG, private in release
    /// Use this when you need to see info-level content during development.
    public func debugInfo(_ message: String) {
        #if DEBUG
        self.info("\(message, privacy: .public)")
        #else
        self.info("\(message, privacy: .private)")
        #endif
    }

    /// Log debug - public in DEBUG, private in release
    /// Use this when you need to see debug-level content during development.
    public func debugLog(_ message: String) {
        #if DEBUG
        self.debug("\(message, privacy: .public)")
        #else
        self.debug("\(message, privacy: .private)")
        #endif
    }
}
