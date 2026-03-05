import Foundation
import os.log

// MARK: - Provenance: REQ-DOC-004, REQ-DOC-008

/// Utilities for loading session history from Claude's native JSONL storage.
///
/// Session ID persistence has moved to ServitorStore (file-system-backed).
/// This enum retains only the history-loading helpers that read from
/// Claude CLI's native `~/.claude/projects/` JSONL files.
public enum SessionStore {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "persistence")

    // MARK: - Jake Session History

    /// Load Jake's session history for a specific project from Claude's native storage.
    /// Falls back to the most recent session file if the session ID has no matching file.
    /// - Parameters:
    ///   - projectPath: The project path to load history for
    ///   - sessionId: The session ID to look up (from ServitorStore)
    /// - Returns: Array of stored messages, empty if no history found
    public static func loadJakeSessionHistory(projectPath: String, sessionId: String? = nil) async -> [ClaudeStoredMessage] {
        let storage = ClaudeNativeSessionStorage()

        // Try the provided session ID first
        if let sessionId {
            do {
                let messages = try await storage.getMessages(sessionId: sessionId, projectPath: projectPath)
                if !messages.isEmpty {
                    logger.debugInfo("Loaded \(messages.count) messages for Jake session \(sessionId)")
                    return messages
                }
            } catch {
                logger.debugError("Failed to load Jake session \(sessionId): \(error.localizedDescription)")
            }
        }

        // Fallback: try the most recent session file for this project
        do {
            if let recentSession = try await storage.getMostRecentSession(for: projectPath) {
                logger.debugInfo("Falling back to most recent session \(recentSession.id) with \(recentSession.messages.count) messages")
                return recentSession.messages
            }
        } catch {
            logger.debugError("Failed to load most recent session: \(error.localizedDescription)")
        }

        logger.debugInfo("No Jake session history found for project: \(projectPath)")
        return []
    }
}
