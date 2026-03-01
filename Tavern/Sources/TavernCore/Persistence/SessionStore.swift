import Foundation
import os.log

// MARK: - Provenance: REQ-DOC-004, REQ-DOC-008, REQ-INV-005

/// Stores session IDs locally using UserDefaults
/// Session IDs are machine-local (stored in ~/.claude/projects/) so they
/// don't belong in DocStore or other shareable storage
public enum SessionStore {

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "persistence")

    // UserDefaults is thread-safe for read/write operations
    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    private static let jakeSessionPrefix = "com.tavern.jake.session."
    private static let servitorSessionPrefix = "com.tavern.servitor.session."
    private static let servitorListKey = "com.tavern.servitors"

    // MARK: - Persisted Agent Type

    /// Data structure for persisting agent info
    public struct PersistedServitor: Codable, Equatable {
        public let id: UUID
        public let name: String
        public var sessionId: String?
        public var chatDescription: String?

        public init(id: UUID, name: String, sessionId: String? = nil, chatDescription: String? = nil) {
            self.id = id
            self.name = name
            self.sessionId = sessionId
            self.chatDescription = chatDescription
        }
    }

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

    /// Load Jake's session history for a specific project from Claude's native storage.
    /// Falls back to the most recent session file if the stored session ID has no matching file.
    /// - Parameter projectPath: The project path to load history for
    /// - Returns: Array of stored messages, empty if no history found
    public static func loadJakeSessionHistory(projectPath: String) async -> [ClaudeStoredMessage] {
        let storage = ClaudeNativeSessionStorage()

        // Try the stored session ID first
        if let sessionId = loadJakeSession(projectPath: projectPath) {
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
    ///   - servitorId: The agent's unique ID
    ///   - sessionId: The session ID to save, or nil to clear
    public static func saveServitorSession(servitorId: UUID, sessionId: String?) {
        let key = servitorSessionKey(for: servitorId)
        if let id = sessionId {
            defaults.set(id, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    /// Load a mortal agent's saved session ID
    /// - Parameter servitorId: The agent's unique ID
    /// - Returns: The session ID if one was saved, nil otherwise
    public static func loadServitorSession(servitorId: UUID) -> String? {
        let key = servitorSessionKey(for: servitorId)
        return defaults.string(forKey: key)
    }

    /// Clear a mortal agent's session
    /// - Parameter servitorId: The agent's unique ID
    public static func clearServitorSession(servitorId: UUID) {
        let key = servitorSessionKey(for: servitorId)
        defaults.removeObject(forKey: key)
    }

    /// Load a mortal agent's session history from Claude's native storage
    /// - Parameters:
    ///   - servitorId: The agent's unique ID
    ///   - projectPath: The project path (needed to locate Claude's session files)
    /// - Returns: Array of stored messages, empty if no history found
    public static func loadServitorSessionHistory(servitorId: UUID, projectPath: String) async -> [ClaudeStoredMessage] {
        guard let sessionId = loadServitorSession(servitorId: servitorId) else {
            logger.debugInfo("No session found for servitor \(servitorId)")
            return []
        }

        let storage = ClaudeNativeSessionStorage()
        do {
            let messages = try await storage.getMessages(sessionId: sessionId, projectPath: projectPath)
            logger.debugInfo("Loaded \(messages.count) messages for servitor \(servitorId)")
            return messages
        } catch {
            logger.debugError("Failed to load servitor session history: \(error.localizedDescription)")
            return []
        }
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
        for key in allKeys where key.hasPrefix(servitorSessionPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Private

    private static func servitorSessionKey(for servitorId: UUID) -> String {
        "\(servitorSessionPrefix)\(servitorId.uuidString)"
    }

    // MARK: - Agent List Persistence

    /// Save the full list of persisted agents
    public static func saveServitorList(_ agents: [PersistedServitor]) {
        do {
            let data = try JSONEncoder().encode(agents)
            defaults.set(data, forKey: servitorListKey)
            logger.debugLog("Saved \(agents.count) servitors to UserDefaults")
        } catch {
            logger.debugError("Failed to encode servitor list: \(error.localizedDescription)")
        }
    }

    /// Load the list of persisted agents
    /// - Returns: Array of persisted agents, empty if none saved
    public static func loadServitorList() -> [PersistedServitor] {
        guard let data = defaults.data(forKey: servitorListKey) else {
            logger.debugLog("No persisted servitor list found in UserDefaults")
            return []
        }
        do {
            let agents = try JSONDecoder().decode([PersistedServitor].self, from: data)
            logger.debugLog("Loaded \(agents.count) servitors from UserDefaults")
            return agents
        } catch {
            logger.debugError("Failed to decode servitor list: \(error.localizedDescription)")
            return []
        }
    }

    /// Add an agent to the persisted list
    public static func addServitor(_ agent: PersistedServitor) {
        var agents = loadServitorList()
        // Replace if already exists (same ID), otherwise append
        if let index = agents.firstIndex(where: { $0.id == agent.id }) {
            agents[index] = agent
        } else {
            agents.append(agent)
        }
        saveServitorList(agents)
    }

    /// Update an existing agent in the persisted list
    public static func updateServitor(id: UUID, sessionId: String? = nil, chatDescription: String? = nil) {
        var agents = loadServitorList()
        guard let index = agents.firstIndex(where: { $0.id == id }) else { return }

        if let sessionId = sessionId {
            agents[index].sessionId = sessionId
        }
        if let chatDescription = chatDescription {
            agents[index].chatDescription = chatDescription
        }
        saveServitorList(agents)
    }

    /// Remove an agent from the persisted list
    public static func removeServitor(id: UUID) {
        var agents = loadServitorList()
        agents.removeAll { $0.id == id }
        saveServitorList(agents)
        // Also clear the session
        clearServitorSession(servitorId: id)
    }

    /// Get a persisted agent by ID
    public static func getServitor(id: UUID) -> PersistedServitor? {
        loadServitorList().first { $0.id == id }
    }

    /// Clear all persisted agents (for testing)
    public static func clearServitorList() {
        saveServitorList([])
    }
}
