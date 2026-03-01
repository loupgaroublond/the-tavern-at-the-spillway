import Foundation

/// A single TODO item in the side pane checklist
public struct TodoItem: Identifiable, Equatable, Sendable {

    /// Unique identifier
    public let id: UUID

    /// The TODO text
    public var text: String

    /// Whether this item is completed
    public var isCompleted: Bool

    /// When this item was created
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        text: String,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
