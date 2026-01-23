import Foundation
import ClaudeCodeSDK

/// Stores session IDs locally using UserDefaults
/// Session IDs are machine-local (stored in ~/.claude/projects/) so they
/// don't belong in DocStore or other shareable storage
public enum SessionStore {

    // UserDefaults is thread-safe for read/write operations
    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    private static let jakeSessionKey = "com.tavern.jake.sessionId"
    private static let jakeProjectPathKey = "com.tavern.jake.projectPath"
    private static let agentSessionPrefix = "com.tavern.agent.session."

    // MARK: - Jake's Session

    /// Save Jake's current session ID and project path
    /// - Parameters:
    ///   - sessionId: The session ID to save, or nil to clear
    ///   - projectPath: The project path (working directory) for the session
    public static func saveJakeSession(_ sessionId: String?, projectPath: String? = nil) {
        if let id = sessionId {
            defaults.set(id, forKey: jakeSessionKey)
            if let path = projectPath {
                defaults.set(path, forKey: jakeProjectPathKey)
            }
        } else {
            defaults.removeObject(forKey: jakeSessionKey)
            defaults.removeObject(forKey: jakeProjectPathKey)
        }
    }

    /// Load Jake's saved session ID
    /// - Returns: The session ID if one was saved, nil otherwise
    public static func loadJakeSession() -> String? {
        defaults.string(forKey: jakeSessionKey)
    }

    /// Load Jake's saved project path
    /// - Returns: The project path if one was saved, nil otherwise
    public static func loadJakeProjectPath() -> String? {
        defaults.string(forKey: jakeProjectPathKey)
    }

    /// Load Jake's session history from Claude's native storage
    /// - Returns: Array of stored messages, empty if no history found
    public static func loadJakeSessionHistory() async -> [ClaudeStoredMessage] {
        guard let sessionId = loadJakeSession(),
              let projectPath = loadJakeProjectPath() else {
            return []
        }

        let storage = ClaudeNativeSessionStorage()
        do {
            return try await storage.getMessages(sessionId: sessionId, projectPath: projectPath)
        } catch {
            return []
        }
    }

    // MARK: - Mortal Agent Sessions

    /// Save a mortal agent's session ID
    /// - Parameters:
    ///   - agentId: The agent's unique ID
    ///   - sessionId: The session ID to save, or nil to clear
    public static func saveAgentSession(agentId: UUID, sessionId: String?) {
        let key = agentSessionKey(for: agentId)
        if let id = sessionId {
            defaults.set(id, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    /// Load a mortal agent's saved session ID
    /// - Parameter agentId: The agent's unique ID
    /// - Returns: The session ID if one was saved, nil otherwise
    public static func loadAgentSession(agentId: UUID) -> String? {
        let key = agentSessionKey(for: agentId)
        return defaults.string(forKey: key)
    }

    /// Clear a mortal agent's session
    /// - Parameter agentId: The agent's unique ID
    public static func clearAgentSession(agentId: UUID) {
        let key = agentSessionKey(for: agentId)
        defaults.removeObject(forKey: key)
    }

    // MARK: - Bulk Operations

    /// Clear all saved sessions (Jake and all agents)
    public static func clearAllSessions() {
        defaults.removeObject(forKey: jakeSessionKey)

        // Clear all agent sessions by iterating keys
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(agentSessionPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Private

    private static func agentSessionKey(for agentId: UUID) -> String {
        "\(agentSessionPrefix)\(agentId.uuidString)"
    }
}
