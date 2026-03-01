import Foundation
import TavernKit

public struct ChatResponder: Sendable {
    public var onApprovalRequired: @Sendable (ToolApprovalRequest) async -> ToolApprovalResponse
    public var onPlanApprovalRequired: @Sendable (PlanApprovalRequest) async -> PlanApprovalResponse
    public var onActivityChanged: @Sendable (ServitorActivity) -> Void

    public init(
        onApprovalRequired: @escaping @Sendable (ToolApprovalRequest) async -> ToolApprovalResponse,
        onPlanApprovalRequired: @escaping @Sendable (PlanApprovalRequest) async -> PlanApprovalResponse,
        onActivityChanged: @escaping @Sendable (ServitorActivity) -> Void
    ) {
        self.onApprovalRequired = onApprovalRequired
        self.onPlanApprovalRequired = onPlanApprovalRequired
        self.onActivityChanged = onActivityChanged
    }
}
