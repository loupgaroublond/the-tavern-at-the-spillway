import Foundation

/// A displayable item representing an agent in the list
/// This is a snapshot of agent state for UI display
public struct AgentListItem: Identifiable, Equatable, Sendable {

    /// Unique identifier (matches the agent's ID)
    public let id: UUID

    /// Display name
    public let name: String

    /// User-editable description shown in sidebar (nil for Jake)
    public let chatDescription: String?

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
        chatDescription: String? = nil,
        state: AgentState = .idle,
        isJake: Bool = false
    ) {
        self.id = id
        self.name = name
        self.chatDescription = chatDescription
        self.stateRawValue = state.rawValue
        self.isJake = isJake
    }

    // MARK: - Factory Methods

    /// Create an item from a Servitor
    public static func from(servitor: Servitor) -> AgentListItem {
        AgentListItem(
            id: servitor.id,
            name: servitor.name,
            chatDescription: servitor.chatDescription,
            state: servitor.state,
            isJake: false
        )
    }

    /// Create an item for Jake
    public static func from(jake: Jake) -> AgentListItem {
        AgentListItem(
            id: jake.id,
            name: jake.name,
            chatDescription: nil,
            state: jake.state,
            isJake: true
        )
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
        case .verifying: return "Verifying"
        case .done: return "Done"
        }
    }

    /// Whether the agent needs attention (waiting state)
    public var needsAttention: Bool {
        state == .waiting
    }
}
