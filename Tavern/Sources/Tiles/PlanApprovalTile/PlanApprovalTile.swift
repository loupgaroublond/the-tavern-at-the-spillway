import Foundation
import TavernKit
import SwiftUI

@Observable @MainActor
public final class PlanApprovalTile {
    public typealias Responder = PlanApprovalResponder

    let request: PlanApprovalRequest
    let responder: PlanApprovalResponder
    var feedback: String = ""

    public init(request: PlanApprovalRequest, responder: PlanApprovalResponder) {
        self.request = request
        self.responder = responder
    }

    public func makeView() -> some View {
        PlanApprovalTileView(tile: self)
    }

    func approve() {
        responder.onResponse(PlanApprovalResponse(approved: true))
    }

    func reject() {
        responder.onResponse(PlanApprovalResponse(
            approved: false,
            feedback: feedback.isEmpty ? nil : feedback
        ))
    }
}
