import os.log

// MARK: - Provenance: REQ-OBS-007, REQ-OBS-008

/// Sink that forwards log entries to Apple's unified logging system (os.log)
///
/// Always active — preserves Console.app and `log stream` functionality.
/// Creates a fresh Logger for each entry's category. Logger is a lightweight
/// struct so the per-call cost is negligible.
public struct OSLogSink: LogSink, Sendable {

    private let subsystem: String

    public init(subsystem: String = "com.tavern.spillway") {
        self.subsystem = subsystem
    }

    public func receive(_ entry: LogEntry) {
        let logger = Logger(subsystem: subsystem, category: entry.category)
        let message = entry.message

        switch entry.level {
        case .debug:
            #if DEBUG
            logger.debug("\(message, privacy: .public)")
            #else
            logger.debug("\(message, privacy: .private)")
            #endif
        case .info:
            #if DEBUG
            logger.info("\(message, privacy: .public)")
            #else
            logger.info("\(message, privacy: .private)")
            #endif
        case .error:
            #if DEBUG
            logger.error("\(message, privacy: .public)")
            #else
            logger.error("\(message, privacy: .private)")
            #endif
        }
    }
}
