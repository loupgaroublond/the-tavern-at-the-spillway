//
//  ClaudeSessionModels.swift
//  TavernCore
//
//  Models for Claude's native session storage.
//  Moved from SDK - this is Tavern-specific functionality, not SDK responsibility.
//

import Foundation

/// Represents a stored Claude session from the native CLI storage
public struct ClaudeStoredSession: Identifiable, Codable {
    public let id: String
    public let projectPath: String
    public let createdAt: Date
    public let lastAccessedAt: Date
    public var summary: String?
    public var gitBranch: String?
    public var messages: [ClaudeStoredMessage]

    public init(
        id: String,
        projectPath: String,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        summary: String? = nil,
        gitBranch: String? = nil,
        messages: [ClaudeStoredMessage] = []
    ) {
        self.id = id
        self.projectPath = projectPath
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.summary = summary
        self.gitBranch = gitBranch
        self.messages = messages
    }
}

/// A content block within a message
public enum StoredContentBlock: Codable, Equatable, Sendable {
    case text(String)
    case toolUse(id: String, name: String, input: String)
    case toolResult(toolUseId: String, content: String, isError: Bool)

    /// Returns display text for this block
    public var displayText: String {
        switch self {
        case .text(let text):
            return text
        case .toolUse(_, let name, _):
            return "[Used tool: \(name)]"
        case .toolResult(_, let content, _):
            return content
        }
    }
}

/// Represents a message in a Claude session
public struct ClaudeStoredMessage: Identifiable, Codable {
    public let id: String // UUID from the jsonl file
    public let parentId: String?
    public let sessionId: String
    public let role: MessageRole
    public let content: String  // Flattened text content (backward compatible)
    public let contentBlocks: [StoredContentBlock]  // Structured content blocks
    public let timestamp: Date
    public let cwd: String?
    public let version: String?

    public enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }

    public init(
        id: String,
        parentId: String? = nil,
        sessionId: String,
        role: MessageRole,
        content: String,
        contentBlocks: [StoredContentBlock] = [],
        timestamp: Date,
        cwd: String? = nil,
        version: String? = nil
    ) {
        self.id = id
        self.parentId = parentId
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.contentBlocks = contentBlocks.isEmpty ? [.text(content)] : contentBlocks
        self.timestamp = timestamp
        self.cwd = cwd
        self.version = version
    }
}

/// Raw JSON structure from Claude's .jsonl files
internal struct ClaudeJSONLEntry: Codable {
    let type: String
    let uuid: String?
    let parentUuid: String?
    let sessionId: String?
    let timestamp: String?
    let cwd: String?
    let version: String?
    let gitBranch: String?
    let message: MessageContent?
    let summary: String?
    let leafUuid: String?
    let requestId: String?

    struct MessageContent: Codable {
        let role: String?
        let content: MessageContentValue?
    }

    enum MessageContentValue: Codable {
        case string(String)
        case array([ContentItem])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let arrayValue = try? container.decode([ContentItem].self) {
                self = .array(arrayValue)
            } else {
                throw DecodingError.typeMismatch(
                    MessageContentValue.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected String or [ContentItem]"
                    )
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .array(let items):
                try container.encode(items)
            }
        }

        var textContent: String {
            switch self {
            case .string(let str):
                return str
            case .array(let items):
                return items.compactMap { $0.itemType.displayText }.joined(separator: "\n")
            }
        }

        /// Convert to structured content blocks for storage
        var contentBlocks: [StoredContentBlock] {
            switch self {
            case .string(let str):
                return [.text(str)]
            case .array(let items):
                return items.compactMap { $0.toStoredContentBlock() }
            }
        }
    }

    struct ContentItem: Codable {
        enum ItemType {
            case text(String)
            case toolUse(id: String, name: String, input: String)
            case toolResult(toolUseId: String, content: String?, isError: Bool)
            case other(String)

            /// Returns display text for this item, or nil if it shouldn't be shown
            var displayText: String? {
                switch self {
                case .text(let text):
                    return text
                case .toolUse(_, let name, _):
                    // Show tool usage as a brief indicator
                    return "[Used tool: \(name)]"
                case .toolResult(_, let content, _):
                    // Show tool result content if available
                    if let content = content, !content.isEmpty {
                        return content
                    }
                    return nil  // Hide empty tool results
                case .other:
                    return nil  // Hide unknown types
                }
            }
        }

        let itemType: ItemType

        /// Convert to a StoredContentBlock for storage, or nil if not displayable
        func toStoredContentBlock() -> StoredContentBlock? {
            switch itemType {
            case .text(let text):
                return .text(text)
            case .toolUse(let id, let name, let input):
                return .toolUse(id: id, name: name, input: input)
            case .toolResult(let toolUseId, let content, let isError):
                guard let content = content, !content.isEmpty else { return nil }
                return .toolResult(toolUseId: toolUseId, content: content, isError: isError)
            case .other:
                return nil
            }
        }

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case id
            case name
            case tool_use_id
            case content
            case input
            case is_error
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let typeString = try container.decode(String.self, forKey: .type)

            switch typeString {
            case "text":
                let text = try container.decode(String.self, forKey: .text)
                self.itemType = .text(text)
            case "tool_use":
                let id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
                let name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
                // Decode input as generic JSON and convert to pretty-printed string
                let inputString: String
                if let inputValue = try container.decodeIfPresent(SessionJSONValue.self, forKey: .input) {
                    inputString = inputValue.prettyPrinted
                } else {
                    inputString = ""
                }
                self.itemType = .toolUse(id: id, name: name, input: inputString)
            case "tool_result":
                let toolUseId = try container.decodeIfPresent(String.self, forKey: .tool_use_id) ?? ""
                let content = try container.decodeIfPresent(String.self, forKey: .content)
                let isError = try container.decodeIfPresent(Bool.self, forKey: .is_error) ?? false
                self.itemType = .toolResult(toolUseId: toolUseId, content: content, isError: isError)
            default:
                self.itemType = .other(typeString)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch itemType {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .toolUse(let id, let name, _):
                // Note: We don't re-encode the input since it's derived from parsed JSON
                try container.encode("tool_use", forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
            case .toolResult(let toolUseId, let content, let isError):
                try container.encode("tool_result", forKey: .type)
                try container.encode(toolUseId, forKey: .tool_use_id)
                if let content = content {
                    try container.encode(content, forKey: .content)
                }
                if isError {
                    try container.encode(isError, forKey: .is_error)
                }
            case .other(let typeString):
                try container.encode(typeString, forKey: .type)
            }
        }
    }
}

// MARK: - JSON Value Helper

/// A type that can decode any JSON value and convert it to a string representation
/// (Internal to session storage, not exported to avoid collision with SDK's JSONValue)
internal enum SessionJSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: SessionJSONValue])
    case array([SessionJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([SessionJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: SessionJSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(
                SessionJSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown JSON type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    /// Convert to a pretty-printed string representation
    var prettyPrinted: String {
        do {
            let data = try JSONEncoder.sessionPrettyPrinted.encode(self)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return String(describing: self)
        }
    }
}

private extension JSONEncoder {
    static let sessionPrettyPrinted: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
