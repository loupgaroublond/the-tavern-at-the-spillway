import Foundation

// MARK: - Provenance: REQ-OBS-007, REQ-OBS-008, REQ-OBS-009

/// Severity level for log entries
public enum LogLevel: Int, Sendable, Comparable, CaseIterable, Hashable {
    case debug = 0
    case info = 1
    case error = 2

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .debug: "DEBUG"
        case .info: "INFO"
        case .error: "ERROR"
        }
    }
}

/// A single log entry captured by the sink system
public struct LogEntry: Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let category: String
    public let level: LogLevel
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: String,
        level: LogLevel,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
    }
}
