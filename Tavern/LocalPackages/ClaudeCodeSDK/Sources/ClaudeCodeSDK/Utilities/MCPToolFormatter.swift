//
//  MCPToolFormatter.swift
//  ClaudeCodeSDK
//
//  Created by James Rochabrun on 6/18/25.
//

import Foundation

/// Utility for formatting MCP tool names according to the Claude Code specification
public enum MCPToolFormatter {
  
  /// Formats an MCP tool name according to the specification: mcp__serverName__toolName
  /// - Parameters:
  ///   - serverName: The name of the MCP server
  ///   - toolName: The name of the tool
  /// - Returns: The formatted tool name
  public static func formatToolName(serverName: String, toolName: String) -> String {
    return "mcp__\(serverName)__\(toolName)"
  }
  
  /// Formats a wildcard pattern for all tools from a specific MCP server
  /// - Parameter serverName: The name of the MCP server
  /// - Returns: The wildcard pattern for all tools from the server
  public static func formatServerWildcard(serverName: String) -> String {
    return "mcp__\(serverName)__*"
  }
  
  /// Extracts MCP server names from a configuration dictionary
  /// - Parameter mcpServers: Dictionary of MCP server configurations
  /// - Returns: Array of server names
  public static func extractServerNames(from mcpServers: [String: McpServerConfiguration]) -> [String] {
    return Array(mcpServers.keys)
  }
  
  /// Generates allowed tool patterns for all MCP servers in a configuration
  /// - Parameter mcpServers: Dictionary of MCP server configurations
  /// - Returns: Array of MCP tool patterns
  public static func generateAllowedToolPatterns(from mcpServers: [String: McpServerConfiguration]) -> [String] {
    return extractServerNames(from: mcpServers).map { formatServerWildcard(serverName: $0) }
  }
  
  /// Parses an MCP configuration file and returns server names
  /// - Parameter configPath: Path to the MCP configuration JSON file
  /// - Returns: Array of server names, or empty array if parsing fails
  public static func extractServerNames(fromConfigPath configPath: String) -> [String] {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let mcpServers = json["mcpServers"] as? [String: Any] else {
      return []
    }
    return Array(mcpServers.keys)
  }
  
  /// Generates allowed tool patterns from an MCP configuration file
  /// - Parameter configPath: Path to the MCP configuration JSON file
  /// - Returns: Array of MCP tool patterns
  public static func generateAllowedToolPatterns(fromConfigPath configPath: String) -> [String] {
    return extractServerNames(fromConfigPath: configPath).map { formatServerWildcard(serverName: $0) }
  }
}

