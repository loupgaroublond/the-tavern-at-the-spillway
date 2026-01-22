//
//  ClaudeSessionProtocol.swift
//  ClaudeCodeSDK
//
//  Created by Assistant on 8/18/2025.
//

import Foundation

/// Protocol for accessing Claude's native session storage
public protocol ClaudeSessionStorageProtocol {
  /// Lists all projects that have sessions
  func listProjects() async throws -> [String]
  
  /// Gets all sessions for a specific project
  func getSessions(for projectPath: String) async throws -> [ClaudeStoredSession]
  
  /// Gets a specific session by ID
  func getSession(id: String, projectPath: String) async throws -> ClaudeStoredSession?
  
  /// Gets all sessions across all projects
  func getAllSessions() async throws -> [ClaudeStoredSession]
  
  /// Gets the messages for a specific session
  func getMessages(sessionId: String, projectPath: String) async throws -> [ClaudeStoredMessage]
  
  /// Gets the most recent session for a project
  func getMostRecentSession(for projectPath: String) async throws -> ClaudeStoredSession?
}