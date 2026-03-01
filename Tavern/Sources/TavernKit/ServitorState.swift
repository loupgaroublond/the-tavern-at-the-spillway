import Foundation

// MARK: - Provenance: REQ-AGT-005, REQ-AGT-010, REQ-ARCH-004

/// State of a servitor in the Tavern
public enum ServitorState: String, Equatable, Sendable {
    /// Servitor is idle, waiting for work
    case idle

    /// Servitor is actively working on a task
    case working

    /// Servitor is waiting for input or decision
    case waiting

    /// Servitor is verifying its commitments before completing
    case verifying

    /// Servitor has completed their assignment
    case done

    /// Servitor encountered an error
    case error
}
