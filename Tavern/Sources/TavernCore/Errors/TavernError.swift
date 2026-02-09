import Foundation

/// Tavern-specific errors that are distinct from SDK errors
/// These represent application-level failure modes that we can handle specially
public enum TavernError: Error, LocalizedError {

    /// Session couldn't be resumed - it may be corrupt, expired, or a test artifact
    case sessionCorrupt(sessionId: String, underlyingError: Error?)

    /// Agent name already in use by another agent in this project
    case agentNameConflict(name: String)

    /// Commitment verification timed out waiting for result
    case commitmentTimeout(commitmentId: String)

    /// MCP server failed to start or communicate
    case mcpServerFailed(reason: String)

    /// Tool execution was denied by permission rules
    case permissionDenied(toolName: String)

    /// Slash command not recognized
    case commandNotFound(name: String)

    /// Internal error - something truly unexpected happened (reserved for unknown failures)
    case internalError(String)

    public var errorDescription: String? {
        switch self {
        case .sessionCorrupt(let sessionId, _):
            return "Session '\(sessionId)' could not be resumed"
        case .agentNameConflict(let name):
            return "Agent name '\(name)' is already in use"
        case .commitmentTimeout(let commitmentId):
            return "Commitment '\(commitmentId)' verification timed out"
        case .mcpServerFailed(let reason):
            return "MCP server failure: \(reason)"
        case .permissionDenied(let toolName):
            return "Permission denied for tool '\(toolName)'"
        case .commandNotFound(let name):
            return "Unknown command '/\(name)'"
        case .internalError(let message):
            return "Internal error: \(message)"
        }
    }
}
