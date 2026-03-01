import Foundation
import TavernKit
import SwiftUI
import os.log

// MARK: - Provenance: REQ-OPM-004, REQ-UX-002, REQ-UX-003

@Observable @MainActor
public final class ServitorListTile {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "agents")

    // MARK: - State

    var items: [ServitorListItem]
    var selectedServitorId: UUID?
    var editingDescriptionForServitorId: UUID?
    var editedDescription: String = ""

    // MARK: - Dependencies

    private let servitorProvider: any ServitorProvider
    let responder: ServitorListResponder

    // MARK: - Initialization

    public init(servitorProvider: any ServitorProvider, responder: ServitorListResponder) {
        self.servitorProvider = servitorProvider
        self.responder = responder
        self.items = servitorProvider.allServitors()
        Self.logger.info("[ServitorListTile] initialized - items: \(servitorProvider.allServitors().count)")
    }

    public func makeView() -> some View {
        ServitorListTileView(tile: self)
    }

    // MARK: - Actions

    func isSelected(id: UUID) -> Bool {
        selectedServitorId == id
    }

    public func selectServitor(id: UUID) {
        Self.logger.info("[ServitorListTile] selectServitor: \(id)")
        selectedServitorId = id
        responder.onServitorSelected(id)
    }

    /// Update selection state without firing the responder.
    /// Used by the board when it already knows about the selection.
    public func setSelectedServitor(id: UUID) {
        selectedServitorId = id
    }

    func closeServitor(id: UUID) {
        Self.logger.info("[ServitorListTile] closeServitor: \(id)")
        responder.onCloseRequested(id)
    }

    func spawnServitor() {
        Self.logger.info("[ServitorListTile] spawnServitor")
        responder.onSpawnRequested()
    }

    func beginEditDescription(for item: ServitorListItem) {
        Self.logger.debug("[ServitorListTile] beginEditDescription for: \(item.id)")
        editedDescription = item.chatDescription ?? ""
        editingDescriptionForServitorId = item.id
    }

    func saveDescription() {
        guard let servitorId = editingDescriptionForServitorId else { return }
        let desc = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        Self.logger.info("[ServitorListTile] saveDescription for: \(servitorId)")
        responder.onDescriptionUpdated(servitorId, desc.isEmpty ? nil : desc)
        editingDescriptionForServitorId = nil
        editedDescription = ""
    }

    func cancelEditDescription() {
        Self.logger.debug("[ServitorListTile] cancelEditDescription")
        editingDescriptionForServitorId = nil
        editedDescription = ""
    }

    /// Called by the board when the servitor list changes externally.
    public func servitorsDidChange() {
        Self.logger.debug("[ServitorListTile] servitorsDidChange")
        items = servitorProvider.allServitors()
    }
}
