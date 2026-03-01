import Foundation

public struct ResourcePanelResponder: Sendable {
    public var onFileSelected: @Sendable (URL) -> Void

    public init(onFileSelected: @escaping @Sendable (URL) -> Void) {
        self.onFileSelected = onFileSelected
    }
}
