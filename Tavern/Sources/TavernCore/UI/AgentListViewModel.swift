import Foundation

/// View model for the agent list
/// Manages the list of agents and selection state
@MainActor
public final class AgentListViewModel: ObservableObject {

    // MARK: - Published State

    /// All agents in the list
    @Published public private(set) var items: [AgentListItem] = []

    /// Currently selected agent ID
    @Published public var selectedAgentId: UUID?

    // MARK: - Dependencies

    private let jake: Jake
    private let spawner: ServitorSpawner

    // MARK: - Initialization

    /// Create the view model
    /// - Parameters:
    ///   - jake: The Proprietor (always shown in list)
    ///   - spawner: The servitor spawner (has access to registry and can provide full servitor info)
    public init(jake: Jake, spawner: ServitorSpawner) {
        self.jake = jake
        self.spawner = spawner

        // Start with Jake selected
        self.selectedAgentId = jake.id

        // Build initial list
        refreshItems()
    }

    // MARK: - Public Methods

    /// Refresh the list of agents from the spawner
    public func refreshItems() {
        var newItems: [AgentListItem] = []

        // Jake is always first
        newItems.append(AgentListItem.from(jake: jake))

        // Add all active servitors
        for anyAgent in spawner.activeServitors {
            // Get chatDescription from persisted storage
            let chatDescription = SessionStore.getAgent(id: anyAgent.id)?.chatDescription
            newItems.append(AgentListItem(
                id: anyAgent.id,
                name: anyAgent.name,
                chatDescription: chatDescription,
                state: anyAgent.state,
                isJake: false
            ))
        }

        items = newItems
    }

    /// Select an agent by ID
    /// - Parameter id: The agent ID to select
    public func selectAgent(id: UUID) {
        guard items.contains(where: { $0.id == id }) else { return }
        selectedAgentId = id
    }

    /// Get the currently selected item
    public var selectedItem: AgentListItem? {
        guard let id = selectedAgentId else { return nil }
        return items.first { $0.id == id }
    }

    /// Check if an agent is selected
    /// - Parameter id: The agent ID to check
    /// - Returns: true if this agent is selected
    public func isSelected(id: UUID) -> Bool {
        selectedAgentId == id
    }
}

// MARK: - Notification Support

extension AgentListViewModel {

    /// Update when agents change
    /// Call this after spawn/dismiss operations
    public func agentsDidChange() {
        refreshItems()

        // If selected agent was removed, select Jake
        if let selectedId = selectedAgentId,
           !items.contains(where: { $0.id == selectedId }) {
            selectedAgentId = jake.id
        }
    }
}
