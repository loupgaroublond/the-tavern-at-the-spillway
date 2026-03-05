import Foundation
import TavernKit

// MARK: - Provenance: REQ-DOC-004, REQ-DOC-008

/// Persistent state for a servitor, stored as YAML frontmatter in servitor.md
public struct ServitorRecord: Codable, Equatable, Sendable {
    public let name: String
    public let id: UUID
    public var assignment: String?
    public var sessionId: String?
    public var sessionMode: PermissionMode
    public var description: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        name: String,
        id: UUID = UUID(),
        assignment: String? = nil,
        sessionId: String? = nil,
        sessionMode: PermissionMode = .plan,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.name = name
        self.id = id
        self.assignment = assignment
        self.sessionId = sessionId
        self.sessionMode = sessionMode
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// A session lifecycle event, stored as one line in sessions.jsonl
public struct SessionEvent: Codable, Equatable, Sendable {
    public enum EventType: String, Codable, Sendable {
        case sessionStarted = "session_started"
        case sessionExpired = "session_expired"
        case sessionEnded = "session_ended"
        case `break` = "break"
    }

    public let event: EventType
    public var sessionId: String?
    public let timestamp: Date
    public var reason: String?

    public init(event: EventType, sessionId: String? = nil, timestamp: Date = Date(), reason: String? = nil) {
        self.event = event
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.reason = reason
    }
}
