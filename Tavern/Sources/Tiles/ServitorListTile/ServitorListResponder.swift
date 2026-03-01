import Foundation

public struct ServitorListResponder: Sendable {
    public var onServitorSelected: @Sendable (UUID) -> Void
    public var onSpawnRequested: @Sendable () -> Void
    public var onCloseRequested: @Sendable (UUID) -> Void
    public var onDescriptionUpdated: @Sendable (UUID, String?) -> Void

    public init(
        onServitorSelected: @escaping @Sendable (UUID) -> Void,
        onSpawnRequested: @escaping @Sendable () -> Void,
        onCloseRequested: @escaping @Sendable (UUID) -> Void,
        onDescriptionUpdated: @escaping @Sendable (UUID, String?) -> Void
    ) {
        self.onServitorSelected = onServitorSelected
        self.onSpawnRequested = onSpawnRequested
        self.onCloseRequested = onCloseRequested
        self.onDescriptionUpdated = onDescriptionUpdated
    }
}
