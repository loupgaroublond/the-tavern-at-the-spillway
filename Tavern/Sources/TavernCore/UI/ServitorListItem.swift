import Foundation

// ServitorListItem struct and display helpers have moved to TavernKit.
// Only factory methods that depend on TavernCore types remain here.

// MARK: - Factory Methods

extension ServitorListItem {

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
