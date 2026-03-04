import Foundation
import TavernKit

// MARK: - Provenance: REQ-ARCH-003, REQ-ARCH-004

public enum DetailFacet: Hashable, Sendable {
    case empty
    case chat(UUID)  // ServitorID
}

public enum SidebarFacet: Hashable, Sendable {
    case agents
}

public enum ModalFacet: Identifiable, Sendable {
    case toolApproval(UUID, ToolApprovalRequest)
    case planApproval(UUID, PlanApprovalRequest)
    case permissionSettings

    public var id: String {
        switch self {
        case .toolApproval(let servitorId, _):
            return "toolApproval-\(servitorId)"
        case .planApproval(let servitorId, _):
            return "planApproval-\(servitorId)"
        case .permissionSettings:
            return "permissionSettings"
        }
    }
}

public enum SidePaneFacet: Hashable, Sendable {
    case hidden
    case visible(SidePaneTab)
}
