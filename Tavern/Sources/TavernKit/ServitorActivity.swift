import Foundation

/// The agent's current activity state — single source of truth for UI indicators.
/// Eliminates impossible state combinations (e.g. cogitating + tool running).
public enum ServitorActivity: Equatable, Sendable {
    case idle
    case cogitating(verb: String)
    case streaming
    case toolRunning(name: String, startTime: Date)
}
