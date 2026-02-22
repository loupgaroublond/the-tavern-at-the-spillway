import Foundation

// MARK: - Provenance: REQ-LCM-004, REQ-OPM-004, REQ-VIW-005

/// View model for the servitor list
/// Manages the list of servitors and selection state
@MainActor
public final class ServitorListViewModel: ObservableObject {

    // MARK: - Published State

    /// All servitors in the list
    @Published public private(set) var items: [ServitorListItem] = []

    /// Currently selected servitor ID
    @Published public var selectedServitorId: UUID?

    // MARK: - Dependencies

    private let jake: Jake
    private let spawner: MortalSpawner

    // MARK: - Initialization

    /// Create the view model
    /// - Parameters:
    ///   - jake: The Proprietor (always shown in list)
    ///   - spawner: The servitor spawner (has access to registry and can provide full servitor info)
    public init(jake: Jake, spawner: MortalSpawner) {
        self.jake = jake
        self.spawner = spawner

        // Start with Jake selected
        self.selectedServitorId = jake.id

        // Build initial list
        refreshItems()
    }

    // MARK: - Public Methods

    /// Refresh the list of servitors from the spawner
    public func refreshItems() {
        var newItems: [ServitorListItem] = []

        // Jake is always first
        newItems.append(ServitorListItem.from(jake: jake))

        // Add all active servitors
        for anyAgent in spawner.activeMortals {
            // Get chatDescription from persisted storage
            let chatDescription = SessionStore.getServitor(id: anyAgent.id)?.chatDescription
            newItems.append(ServitorListItem(
                id: anyAgent.id,
                name: anyAgent.name,
                chatDescription: chatDescription,
                state: anyAgent.state,
                isJake: false
            ))
        }

        items = newItems
    }

    /// Select a servitor by ID
    /// - Parameter id: The servitor ID to select
    public func selectServitor(id: UUID) {
        guard items.contains(where: { $0.id == id }) else { return }
        selectedServitorId = id
    }

    /// Get the currently selected item
    public var selectedItem: ServitorListItem? {
        guard let id = selectedServitorId else { return nil }
        return items.first { $0.id == id }
    }

    /// Check if a servitor is selected
    /// - Parameter id: The servitor ID to check
    /// - Returns: true if this servitor is selected
    public func isSelected(id: UUID) -> Bool {
        selectedServitorId == id
    }
}

// MARK: - Notification Support

extension ServitorListViewModel {

    /// Update when servitors change
    /// Call this after spawn/dismiss operations
    public func servitorsDidChange() {
        refreshItems()

        // If selected servitor was removed, select Jake
        if let selectedId = selectedServitorId,
           !items.contains(where: { $0.id == selectedId }) {
            selectedServitorId = jake.id
        }
    }
}
