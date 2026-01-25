import Foundation
import ClaudeCodeSDK

/// Stores session IDs locally using UserDefaults
/// Session IDs are machine-local (stored in ~/.claude/projects/) so they
/// don't belong in DocStore or other shareable storage
public enum SessionStore {

    // UserDefaults is thread-safe for read/write operations
    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    private static let jakeSessionPrefix = "com.tavern.jake.session."
    private static let agentSessionPrefix = "com.tavern.agent.session."

    // MARK: - Jake's Session (Per-Project)

    /// Save Jake's session ID for a specific project
    /// - Parameters:
    ///   - sessionId: The session ID to save, or nil to clear
    ///   - projectPath: The project path (working directory) for the session (required)
    public static func saveJakeSession(_ sessionId: String?, projectPath: String) {
        let key = jakeSessionKey(for: projectPath)
        if let id = sessionId {
            defaults.set(id, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    /// Load Jake's saved session ID for a specific project
    /// - Parameter projectPath: The project path to look up
    /// - Returns: The session ID if one was saved, nil otherwise
    public static func loadJakeSession(projectPath: String) -> String? {
        let key = jakeSessionKey(for: projectPath)
        return defaults.string(forKey: key)
    }

    /// Load Jake's session history for a specific project from Claude's native storage
    /// - Parameter projectPath: The project path to load history for
    /// - Returns: Array of stored messages, empty if no history found
    public static func loadJakeSessionHistory(projectPath: String) async -> [ClaudeStoredMessage] {
        guard let sessionId = loadJakeSession(projectPath: projectPath) else {
            return []
        }

        let storage = ClaudeNativeSessionStorage()
        do {
            return try await storage.getMessages(sessionId: sessionId, projectPath: projectPath)
        } catch {
            return []
        }
    }

    /// Clear Jake's session for a specific project
    /// - Parameter projectPath: The project path to clear
    public static func clearJakeSession(projectPath: String) {
        let key = jakeSessionKey(for: projectPath)
        defaults.removeObject(forKey: key)
    }

    /// Get the UserDefaults key for Jake's session in a project
    private static func jakeSessionKey(for projectPath: String) -> String {
        "\(jakeSessionPrefix)\(encodePathForKey(projectPath))"
    }

    /// Encode a path for use in a UserDefaults key
    /// Matches Claude CLI's encoding: replaces / and _ with -
    private static func encodePathForKey(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "_", with: "-")
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

    /// Clear all saved sessions (Jake across all projects, and all agents)
    public static func clearAllSessions() {
        // Clear all Jake sessions (one per project)
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(jakeSessionPrefix) {
            defaults.removeObject(forKey: key)
        }

        // Clear all agent sessions
        for key in allKeys where key.hasPrefix(agentSessionPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Private

    private static func agentSessionKey(for agentId: UUID) -> String {
        "\(agentSessionPrefix)\(agentId.uuidString)"
    }
}
