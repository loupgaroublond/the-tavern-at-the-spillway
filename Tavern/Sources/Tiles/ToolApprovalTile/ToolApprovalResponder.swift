import Foundation
import TavernKit

public struct ToolApprovalResponder: Sendable {
    public var onResponse: @Sendable (ToolApprovalResponse) -> Void

    public init(onResponse: @escaping @Sendable (ToolApprovalResponse) -> Void) {
        self.onResponse = onResponse
    }
}
