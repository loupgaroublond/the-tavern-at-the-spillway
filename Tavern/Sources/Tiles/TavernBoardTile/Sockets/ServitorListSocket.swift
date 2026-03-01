import Foundation
import TavernKit
import ServitorListTile

// MARK: - Provenance: REQ-ARCH-003

@MainActor
final class ServitorListSocket {
    let tile: ServitorListTile

    func selectServitor(id: UUID) {
        tile.setSelectedServitor(id: id)
    }

    init(servitorProvider: any ServitorProvider, navigator: any TavernNavigator) {
        let nav = navigator
        self.tile = ServitorListTile(
            servitorProvider: servitorProvider,
            responder: ServitorListResponder(
                onServitorSelected: { id in
                    MainActor.assumeIsolated {
                        nav.selectServitor(id: id)
                    }
                },
                onSpawnRequested: {
                    MainActor.assumeIsolated {
                        nav.spawnServitor()
                    }
                },
                onCloseRequested: { id in
                    MainActor.assumeIsolated {
                        nav.closeServitor(id: id)
                    }
                },
                onDescriptionUpdated: { id, desc in
                    MainActor.assumeIsolated {
                        nav.updateServitorDescription(id: id, description: desc)
                    }
                }
            )
        )
    }
}
