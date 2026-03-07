// MARK: - Provenance: REQ-OBS-007, REQ-OBS-008

/// Protocol for log sinks that receive log entries
///
/// Sinks are the output destinations for the logging system.
/// Each sink receives every log entry and decides what to do with it.
public protocol LogSink: Sendable {
    /// Receive a log entry for processing
    func receive(_ entry: LogEntry)
}
