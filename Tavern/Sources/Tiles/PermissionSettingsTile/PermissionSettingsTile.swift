import Foundation
import TavernKit
import SwiftUI
import os.log

// MARK: - Provenance: REQ-OPM-003

@Observable @MainActor
public final class PermissionSettingsTile {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "permissions")

    // MARK: - State

    var currentMode: PermissionMode

    var rules: [PermissionRuleInfo]
    var newRulePattern: String = ""
    var newRuleDecision: PermissionDecisionInfo = .allow

    // MARK: - Dependencies

    private var permissionProvider: any PermissionProvider
    let responder: PermissionSettingsResponder

    // MARK: - Initialization

    public init(permissionProvider: any PermissionProvider, responder: PermissionSettingsResponder) {
        self.permissionProvider = permissionProvider
        self.responder = responder
        self.currentMode = permissionProvider.mode
        self.rules = permissionProvider.rules()
        Self.logger.info("[PermissionSettingsTile] initialized - mode: \(permissionProvider.mode.rawValue), rules: \(permissionProvider.rules().count)")
    }

    public func makeView() -> some View {
        PermissionSettingsTileView(tile: self)
    }

    // MARK: - Actions

    /// Syncs the current mode to the provider. Called from the view's onChange.
    func syncModeToProvider() {
        let mode = self.currentMode
        Self.logger.info("[PermissionSettingsTile] mode changed: \(mode.rawValue)")
        permissionProvider.mode = mode
    }

    func addRule() {
        let pattern = newRulePattern.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return }

        let decision = self.newRuleDecision
        Self.logger.info("[PermissionSettingsTile] addRule: pattern=\(pattern), decision=\(decision.rawValue)")
        permissionProvider.addRule(pattern: pattern, decision: newRuleDecision)
        rules = permissionProvider.rules()
        newRulePattern = ""
    }

    func removeRule(id: UUID) {
        Self.logger.info("[PermissionSettingsTile] removeRule: \(id)")
        permissionProvider.removeRule(id: id)
        rules = permissionProvider.rules()
    }

    func removeAllRules() {
        Self.logger.info("[PermissionSettingsTile] removeAllRules")
        permissionProvider.removeAllRules()
        rules = permissionProvider.rules()
    }
}
