import Foundation
import TavernKit
import ResourcePanelTile

// MARK: - Provenance: REQ-ARCH-003

@MainActor
final class ResourcePanelSocket {
    let tile: ResourcePanelTile

    init(resourceProvider: any ResourceProvider, rootURL: URL) {
        self.tile = ResourcePanelTile(
            resourceProvider: resourceProvider,
            responder: ResourcePanelResponder(
                onFileSelected: { _ in
                    // File selection is handled within the resource panel itself
                }
            ),
            rootURL: rootURL
        )
    }
}
