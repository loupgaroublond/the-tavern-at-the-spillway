import Foundation

/// A displayable item representing an agent in the list
/// This is a snapshot of agent state for UI display
public struct AgentListItem: Identifiable, Equatable, Sendable {

    /// Unique identifier (matches the agent's ID)
    public let id: UUID

    /// Display name
    public let name: String

    /// Brief summary of what the agent is working on (nil for Jake)
    public let assignmentSummary: String?

    /// Current state of the agent (as raw value for Sendable)
    private let stateRawValue: String

    /// Current state of the agent
    public var state: AgentState {
        AgentState(rawValue: stateRawValue) ?? .idle
    }

    /// Whether this is Jake (The Proprietor)
    public let isJake: Bool

    // MARK: - Initialization

    /// Create an item directly (for testing and general use)
    public init(
        id: UUID = UUID(),
        name: String,
        assignmentSummary: String? = nil,
        state: AgentState = .idle,
        isJake: Bool = false
    ) {
        self.id = id
        self.name = name
        self.assignmentSummary = assignmentSummary
        self.stateRawValue = state.rawValue
        self.isJake = isJake
    }

    // MARK: - Factory Methods

    /// Create an item from a MortalAgent
    public static func from(mortalAgent: MortalAgent) -> AgentListItem {
        AgentListItem(
            id: mortalAgent.id,
            name: mortalAgent.name,
            assignmentSummary: summarize(mortalAgent.assignment),
            state: mortalAgent.state,
            isJake: false
        )
    }

    /// Create an item for Jake
    public static func from(jake: Jake) -> AgentListItem {
        AgentListItem(
            id: jake.id,
            name: jake.name,
            assignmentSummary: nil,
            state: jake.state,
            isJake: true
        )
    }

    // MARK: - Private Helpers

    /// Summarize a long assignment to a brief display string
    private static func summarize(_ assignment: String, maxLength: Int = 50) -> String {
        let trimmed = assignment.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxLength {
            return trimmed
        }
        let truncated = String(trimmed.prefix(maxLength - 3))
        return truncated + "..."
    }
}

// MARK: - Display Helpers

extension AgentListItem {

    /// Human-readable state label
    public var stateLabel: String {
        switch state {
        case .idle: return "Idle"
        case .working: return "Working"
        case .waiting: return "Needs attention"
        case .done: return "Done"
        }
    }

    /// Whether the agent needs attention (waiting state)
    public var needsAttention: Bool {
        state == .waiting
    }
}
