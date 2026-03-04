import Foundation
import TavernKit
import SwiftUI

@Observable @MainActor
public final class ToolApprovalTile {
    public typealias Responder = ToolApprovalResponder

    let request: ToolApprovalRequest
    let responder: ToolApprovalResponder
    var alwaysAllow: Bool = false

    public init(request: ToolApprovalRequest, responder: ToolApprovalResponder) {
        self.request = request
        self.responder = responder
    }

    public func makeView() -> some View {
        ToolApprovalTileView(tile: self)
    }

    func approve() {
        responder.onResponse(ToolApprovalResponse(approved: true, alwaysAllow: alwaysAllow))
    }

    func deny() {
        responder.onResponse(ToolApprovalResponse(approved: false, alwaysAllow: false))
    }
}
