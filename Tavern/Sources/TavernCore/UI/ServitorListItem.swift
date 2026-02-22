import Foundation

/// A displayable item representing a servitor in the list
/// This is a snapshot of servitor state for UI display
public struct ServitorListItem: Identifiable, Equatable, Sendable {

    /// Unique identifier (matches the servitor's ID)
    public let id: UUID

    /// Display name
    public let name: String

    /// User-editable description shown in sidebar (nil for Jake)
    public let chatDescription: String?

    /// Current state of the servitor (as raw value for Sendable)
    private let stateRawValue: String

    /// Current state of the servitor
    public var state: ServitorState {
        ServitorState(rawValue: stateRawValue) ?? .idle
    }

    /// Whether this is Jake (The Proprietor)
    public let isJake: Bool

    // MARK: - Initialization

    /// Create an item directly (for testing and general use)
    public init(
        id: UUID = UUID(),
        name: String,
        chatDescription: String? = nil,
        state: ServitorState = .idle,
        isJake: Bool = false
    ) {
        self.id = id
        self.name = name
        self.chatDescription = chatDescription
        self.stateRawValue = state.rawValue
        self.isJake = isJake
    }

    // MARK: - Factory Methods

    /// Create an item from a Mortal
    public static func from(mortal: Mortal) -> ServitorListItem {
        ServitorListItem(
            id: mortal.id,
            name: mortal.name,
            chatDescription: mortal.chatDescription,
            state: mortal.state,
            isJake: false
        )
    }

    /// Create an item for Jake
    public static func from(jake: Jake) -> ServitorListItem {
        ServitorListItem(
            id: jake.id,
            name: jake.name,
            chatDescription: nil,
            state: jake.state,
            isJake: true
        )
    }
}

// MARK: - Display Helpers

extension ServitorListItem {

    /// Human-readable state label
    public var stateLabel: String {
        switch state {
        case .idle: return "Idle"
        case .working: return "Working"
        case .waiting: return "Needs attention"
        case .verifying: return "Verifying"
        case .done: return "Done"
        case .error: return "Error"
        }
    }

    /// Whether the servitor needs attention (waiting or error state)
    public var needsAttention: Bool {
        state == .waiting || state == .error
    }
}
