import Foundation

public struct PermissionSettingsResponder: Sendable {
    public var onDismiss: @Sendable () -> Void

    public init(onDismiss: @escaping @Sendable () -> Void) {
        self.onDismiss = onDismiss
    }
}
