//
//  ClaudeNativeSessionStorage.swift
//  ClaudeCodeSDK
//
//  Created by Assistant on 8/18/2025.
//

import Foundation
import OSLog

/// Implementation of Claude's native session storage that reads from ~/.claude/projects/
public class ClaudeNativeSessionStorage: ClaudeSessionStorageProtocol {
  private let basePath: String
  private let fileManager = FileManager.default
  private let logger = Logger(subsystem: "com.claudecode.sdk", category: "SessionStorage")
  private let decoder = JSONDecoder()
  
  public init(basePath: String? = nil) {
    self.basePath = basePath ?? NSString(string: "~/.claude/projects").expandingTildeInPath
  }
  
  // MARK: - Public Methods
  
  public func listProjects() async throws -> [String] {
    guard fileManager.fileExists(atPath: basePath) else {
      logger.info("Claude projects directory not found at \(self.basePath)")
      return []
    }
    
    let contents = try fileManager.contentsOfDirectory(atPath: basePath)
    
    // Filter only directories and decode the project paths
    let projects = contents.compactMap { item -> String? in
      let fullPath = (basePath as NSString).appendingPathComponent(item)
      var isDirectory: ObjCBool = false
      
      guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
            isDirectory.boolValue else {
        return nil
      }
      
      // Decode the project path (convert dashes back to slashes)
      return decodeProjectPath(item)
    }
    
    return projects.sorted()
  }
  
  public func getSessions(for projectPath: String) async throws -> [ClaudeStoredSession] {
    let encodedPath = encodeProjectPath(projectPath)
    let projectDir = (basePath as NSString).appendingPathComponent(encodedPath)
    
    guard fileManager.fileExists(atPath: projectDir) else {
      logger.info("No sessions found for project: \(projectPath)")
      return []
    }
    
    let files = try fileManager.contentsOfDirectory(atPath: projectDir)
    let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
    
    var sessions: [ClaudeStoredSession] = []
    
    for file in jsonlFiles {
      let sessionId = String(file.dropLast(6)) // Remove .jsonl extension
      let filePath = (projectDir as NSString).appendingPathComponent(file)
      
      if let session = try await parseSessionFile(
        at: filePath,
        sessionId: sessionId,
        projectPath: projectPath
      ) {
        sessions.append(session)
      }
    }
    
    // Sort by last accessed date (most recent first)
    return sessions.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
  }
  
  public func getSession(id: String, projectPath: String) async throws -> ClaudeStoredSession? {
    let encodedPath = encodeProjectPath(projectPath)
    let projectDir = (basePath as NSString).appendingPathComponent(encodedPath)
    let filePath = (projectDir as NSString).appendingPathComponent("\(id).jsonl")
    
    guard fileManager.fileExists(atPath: filePath) else {
      logger.info("Session file not found: \(filePath)")
      return nil
    }
    
    return try await parseSessionFile(
      at: filePath,
      sessionId: id,
      projectPath: projectPath
    )
  }
  
  public func getAllSessions() async throws -> [ClaudeStoredSession] {
    let projects = try await listProjects()
    var allSessions: [ClaudeStoredSession] = []
    
    for project in projects {
      let sessions = try await getSessions(for: project)
      allSessions.append(contentsOf: sessions)
    }
    
    // Sort all sessions by last accessed date
    return allSessions.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
  }
  
  public func getMessages(sessionId: String, projectPath: String) async throws -> [ClaudeStoredMessage] {
    if let session = try await getSession(id: sessionId, projectPath: projectPath) {
      return session.messages
    }
    return []
  }
  
  public func getMostRecentSession(for projectPath: String) async throws -> ClaudeStoredSession? {
    let sessions = try await getSessions(for: projectPath)
    return sessions.first // Already sorted by most recent
  }
  
  // MARK: - Private Methods
  
  private func encodeProjectPath(_ path: String) -> String {
    // Replace slashes with dashes, as Claude CLI does
    return path.replacingOccurrences(of: "/", with: "-")
  }
  
  private func decodeProjectPath(_ encoded: String) -> String {
    // Convert dashes back to slashes
    return encoded.replacingOccurrences(of: "-", with: "/")
  }
  
  private func parseSessionFile(
    at filePath: String,
    sessionId: String,
    projectPath: String
  ) async throws -> ClaudeStoredSession? {
    guard let data = fileManager.contents(atPath: filePath) else {
      logger.error("Failed to read session file: \(filePath)")
      return nil
    }
    
    // Parse JSONL file (each line is a separate JSON object)
    let lines = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines) ?? []
    
    var messages: [ClaudeStoredMessage] = []
    var summary: String?
    var gitBranch: String?
    var firstTimestamp: Date?
    var lastTimestamp: Date?
    
    for line in lines where !line.isEmpty {
      guard let lineData = line.data(using: .utf8) else { continue }
      
      do {
        let entry = try decoder.decode(ClaudeJSONLEntry.self, from: lineData)
        
        // Extract summary if present
        if entry.type == "summary", let entrySummary = entry.summary {
          summary = entrySummary
        }
        
        // Extract git branch from first user message
        if gitBranch == nil, entry.type == "user" {
          gitBranch = entry.gitBranch
        }
        
        // Parse messages
        if let message = entry.message,
           let role = message.role,
           let uuid = entry.uuid {
          
          let timestamp = parseTimestamp(entry.timestamp)
          
          // Track first and last timestamps
          if let ts = timestamp {
            if firstTimestamp == nil || ts < firstTimestamp! {
              firstTimestamp = ts
            }
            if lastTimestamp == nil || ts > lastTimestamp! {
              lastTimestamp = ts
            }
          }
          
          // Extract text content
          let content = message.content?.textContent ?? ""
          
          let storedMessage = ClaudeStoredMessage(
            id: uuid,
            parentId: entry.parentUuid,
            sessionId: entry.sessionId ?? sessionId,
            role: ClaudeStoredMessage.MessageRole(rawValue: role) ?? .user,
            content: content,
            timestamp: timestamp ?? Date(),
            cwd: entry.cwd,
            version: entry.version
          )
          
          messages.append(storedMessage)
        }
      } catch {
        // Log but continue parsing other lines
        logger.debug("Failed to parse JSONL line: \(error)")
      }
    }
    
    // If we found any messages, create a session
    guard !messages.isEmpty || summary != nil else {
      return nil
    }
    
    return ClaudeStoredSession(
      id: sessionId,
      projectPath: projectPath,
      createdAt: firstTimestamp ?? Date(),
      lastAccessedAt: lastTimestamp ?? Date(),
      summary: summary,
      gitBranch: gitBranch,
      messages: messages
    )
  }
  
  private func parseTimestamp(_ timestamp: String?) -> Date? {
    guard let timestamp = timestamp else { return nil }
    
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    if let date = formatter.date(from: timestamp) {
      return date
    }
    
    // Try without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: timestamp)
  }
}