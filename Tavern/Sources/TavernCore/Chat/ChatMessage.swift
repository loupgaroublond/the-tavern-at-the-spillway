import Foundation

/// Type of message content for rich block display
public enum MessageType: String, Equatable, Sendable {
    case text
    case toolUse
    case toolResult
    case toolError
    case thinking
    case webSearch
}

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

    /// Type of content for block rendering (defaults to .text)
    public let messageType: MessageType

    /// Tool name when messageType is .toolUse (nil otherwise)
    public let toolName: String?

    /// Whether this is an error result (for toolResult/toolError types)
    public let isError: Bool

    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        messageType: MessageType = .text,
        toolName: String? = nil,
        isError: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.messageType = messageType
        self.toolName = toolName
        self.isError = isError
    }

    /// Convenience initializer for simple text messages (backward compatible)
    public static func text(role: Role, content: String) -> ChatMessage {
        ChatMessage(role: role, content: content, messageType: .text)
    }

    /// Convenience initializer for tool use messages
    public static func toolUse(name: String, input: String) -> ChatMessage {
        ChatMessage(
            role: .agent,
            content: input,
            messageType: .toolUse,
            toolName: name
        )
    }

    /// Convenience initializer for tool result messages
    public static func toolResult(content: String, isError: Bool = false) -> ChatMessage {
        ChatMessage(
            role: .agent,
            content: content,
            messageType: isError ? .toolError : .toolResult,
            isError: isError
        )
    }

    /// Convenience initializer for thinking messages
    public static func thinking(content: String) -> ChatMessage {
        ChatMessage(role: .agent, content: content, messageType: .thinking)
    }
}
