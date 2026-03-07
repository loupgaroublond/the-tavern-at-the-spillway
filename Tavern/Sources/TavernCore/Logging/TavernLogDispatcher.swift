import Foundation

// MARK: - Provenance: REQ-OBS-007, REQ-OBS-008, REQ-OBS-009

/// Central dispatcher that routes log entries to all registered sinks
///
/// The dispatcher is the single entry point for all logging. It holds
/// an array of sinks and dispatches each entry to every sink.
/// Sinks are set at initialization and remain fixed for the lifetime
/// of the dispatcher (no mutable state = genuinely Sendable).
public struct TavernLogDispatcher: Sendable {

    private let sinks: [any LogSink]

    /// Create a dispatcher with the given sinks
    public init(sinks: [any LogSink]) {
        self.sinks = sinks
    }

    /// Log a message at the given level and category
    public func log(
        category: String,
        level: LogLevel,
        message: String
    ) {
        let entry = LogEntry(
            category: category,
            level: level,
            message: message
        )
        for sink in sinks {
            sink.receive(entry)
        }
    }

    /// Log a debug-level message
    public func debug(category: String, _ message: String) {
        log(category: category, level: .debug, message: message)
    }

    /// Log an info-level message
    public func info(category: String, _ message: String) {
        log(category: category, level: .info, message: message)
    }

    /// Log an error-level message
    public func error(category: String, _ message: String) {
        log(category: category, level: .error, message: message)
    }
}
