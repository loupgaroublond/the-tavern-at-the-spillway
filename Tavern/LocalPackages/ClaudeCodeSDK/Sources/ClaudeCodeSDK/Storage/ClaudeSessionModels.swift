//
//  ClaudeSessionModels.swift
//  ClaudeCodeSDK
//
//  Created by Assistant on 8/18/2025.
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

/// Represents a message in a Claude session
public struct ClaudeStoredMessage: Identifiable, Codable {
  public let id: String // UUID from the jsonl file
  public let parentId: String?
  public let sessionId: String
  public let role: MessageRole
  public let content: String
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
    timestamp: Date,
    cwd: String? = nil,
    version: String? = nil
  ) {
    self.id = id
    self.parentId = parentId
    self.sessionId = sessionId
    self.role = role
    self.content = content
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
        return items.compactMap { item in
          if case .text(let text) = item.type {
            return text
          }
          return nil
        }.joined(separator: "\n")
      }
    }
  }
  
  struct ContentItem: Codable {
    let type: ContentType
    
    enum ContentType: Codable {
      case text(String)
      case other
      
      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        
        if typeString == "text" {
          let text = try container.decode(String.self, forKey: .text)
          self = .text(text)
        } else {
          self = .other
        }
      }
      
      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
          try container.encode("text", forKey: .type)
          try container.encode(text, forKey: .text)
        case .other:
          try container.encode("other", forKey: .type)
        }
      }
      
      enum CodingKeys: String, CodingKey {
        case type
        case text
      }
    }
  }
}