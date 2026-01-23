import Foundation

/// Tavern-specific errors that are distinct from SDK errors
/// These represent application-level failure modes that we can handle specially
public enum TavernError: Error, LocalizedError {

    /// Session couldn't be resumed - it may be corrupt, expired, or a test artifact
    /// This happens when a saved session ID doesn't correspond to a valid Claude session
    case sessionCorrupt(sessionId: String, underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .sessionCorrupt(let sessionId, _):
            return "Session '\(sessionId)' could not be resumed"
        }
    }
}
