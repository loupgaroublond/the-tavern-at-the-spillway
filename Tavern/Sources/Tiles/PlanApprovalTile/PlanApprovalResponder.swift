import Foundation
import TavernKit

public struct PlanApprovalResponder: Sendable {
    public var onResponse: @Sendable (PlanApprovalResponse) -> Void

    public init(onResponse: @escaping @Sendable (PlanApprovalResponse) -> Void) {
        self.onResponse = onResponse
    }
}
