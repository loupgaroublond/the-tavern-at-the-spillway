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
}
