import Foundation

/// Represents a background task with its current execution state
public struct TavernTask: Identifiable, Equatable, Sendable {

    /// Status of a background task
    public enum Status: String, Equatable, Sendable {
        case running
        case completed
        case failed
        case stopped
    }

    /// Unique identifier
    public let id: UUID

    /// Human-readable name for the task
    public let name: String

    /// When the task started
    public let startedAt: Date

    /// When the task finished (nil if still running)
    public var finishedAt: Date?

    /// Current status
    public var status: Status

    /// Accumulated output text
    public var output: String

    public init(
        id: UUID = UUID(),
        name: String,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        status: Status = .running,
        output: String = ""
    ) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.output = output
    }

    /// Elapsed time since task started (or total duration if finished)
    public var elapsed: TimeInterval {
        let end = finishedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }
}
