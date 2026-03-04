import Foundation
import TavernKit

// MARK: - Provenance: REQ-ARCH-003, REQ-ARCH-004

@MainActor
public protocol TavernNavigator: AnyObject, Sendable {
    func selectServitor(id: UUID)
    func spawnServitor()
    func closeServitor(id: UUID)
    func updateServitorDescription(id: UUID, description: String?)

    func presentToolApproval(for servitorID: UUID, request: ToolApprovalRequest) async -> ToolApprovalResponse
    func presentPlanApproval(for servitorID: UUID, request: PlanApprovalRequest) async -> PlanApprovalResponse
    func respondToToolApproval(_ response: ToolApprovalResponse)
    func respondToPlanApproval(_ response: PlanApprovalResponse)
    func dismissModal()

    func toggleSidePane()
    func selectSidePaneTab(_ tab: SidePaneTab)

    func servitorActivityChanged(id: UUID, activity: ServitorActivity)
    func presentPermissionSettings()
}
