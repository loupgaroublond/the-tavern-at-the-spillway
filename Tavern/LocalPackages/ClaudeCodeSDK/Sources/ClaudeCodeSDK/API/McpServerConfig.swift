//
//  McpServerConfig.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 6/17/25.
//

import Foundation

/// Base protocol for MCP server configurations
public protocol McpServerConfig: Codable {
  var type: McpServerType? { get }
}

/// Type of MCP server
public enum McpServerType: String, Codable, Sendable {
  case stdio = "stdio"
  case sse = "sse"
}

/// Configuration for stdio-based MCP servers
public struct McpStdioServerConfig: McpServerConfig, Sendable {
  /// Type of server (optional for backwards compatibility)
  public let type: McpServerType?
  
  /// Command to execute
  public let command: String
  
  /// Arguments to pass to the command
  public let args: [String]?
  
  /// Environment variables for the command
  public let env: [String: String]?
  
  public init(
    type: McpServerType? = .stdio,
    command: String,
    args: [String]? = nil,
    env: [String: String]? = nil
  ) {
    self.type = type
    self.command = command
    self.args = args
    self.env = env
  }
}

/// Configuration for SSE-based MCP servers
public struct McpSSEServerConfig: McpServerConfig, Sendable {
  /// Type of server (required for SSE)
  public let type: McpServerType?
  
  /// URL of the SSE server
  public let url: String
  
  /// Headers to include in requests
  public let headers: [String: String]?
  
  public init(type: McpServerType? = .sse, url: String, headers: [String: String]? = nil) {
    self.type = type
    self.url = url
    self.headers = headers
  }
}

/// Container for MCP server configuration that handles both types
public enum McpServerConfiguration: Codable, Sendable {
  case stdio(McpStdioServerConfig)
  case sse(McpSSEServerConfig)
  
  private enum CodingKeys: String, CodingKey {
    case type
    case command
    case args
    case env
    case url
    case headers
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    // Try to decode type, but it's optional for stdio
    let type = try container.decodeIfPresent(McpServerType.self, forKey: .type)
    
    // If type is SSE or we have a URL, decode as SSE
    if type == .sse || container.contains(.url) {
      let url = try container.decode(String.self, forKey: .url)
      let headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
      self = .sse(McpSSEServerConfig(type: type, url: url, headers: headers))
    } else {
      // Otherwise decode as stdio
      let command = try container.decode(String.self, forKey: .command)
      let args = try container.decodeIfPresent([String].self, forKey: .args)
      let env = try container.decodeIfPresent([String: String].self, forKey: .env)
      self = .stdio(McpStdioServerConfig(type: type, command: command, args: args, env: env))
    }
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    
    switch self {
    case .stdio(let config):
      try container.encodeIfPresent(config.type, forKey: .type)
      try container.encode(config.command, forKey: .command)
      try container.encodeIfPresent(config.args, forKey: .args)
      try container.encodeIfPresent(config.env, forKey: .env)
      
    case .sse(let config):
      try container.encode(McpServerType.sse, forKey: .type)
      try container.encode(config.url, forKey: .url)
      try container.encodeIfPresent(config.headers, forKey: .headers)
    }
  }
}

