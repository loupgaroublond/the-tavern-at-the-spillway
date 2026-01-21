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
    private let spawner: AgentSpawner

    // MARK: - Initialization

    /// Create the view model
    /// - Parameters:
    ///   - jake: The Proprietor (always shown in list)
    ///   - spawner: The agent spawner (has access to registry and can provide full agent info)
    public init(jake: Jake, spawner: AgentSpawner) {
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

        // Add all active mortal agents (spawner has full agent info)
        for anyAgent in spawner.activeAgents {
            newItems.append(AgentListItem(
                id: anyAgent.id,
                name: anyAgent.name,
                assignmentSummary: getAssignmentSummary(for: anyAgent.id),
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

    // MARK: - Private Helpers

    /// Map of agent IDs to assignment summaries
    /// This is a workaround until we have proper type info from registry
    private var assignmentCache: [UUID: String] = [:]

    /// Register an assignment summary for an agent
    /// This should be called when agents are spawned
    public func cacheAssignment(agentId: UUID, assignment: String) {
        let maxLength = 50
        if assignment.count <= maxLength {
            assignmentCache[agentId] = assignment
        } else {
            assignmentCache[agentId] = String(assignment.prefix(maxLength - 3)) + "..."
        }
    }

    /// Get cached assignment summary for an agent
    private func getAssignmentSummary(for id: UUID) -> String? {
        assignmentCache[id]
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
