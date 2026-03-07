#if DEBUG
import Foundation

// MARK: - Provenance: REQ-OBS-007, REQ-OBS-008, REQ-OBS-009

/// Thread-safe in-memory buffer for log entries (DEBUG only)
///
/// Grows infinitely — cleared on app restart (no persistence).
/// Provides both snapshot access and an `AsyncStream` for live subscribers.
public actor LogBuffer {

    private var _entries: [LogEntry] = []
    private var continuations: [UUID: AsyncStream<LogEntry>.Continuation] = [:]

    public init() {}

    /// All entries currently in the buffer
    public var entries: [LogEntry] {
        _entries
    }

    /// Append an entry and notify all stream subscribers
    public func append(_ entry: LogEntry) {
        _entries.append(entry)
        for (_, continuation) in continuations {
            continuation.yield(entry)
        }
    }

    /// Create a new `AsyncStream` that delivers entries as they arrive.
    /// The stream terminates when the returned subscription is cancelled.
    public func stream() -> AsyncStream<LogEntry> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeContinuation(id) }
            }
            self.continuations[id] = continuation
        }
    }

    /// Filter entries by category
    public func entries(forCategory category: String) -> [LogEntry] {
        _entries.filter { $0.category == category }
    }

    /// Filter entries by level
    public func entries(atLevel level: LogLevel) -> [LogEntry] {
        _entries.filter { $0.level >= level }
    }

    /// Remove all entries
    public func clear() {
        _entries.removeAll()
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

/// Sink that appends log entries to a `LogBuffer` (DEBUG only)
public struct BufferSink: LogSink, Sendable {

    private let buffer: LogBuffer

    public init(buffer: LogBuffer) {
        self.buffer = buffer
    }

    public func receive(_ entry: LogEntry) {
        Task { await buffer.append(entry) }
    }
}
#endif
