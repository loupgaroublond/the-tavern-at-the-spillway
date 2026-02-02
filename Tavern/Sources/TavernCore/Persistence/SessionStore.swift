import Foundation

/// Stores session IDs locally using UserDefaults
/// Session IDs are machine-local (stored in ~/.claude/projects/) so they
/// don't belong in DocStore or other shareable storage
public enum SessionStore {

    // UserDefaults is thread-safe for read/write operations
    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    private static let jakeSessionPrefix = "com.tavern.jake.session."
    private static let agentSessionPrefix = "com.tavern.agent.session."
    private static let agentListKey = "com.tavern.agents"

    // MARK: - Persisted Agent Type

    /// Data structure for persisting agent info
    public struct PersistedAgent: Codable, Equatable {
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

    /// Load a mortal agent's session history from Claude's native storage
    /// - Parameters:
    ///   - agentId: The agent's unique ID
    ///   - projectPath: The project path (needed to locate Claude's session files)
    /// - Returns: Array of stored messages, empty if no history found
    public static func loadAgentSessionHistory(agentId: UUID, projectPath: String) async -> [ClaudeStoredMessage] {
        guard let sessionId = loadAgentSession(agentId: agentId) else {
            return []
        }

        let storage = ClaudeNativeSessionStorage()
        do {
            return try await storage.getMessages(sessionId: sessionId, projectPath: projectPath)
        } catch {
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
        for key in allKeys where key.hasPrefix(agentSessionPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Private

    private static func agentSessionKey(for agentId: UUID) -> String {
        "\(agentSessionPrefix)\(agentId.uuidString)"
    }

    // MARK: - Agent List Persistence

    /// Save the full list of persisted agents
    public static func saveAgentList(_ agents: [PersistedAgent]) {
        do {
            let data = try JSONEncoder().encode(agents)
            defaults.set(data, forKey: agentListKey)
        } catch {
            // Silent failure - next app launch won't have agents, but no crash
        }
    }

    /// Load the list of persisted agents
    /// - Returns: Array of persisted agents, empty if none saved
    public static func loadAgentList() -> [PersistedAgent] {
        guard let data = defaults.data(forKey: agentListKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([PersistedAgent].self, from: data)
        } catch {
            return []
        }
    }

    /// Add an agent to the persisted list
    public static func addAgent(_ agent: PersistedAgent) {
        var agents = loadAgentList()
        // Replace if already exists (same ID), otherwise append
        if let index = agents.firstIndex(where: { $0.id == agent.id }) {
            agents[index] = agent
        } else {
            agents.append(agent)
        }
        saveAgentList(agents)
    }

    /// Update an existing agent in the persisted list
    public static func updateAgent(id: UUID, sessionId: String? = nil, chatDescription: String? = nil) {
        var agents = loadAgentList()
        guard let index = agents.firstIndex(where: { $0.id == id }) else { return }

        if let sessionId = sessionId {
            agents[index].sessionId = sessionId
        }
        if let chatDescription = chatDescription {
            agents[index].chatDescription = chatDescription
        }
        saveAgentList(agents)
    }

    /// Remove an agent from the persisted list
    public static func removeAgent(id: UUID) {
        var agents = loadAgentList()
        agents.removeAll { $0.id == id }
        saveAgentList(agents)
        // Also clear the session
        clearAgentSession(agentId: id)
    }

    /// Get a persisted agent by ID
    public static func getAgent(id: UUID) -> PersistedAgent? {
        loadAgentList().first { $0.id == id }
    }

    /// Clear all persisted agents (for testing)
    public static func clearAgentList() {
        saveAgentList([])
    }
}
