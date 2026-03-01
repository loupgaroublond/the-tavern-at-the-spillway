import Foundation
import TavernKit
import SwiftUI
import os.log
import ApprovalTile
import ChatTile
import ServitorListTile
import ResourcePanelTile
import PermissionSettingsTile

// MARK: - Provenance: REQ-ARCH-003, REQ-ARCH-004, REQ-ARCH-008

@Observable @MainActor
public final class WindowBoard: TavernNavigator {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "board")

    // MARK: - Facets

    var detailFacet: DetailFacet = .empty
    var sidebarFacet: SidebarFacet = .agents
    var activeModal: ModalFacet?
    var sidePaneFacet: SidePaneFacet = .hidden

    // MARK: - Active State

    var activeServitorID: UUID?

    // MARK: - Approval Continuations

    private var pendingApprovalContinuation: CheckedContinuation<ToolApprovalResponse, Never>?
    private var pendingPlanContinuation: CheckedContinuation<PlanApprovalResponse, Never>?

    // MARK: - Sockets

    private(set) var servitorListSocket: ServitorListSocket!
    private(set) var chatSocketPool: ChatSocketPool!
    private(set) var resourcePanelSocket: ResourcePanelSocket!
    private(set) var approvalSocket: ApprovalSocket!
    private(set) var permissionSettingsSocket: PermissionSettingsSocket!

    // MARK: - Providers

    let servitorProvider: any ServitorProvider
    let commandProvider: any CommandProvider
    let resourceProvider: any ResourceProvider
    let permissionProvider: any PermissionProvider
    let projectName: String
    let rootURL: URL

    // MARK: - Initialization

    public init(
        servitorProvider: any ServitorProvider,
        commandProvider: any CommandProvider,
        resourceProvider: any ResourceProvider,
        permissionProvider: any PermissionProvider,
        projectName: String,
        rootURL: URL
    ) {
        self.servitorProvider = servitorProvider
        self.commandProvider = commandProvider
        self.resourceProvider = resourceProvider
        self.permissionProvider = permissionProvider
        self.projectName = projectName
        self.rootURL = rootURL

        // Create sockets (must be done after all stored properties are set)
        self.servitorListSocket = ServitorListSocket(
            servitorProvider: servitorProvider,
            navigator: self
        )
        self.chatSocketPool = ChatSocketPool(
            servitorProvider: servitorProvider,
            commandProvider: commandProvider,
            navigator: self
        )
        self.resourcePanelSocket = ResourcePanelSocket(
            resourceProvider: resourceProvider,
            rootURL: rootURL
        )
        self.approvalSocket = ApprovalSocket(navigator: self)
        self.permissionSettingsSocket = PermissionSettingsSocket(
            permissionProvider: permissionProvider,
            navigator: self
        )

        Self.logger.info("[WindowBoard] initialized for project: \(projectName)")
    }

    public func makeView() -> some View {
        WindowBoardView(board: self)
    }

    // MARK: - Tile Access

    var servitorListView: some View {
        servitorListSocket.tile.makeView()
    }

    func chatView(for servitorID: UUID) -> some View {
        chatSocketPool.tile(for: servitorID).makeView()
    }

    // MARK: - TavernNavigator

    public func selectServitor(id: UUID) {
        Self.logger.info("[WindowBoard] selectServitor: \(id)")
        activeServitorID = id
        detailFacet = .chat(id)
        servitorListSocket.selectServitor(id: id)
    }

    public func spawnServitor() {
        Self.logger.info("[WindowBoard] spawnServitor")
        do {
            let newID = try servitorProvider.spawnServitor()
            servitorListSocket.tile.servitorsDidChange()
            selectServitor(id: newID)
        } catch {
            Self.logger.error("[WindowBoard] spawnServitor failed: \(error.localizedDescription)")
        }
    }

    public func closeServitor(id: UUID) {
        Self.logger.info("[WindowBoard] closeServitor: \(id)")
        do {
            try servitorProvider.closeServitor(id: id)
            chatSocketPool.removeTile(for: id)
            servitorListSocket.tile.servitorsDidChange()

            // If the closed servitor was active, go back to empty or pick another
            if activeServitorID == id {
                activeServitorID = nil
                detailFacet = .empty
            }
        } catch {
            Self.logger.error("[WindowBoard] closeServitor failed: \(error.localizedDescription)")
        }
    }

    public func updateServitorDescription(id: UUID, description: String?) {
        Self.logger.debug("[WindowBoard] updateDescription for \(id)")
        servitorProvider.updateDescription(id: id, description: description)
        servitorListSocket.tile.servitorsDidChange()
    }

    public func presentToolApproval(
        for servitorID: UUID,
        request: ToolApprovalRequest
    ) async -> ToolApprovalResponse {
        Self.logger.info("[WindowBoard] presentToolApproval for servitor: \(servitorID), tool: \(request.toolName)")
        activeModal = .toolApproval(servitorID, request)
        return await withCheckedContinuation { continuation in
            pendingApprovalContinuation = continuation
        }
    }

    public func presentPlanApproval(
        for servitorID: UUID,
        request: PlanApprovalRequest
    ) async -> PlanApprovalResponse {
        Self.logger.info("[WindowBoard] presentPlanApproval for servitor: \(servitorID)")
        activeModal = .planApproval(servitorID, request)
        return await withCheckedContinuation { continuation in
            pendingPlanContinuation = continuation
        }
    }

    public func respondToToolApproval(_ response: ToolApprovalResponse) {
        Self.logger.info("[WindowBoard] respondToToolApproval: approved=\(response.approved)")
        activeModal = nil
        pendingApprovalContinuation?.resume(returning: response)
        pendingApprovalContinuation = nil
    }

    public func respondToPlanApproval(_ response: PlanApprovalResponse) {
        Self.logger.info("[WindowBoard] respondToPlanApproval: approved=\(response.approved)")
        activeModal = nil
        pendingPlanContinuation?.resume(returning: response)
        pendingPlanContinuation = nil
    }

    public func dismissModal() {
        Self.logger.info("[WindowBoard] dismissModal")
        activeModal = nil
    }

    public func toggleSidePane() {
        switch sidePaneFacet {
        case .hidden:
            sidePaneFacet = .visible(.files)
        case .visible:
            sidePaneFacet = .hidden
        }
        Self.logger.info("[WindowBoard] toggleSidePane: \(String(describing: self.sidePaneFacet))")
    }

    public func selectSidePaneTab(_ tab: SidePaneTab) {
        sidePaneFacet = .visible(tab)
        Self.logger.debug("[WindowBoard] selectSidePaneTab: \(tab.rawValue)")
    }

    public func servitorActivityChanged(id: UUID, activity: ServitorActivity) {
        Self.logger.debug("[WindowBoard] activityChanged for \(id): \(String(describing: activity))")
        servitorListSocket.tile.servitorsDidChange()
    }

    public func presentPermissionSettings() {
        Self.logger.info("[WindowBoard] presentPermissionSettings")
        activeModal = .permissionSettings
    }
}
