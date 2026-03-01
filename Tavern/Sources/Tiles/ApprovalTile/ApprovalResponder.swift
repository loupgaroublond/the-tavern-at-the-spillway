import Foundation
import TavernKit

public struct ToolApprovalResponder: Sendable {
    public var onResponse: @Sendable (ToolApprovalResponse) -> Void

    public init(onResponse: @escaping @Sendable (ToolApprovalResponse) -> Void) {
        self.onResponse = onResponse
    }
}

public struct PlanApprovalResponder: Sendable {
    public var onResponse: @Sendable (PlanApprovalResponse) -> Void

    public init(onResponse: @escaping @Sendable (PlanApprovalResponse) -> Void) {
        self.onResponse = onResponse
    }
}
