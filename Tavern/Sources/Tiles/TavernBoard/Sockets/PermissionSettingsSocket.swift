import Foundation
import TavernKit
import PermissionSettingsTile

// MARK: - Provenance: REQ-OPM-003

@MainActor
final class PermissionSettingsSocket {
    private var _tile: PermissionSettingsTile?
    private let permissionProvider: any PermissionProvider
    private weak var navigator: (any TavernNavigator)?

    init(permissionProvider: any PermissionProvider, navigator: any TavernNavigator) {
        self.permissionProvider = permissionProvider
        self.navigator = navigator
    }

    var tile: PermissionSettingsTile {
        if let existing = _tile {
            return existing
        }
        let nav = navigator
        let tile = PermissionSettingsTile(
            permissionProvider: permissionProvider,
            responder: PermissionSettingsResponder(
                onDismiss: {
                    MainActor.assumeIsolated {
                        nav?.dismissModal()
                    }
                }
            )
        )
        _tile = tile
        return tile
    }
}
