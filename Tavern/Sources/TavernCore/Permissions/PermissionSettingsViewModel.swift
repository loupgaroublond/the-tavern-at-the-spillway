import Foundation
import os.log

/// ViewModel for the permission settings UI.
///
/// Manages the current mode, rules list, and new-rule input state.
/// All UX logic lives here; the view is dumb (layout + bindings only).
@MainActor
public final class PermissionSettingsViewModel: ObservableObject {

    // MARK: - Published State

    /// The active permission mode
    @Published public var currentMode: PermissionMode {
        didSet {
            if currentMode != oldValue {
                manager.mode = currentMode
                TavernLogger.permissions.info("[PermissionSettingsVM] mode changed: \(oldValue.rawValue) -> \(self.currentMode.rawValue)")
            }
        }
    }

    /// All permission rules (refreshed from store)
    @Published public private(set) var rules: [PermissionRule]

    /// Text field for new rule pattern
    @Published public var newRulePattern: String = ""

    /// Decision picker for new rule
    @Published public var newRuleDecision: PermissionDecision = .allow

    // MARK: - Dependencies

    private let manager: PermissionManager

    // MARK: - Initialization

    /// Create a PermissionSettingsViewModel backed by the given manager
    /// - Parameter manager: The permission manager to delegate to
    public init(manager: PermissionManager) {
        self.manager = manager
        self.currentMode = manager.mode
        self.rules = manager.rules
        TavernLogger.permissions.info("[PermissionSettingsVM] initialized, mode=\(manager.mode.rawValue), rules=\(manager.rules.count)")
    }

    // MARK: - Actions

    /// Add a new rule from the current input fields
    public func addRule() {
        let pattern = newRulePattern.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return }

        let decision = newRuleDecision
        switch decision {
        case .allow:
            manager.addAllowRule(toolPattern: pattern)
        case .deny:
            manager.addDenyRule(toolPattern: pattern)
        }

        // Refresh and clear input
        rules = manager.rules
        newRulePattern = ""
        TavernLogger.permissions.info("[PermissionSettingsVM] added rule: \(pattern) -> \(decision.rawValue)")
    }

    /// Remove a rule by ID
    /// - Parameter id: The rule's unique identifier
    public func removeRule(id: UUID) {
        manager.removeRule(id: id)
        rules = manager.rules
        TavernLogger.permissions.info("[PermissionSettingsVM] removed rule: \(id)")
    }

    /// Remove all rules
    public func removeAllRules() {
        manager.removeAllRules()
        rules = manager.rules
        TavernLogger.permissions.info("[PermissionSettingsVM] removed all rules")
    }

    /// Refresh rules from the store (call after external changes)
    public func refresh() {
        currentMode = manager.mode
        rules = manager.rules
    }
}
