import Foundation

/// A message in a chat conversation
public struct ChatMessage: Identifiable, Equatable, Sendable {

    /// Who sent the message
    public enum Role: String, Equatable, Sendable {
        case user
        case agent
    }

    public let id: UUID
    public let role: Role
    public let content: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
