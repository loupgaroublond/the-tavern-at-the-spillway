import Foundation
import TavernKit

// MARK: - Provenance: REQ-DOC-001

/// Configuration for an external MCP server, persisted in servitor.md body as JSON.
/// Matches the Claude Code `mcpServers` schema: command + args + optional env.
public struct MCPServerEntry: Codable, Equatable, Sendable {
    public let command: String
    public let args: [String]
    public let env: [String: String]?

    public init(command: String, args: [String] = [], env: [String: String]? = nil) {
        self.command = command
        self.args = args
        self.env = env
    }
}

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

    // MARK: - Model & Thinking Control (SDK gap 2a)

    /// Model ID override for this servitor (nil = use system default)
    public var modelId: String?

    /// Thinking budget in tokens (nil = no explicit budget).
    public var thinkingBudget: Int?

    /// Effort level for this servitor (nil = use system default).
    /// Valid values: "low", "medium", "high", "max".
    public var effortLevel: String?

    /// External MCP server configurations, keyed by server name.
    /// Persisted as a JSON code block in the servitor.md body (after frontmatter).
    public var mcpServers: [String: MCPServerEntry]

    public init(
        name: String,
        id: UUID = UUID(),
        assignment: String? = nil,
        sessionId: String? = nil,
        sessionMode: PermissionMode = .plan,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        modelId: String? = nil,
        thinkingBudget: Int? = nil,
        effortLevel: String? = nil,
        mcpServers: [String: MCPServerEntry] = [:]
    ) {
        self.name = name
        self.id = id
        self.assignment = assignment
        self.sessionId = sessionId
        self.sessionMode = sessionMode
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.modelId = modelId
        self.thinkingBudget = thinkingBudget
        self.effortLevel = effortLevel
        self.mcpServers = mcpServers
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
