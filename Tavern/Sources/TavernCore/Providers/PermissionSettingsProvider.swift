import Foundation
import TavernKit
import os.log

// MARK: - Provenance: REQ-OPM-001, REQ-OPM-002, REQ-OPM-003

@MainActor
public final class PermissionSettingsProvider: PermissionProvider {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "permissions")

    private let manager: PermissionManager

    public init(manager: PermissionManager) {
        self.manager = manager
    }

    public var mode: TavernKit.PermissionMode {
        get { manager.mode }
        set { manager.mode = newValue }
    }

    public func rules() -> [PermissionRuleInfo] {
        manager.rules.map { rule in
            PermissionRuleInfo(
                id: rule.id,
                toolPattern: rule.toolPattern,
                decision: rule.decision == .allow ? .allow : .deny,
                note: rule.note
            )
        }
    }

    public func addRule(pattern: String, decision: PermissionDecisionInfo) {
        switch decision {
        case .allow:
            manager.addAllowRule(toolPattern: pattern)
        case .deny:
            manager.addDenyRule(toolPattern: pattern)
        }
        Self.logger.info("[PermissionSettingsProvider] added rule: \(pattern) -> \(decision.rawValue)")
    }

    public func removeRule(id: UUID) {
        manager.removeRule(id: id)
    }

    public func removeAllRules() {
        manager.removeAllRules()
    }
}
