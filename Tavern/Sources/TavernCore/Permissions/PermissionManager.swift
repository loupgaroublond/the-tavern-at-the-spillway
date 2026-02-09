import Foundation
import os.log

/// Central permission logic: checks rules, evaluates mode, and coordinates tool approval.
///
/// PermissionManager sits between the SDK tool callbacks and the UI. When a tool
/// requests execution, PermissionManager decides:
/// 1. Auto-approve (bypass mode, matching allow rule, or edit tool in acceptEdits mode)
/// 2. Auto-deny (plan mode, don't-ask mode with no matching allow rule, or matching deny rule)
/// 3. Prompt the user (normal mode with no matching rule)
///
/// Thread-safe via serial DispatchQueue.
public final class PermissionManager: @unchecked Sendable {

    // MARK: - Properties

    private let store: PermissionStore

    /// Tool name patterns considered "edit" operations for acceptEdits mode
    private static let editToolPatterns: Set<String> = [
        "edit", "write", "notebookedit"
    ]

    // MARK: - Initialization

    /// Create a PermissionManager backed by the given store
    /// - Parameter store: The persistence layer for rules and mode
    public init(store: PermissionStore) {
        self.store = store
        TavernLogger.permissions.info("PermissionManager initialized, mode=\(store.mode.rawValue)")
    }

    // MARK: - Mode Access

    /// The active permission mode (delegates to store)
    public var mode: PermissionMode {
        get { store.mode }
        set { store.mode = newValue }
    }

    // MARK: - Rule Access

    /// All permission rules (delegates to store)
    public var rules: [PermissionRule] {
        store.rules
    }

    /// Add a new always-allow rule for a tool
    /// - Parameters:
    ///   - toolPattern: The tool name pattern to match
    ///   - note: Optional note about why this rule exists
    public func addAllowRule(toolPattern: String, note: String? = nil) {
        let rule = PermissionRule(toolPattern: toolPattern, decision: .allow, note: note)
        store.addRule(rule)
    }

    /// Add a new always-deny rule for a tool
    /// - Parameters:
    ///   - toolPattern: The tool name pattern to match
    ///   - note: Optional note about why this rule exists
    public func addDenyRule(toolPattern: String, note: String? = nil) {
        let rule = PermissionRule(toolPattern: toolPattern, decision: .deny, note: note)
        store.addRule(rule)
    }

    /// Remove a rule by ID (delegates to store)
    /// - Parameter id: The rule's unique identifier
    public func removeRule(id: UUID) {
        store.removeRule(id: id)
    }

    /// Remove all rules (delegates to store)
    public func removeAllRules() {
        store.removeAllRules()
    }

    // MARK: - Decision Logic

    /// Evaluate whether a tool should be approved, denied, or needs user input.
    ///
    /// - Parameter toolName: The name of the tool requesting execution
    /// - Returns: The auto-decision, or nil if the user must be prompted
    public func evaluateTool(_ toolName: String) -> PermissionDecision? {
        let currentMode = store.mode

        TavernLogger.permissions.debug("Evaluating tool '\(toolName)' in mode '\(currentMode.rawValue)'")

        switch currentMode {
        case .bypassPermissions:
            TavernLogger.permissions.info("Tool '\(toolName)' auto-approved (bypass mode)")
            return .allow

        case .plan:
            TavernLogger.permissions.info("Tool '\(toolName)' auto-denied (plan mode)")
            return .deny

        case .acceptEdits:
            // Check if this is an edit tool
            if Self.isEditTool(toolName) {
                TavernLogger.permissions.info("Tool '\(toolName)' auto-approved (acceptEdits mode, edit tool)")
                return .allow
            }
            // Fall through to rule checking for non-edit tools
            return evaluateAgainstRules(toolName: toolName, fallback: nil)

        case .dontAsk:
            // Only allow if there's an explicit allow rule; deny everything else
            return evaluateAgainstRules(toolName: toolName, fallback: .deny)

        case .normal:
            // Check rules; if no match, return nil to prompt user
            return evaluateAgainstRules(toolName: toolName, fallback: nil)
        }
    }

    /// Process a user's response to a tool approval request.
    /// If the user checked "always allow", creates a new allow rule.
    ///
    /// - Parameters:
    ///   - request: The original approval request
    ///   - response: The user's response
    public func processApprovalResponse(for request: ToolApprovalRequest, response: ToolApprovalResponse) {
        if response.alwaysAllow && response.approved {
            addAllowRule(
                toolPattern: request.toolName,
                note: "Auto-created from approval dialog"
            )
            TavernLogger.permissions.info("Created always-allow rule for '\(request.toolName)' from approval dialog")
        }

        let decision = response.approved ? "approved" : "denied"
        TavernLogger.permissions.info("Tool '\(request.toolName)' \(decision) by user (alwaysAllow=\(response.alwaysAllow))")
    }

    // MARK: - Private

    /// Check a tool against stored rules
    /// - Parameters:
    ///   - toolName: The tool to check
    ///   - fallback: If no rule matches, return this (nil means "prompt user")
    /// - Returns: The decision from a matching rule, or the fallback
    private func evaluateAgainstRules(toolName: String, fallback: PermissionDecision?) -> PermissionDecision? {
        if let rule = store.findMatchingRule(for: toolName) {
            TavernLogger.permissions.debug("Tool '\(toolName)' matched rule '\(rule.toolPattern)' -> \(rule.decision.rawValue)")
            return rule.decision
        }
        if let fallback = fallback {
            TavernLogger.permissions.debug("Tool '\(toolName)' no rule match, fallback -> \(fallback.rawValue)")
        } else {
            TavernLogger.permissions.debug("Tool '\(toolName)' no rule match, requires user prompt")
        }
        return fallback
    }

    /// Check if a tool name matches an edit operation
    /// - Parameter toolName: The tool name to check
    /// - Returns: true if the tool is considered an edit operation
    private static func isEditTool(_ toolName: String) -> Bool {
        let lower = toolName.lowercased()
        return editToolPatterns.contains(lower)
    }
}
