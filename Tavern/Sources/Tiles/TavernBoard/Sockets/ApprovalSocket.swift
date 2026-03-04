import Foundation
import TavernKit
import ToolApprovalTile
import PlanApprovalTile

// MARK: - Provenance: REQ-OPM-001, REQ-OPM-002

@MainActor
final class ApprovalSocket {
    private weak var navigator: (any TavernNavigator)?

    init(navigator: any TavernNavigator) {
        self.navigator = navigator
    }

    func makeToolApprovalTile(request: ToolApprovalRequest) -> ToolApprovalTile {
        let nav = navigator
        return ToolApprovalTile(
            request: request,
            responder: ToolApprovalResponder(
                onResponse: { response in
                    MainActor.assumeIsolated {
                        nav?.respondToToolApproval(response)
                    }
                }
            )
        )
    }

    func makePlanApprovalTile(request: PlanApprovalRequest) -> PlanApprovalTile {
        let nav = navigator
        return PlanApprovalTile(
            request: request,
            responder: PlanApprovalResponder(
                onResponse: { response in
                    MainActor.assumeIsolated {
                        nav?.respondToPlanApproval(response)
                    }
                }
            )
        )
    }
}
