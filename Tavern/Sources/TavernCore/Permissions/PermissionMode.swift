import Foundation

/// Permission modes that control how tool approval requests are handled.
///
/// Each mode defines a policy for whether tools require explicit user approval,
/// are auto-approved, or are auto-denied.
public enum PermissionMode: String, Codable, CaseIterable, Sendable {

    /// Default mode — tools require approval unless an always-allow rule matches
    case normal

    /// Accept edits — file editing tools are auto-approved, others still require approval
    case acceptEdits

    /// Plan mode — all tools are denied (agent can only plan, not execute)
    case plan

    /// Bypass permissions — all tools are auto-approved (YOLO mode)
    case bypassPermissions

    /// Don't ask mode — tools matching always-allow rules are approved,
    /// everything else is auto-denied without prompting the user
    case dontAsk

    /// Human-readable label for UI display
    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .acceptEdits: return "Accept Edits"
        case .plan: return "Plan Only"
        case .bypassPermissions: return "Bypass Permissions"
        case .dontAsk: return "Don't Ask"
        }
    }

    /// Description of what this mode does
    public var modeDescription: String {
        switch self {
        case .normal:
            return "Tools require approval unless an always-allow rule matches."
        case .acceptEdits:
            return "File editing tools are auto-approved. Other tools still require approval."
        case .plan:
            return "All tools are denied. The agent can only plan, not execute."
        case .bypassPermissions:
            return "All tools are auto-approved without asking."
        case .dontAsk:
            return "Allowed tools run automatically. Everything else is silently denied."
        }
    }
}
