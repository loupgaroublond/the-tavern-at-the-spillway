import Foundation
import os.log

// MARK: - Tool Handler Protocol

/// Protocol for handling Jake's tool requests.
/// Current implementation: JSON parsing. Future: Native SDK tools.
/// Designed for easy replacement when SDK adds native tool support.
public protocol JakeToolHandler: Sendable {
    /// Process a response and execute any tool requests.
    /// - Parameter response: The raw response from Claude
    /// - Returns: Result containing display message and optional feedback for continuation
    func processResponse(_ response: String) async throws -> ToolResult
}

// MARK: - Tool Result

/// Result of processing a response through the tool handler
public struct ToolResult: Sendable {
    /// The message to display to the user
    public let displayMessage: String

    /// Feedback to send back to Jake (nil = conversation complete)
    public let toolFeedback: String?

    public init(displayMessage: String, toolFeedback: String? = nil) {
        self.displayMessage = displayMessage
        self.toolFeedback = toolFeedback
    }
}

// MARK: - JSON Action Handler

/// Handles tool requests by parsing JSON actions from Jake's responses.
/// This is the current implementation - will be replaced when SDK supports native tools.
public final class JSONActionHandler: JakeToolHandler, @unchecked Sendable {

    // MARK: - Types

    /// Jake's structured response format
    private struct JakeResponse: Codable {
        let message: String
        let spawn: SpawnAction?
    }

    /// A spawn action embedded in Jake's response
    private struct SpawnAction: Codable {
        let assignment: String
        let name: String?
    }

    // MARK: - Dependencies

    private let spawnAction: @Sendable (String, String?) async throws -> SpawnResult

    // MARK: - Initialization

    /// Create a handler with a spawn action closure
    /// - Parameter spawnAction: Closure that spawns an agent with (assignment, optionalName) -> SpawnResult
    public init(spawnAction: @escaping @Sendable (String, String?) async throws -> SpawnResult) {
        self.spawnAction = spawnAction
    }

    // MARK: - JakeToolHandler

    public func processResponse(_ response: String) async throws -> ToolResult {
        // Try to parse as JSON
        guard let data = response.data(using: .utf8) else {
            TavernLogger.agents.debug("JakeToolHandler: Response is not UTF-8, returning as-is")
            return ToolResult(displayMessage: response)
        }

        let decoder = JSONDecoder()
        guard let jakeResponse = try? decoder.decode(JakeResponse.self, from: data) else {
            // Not valid JSON or doesn't match our schema - return as plain text
            TavernLogger.agents.debug("JakeToolHandler: Response is not valid JakeResponse JSON, returning as-is")
            return ToolResult(displayMessage: response)
        }

        // We have a valid JakeResponse - check for spawn action
        if let spawn = jakeResponse.spawn {
            TavernLogger.agents.info("JakeToolHandler: Processing spawn action - assignment: \(spawn.assignment), name: \(spawn.name ?? "<auto>")")

            do {
                let result = try await spawnAction(spawn.assignment, spawn.name)
                let feedback = "Spawned agent '\(result.agentName)' (id: \(result.agentId)) for: \(spawn.assignment)"
                TavernLogger.agents.info("JakeToolHandler: Spawn succeeded - \(feedback)")

                return ToolResult(
                    displayMessage: jakeResponse.message,
                    toolFeedback: feedback
                )
            } catch {
                let feedback = "Failed to spawn agent: \(error.localizedDescription)"
                TavernLogger.agents.error("JakeToolHandler: Spawn failed - \(error.localizedDescription)")

                return ToolResult(
                    displayMessage: jakeResponse.message,
                    toolFeedback: feedback
                )
            }
        }

        // No actions, just a message
        TavernLogger.agents.debug("JakeToolHandler: No actions in response, returning message")
        return ToolResult(displayMessage: jakeResponse.message)
    }
}

// MARK: - Spawn Result

/// Result of a spawn action
public struct SpawnResult: Sendable {
    public let agentId: UUID
    public let agentName: String

    public init(agentId: UUID, agentName: String) {
        self.agentId = agentId
        self.agentName = agentName
    }
}
