//
//  MCPConfigurationTests.swift
//  ClaudeCodeSDKTests
//
//  Created by James Rochabrun on 6/18/25.
//

import XCTest
@testable import ClaudeCodeSDK
import Foundation

final class MCPConfigurationTests: XCTestCase {
  
  func testMCPConfigWithFilePath() throws {
    // Given
    var options = ClaudeCodeOptions()
    options.mcpConfigPath = "/path/to/mcp-config.json"
    
    // When
    let args = options.toCommandArgs()
    
    // Then
    XCTAssertTrue(args.contains("--mcp-config"))
    if let index = args.firstIndex(of: "--mcp-config") {
      XCTAssertEqual(args[index + 1], "/path/to/mcp-config.json")
    }
    XCTAssertFalse(args.contains("--mcp-servers"))
  }
  
  func testMCPConfigWithProgrammaticServers() throws {
    // Given
    var options = ClaudeCodeOptions()
    options.mcpServers = [
      "XcodeBuildMCP": .stdio(McpStdioServerConfig(
        command: "npx",
        args: ["-y", "xcodebuildmcp@latest"]
      ))
    ]
    
    // When
    let args = options.toCommandArgs()
    
    // Then
    XCTAssertTrue(args.contains("--mcp-config"))
    if let index = args.firstIndex(of: "--mcp-config") {
      let configPath = args[index + 1]
      XCTAssertTrue(configPath.contains("mcp-config-"))
      XCTAssertTrue(configPath.hasSuffix(".json"))
      
      // Verify the temporary file contains the correct structure
      if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let mcpServers = json["mcpServers"] as? [String: Any] {
        XCTAssertNotNil(mcpServers["XcodeBuildMCP"])
      }
    }
    XCTAssertFalse(args.contains("--mcp-servers"))
  }
  
  func testMCPToolNaming() {
    // Test basic tool naming
    let toolName = MCPToolFormatter.formatToolName(serverName: "filesystem", toolName: "read_file")
    XCTAssertEqual(toolName, "mcp__filesystem__read_file")
    
    // Test wildcard pattern
    let wildcard = MCPToolFormatter.formatServerWildcard(serverName: "github")
    XCTAssertEqual(wildcard, "mcp__github__*")
  }
  
  func testMCPToolPatternsGeneration() {
    // Given
    let mcpServers: [String: McpServerConfiguration] = [
      "XcodeBuildMCP": .stdio(McpStdioServerConfig(command: "npx", args: ["xcodebuildmcp"])),
      "filesystem": .stdio(McpStdioServerConfig(command: "npx", args: ["filesystem"]))
    ]
    
    // When
    let patterns = MCPToolFormatter.generateAllowedToolPatterns(from: mcpServers)
    
    // Then
    XCTAssertEqual(patterns.count, 2)
    XCTAssertTrue(patterns.contains("mcp__XcodeBuildMCP__*"))
    XCTAssertTrue(patterns.contains("mcp__filesystem__*"))
  }
  
  func testMCPConfigFileExtraction() throws {
    // Given - Create a temporary MCP config file
    let tempDir = FileManager.default.temporaryDirectory
    let configFile = tempDir.appendingPathComponent("test-mcp-config.json")
    
    let config = """
    {
      "mcpServers": {
        "testServer1": {
          "command": "test",
          "args": ["arg1"]
        },
        "testServer2": {
          "command": "test2"
        }
      }
    }
    """
    
    try config.write(to: configFile, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: configFile) }
    
    // When
    let serverNames = MCPToolFormatter.extractServerNames(fromConfigPath: configFile.path)
    let patterns = MCPToolFormatter.generateAllowedToolPatterns(fromConfigPath: configFile.path)
    
    // Then
    XCTAssertEqual(serverNames.count, 2)
    XCTAssertTrue(serverNames.contains("testServer1"))
    XCTAssertTrue(serverNames.contains("testServer2"))
    
    XCTAssertEqual(patterns.count, 2)
    XCTAssertTrue(patterns.contains(where: { $0.contains("testServer1") }))
    XCTAssertTrue(patterns.contains(where: { $0.contains("testServer2") }))
  }
  
  func testMCPServerConfigurationEncoding() throws {
    // Test stdio server encoding
    let stdioConfig = McpStdioServerConfig(
      command: "npx",
      args: ["-y", "test-server"],
      env: ["API_KEY": "secret"]
    )
    
    let stdioWrapper = McpServerConfiguration.stdio(stdioConfig)
    let encodedData = try JSONEncoder().encode(stdioWrapper)
    let json = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any]
    
    XCTAssertEqual(json?["command"] as? String, "npx")
    XCTAssertEqual(json?["args"] as? [String], ["-y", "test-server"])
    XCTAssertEqual((json?["env"] as? [String: String])?["API_KEY"], "secret")
    
    // Test SSE server encoding
    let sseConfig = McpSSEServerConfig(
      url: "https://example.com/mcp",
      headers: ["Authorization": "Bearer token"]
    )
    
    let sseWrapper = McpServerConfiguration.sse(sseConfig)
    let sseData = try JSONEncoder().encode(sseWrapper)
    let sseJson = try JSONSerialization.jsonObject(with: sseData) as? [String: Any]
    
    XCTAssertEqual(sseJson?["type"] as? String, "sse")
    XCTAssertEqual(sseJson?["url"] as? String, "https://example.com/mcp")
    XCTAssertEqual((sseJson?["headers"] as? [String: String])?["Authorization"], "Bearer token")
  }
}