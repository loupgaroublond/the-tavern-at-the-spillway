import Foundation
import TavernKit
import ChatTile
import os.log

// MARK: - Provenance: REQ-ARCH-003, REQ-ARCH-004

@MainActor
final class ChatSocketPool {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "pool")

    private var tiles: [UUID: ChatTile] = [:]
    private let servitorProvider: any ServitorProvider
    private let commandProvider: any CommandProvider
    private weak var navigator: (any TavernNavigator)?

    init(
        servitorProvider: any ServitorProvider,
        commandProvider: any CommandProvider,
        navigator: any TavernNavigator
    ) {
        self.servitorProvider = servitorProvider
        self.commandProvider = commandProvider
        self.navigator = navigator
    }

    func tile(for servitorID: UUID) -> ChatTile {
        if let existing = tiles[servitorID] {
            Self.logger.info("[ChatSocketPool] cache hit for \(servitorID)")
            return existing
        }
        Self.logger.info("[ChatSocketPool] cache miss for \(servitorID) — creating new tile")

        let nav = navigator

        let responder = ChatResponder(
            onApprovalRequired: { request in
                guard let nav else {
                    return ToolApprovalResponse(approved: false, alwaysAllow: false)
                }
                return await nav.presentToolApproval(for: servitorID, request: request)
            },
            onPlanApprovalRequired: { request in
                guard let nav else {
                    return PlanApprovalResponse(approved: false, feedback: nil)
                }
                return await nav.presentPlanApproval(for: servitorID, request: request)
            },
            onActivityChanged: { activity in
                MainActor.assumeIsolated {
                    nav?.servitorActivityChanged(id: servitorID, activity: activity)
                }
            }
        )

        let tile = ChatTile(
            servitorID: servitorID,
            servitorProvider: servitorProvider,
            commandProvider: commandProvider,
            responder: responder
        )
        tiles[servitorID] = tile
        Task { await tile.loadSessionHistory() }
        return tile
    }

    func removeTile(for servitorID: UUID) {
        tiles.removeValue(forKey: servitorID)
    }
}
