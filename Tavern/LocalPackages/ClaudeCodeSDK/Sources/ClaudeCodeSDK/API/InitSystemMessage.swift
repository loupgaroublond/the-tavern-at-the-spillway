//
//  File.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 5/20/25.
//

import Foundation

public struct InitSystemMessage: Codable {
  public let type: String
  public let subtype: String
  public let sessionId: String
  public let tools: [String]
  public let mcpServers: [MCPServer]
  
  public struct MCPServer: Codable {
    public let name: String
    public let status: String
  }
}

/// Represents system message subtypes
public enum SystemSubtype: String, Codable {
  case `init`
  case success
  case errorMaxTurns = "error_max_turns"
  // Add other error types as needed
}
