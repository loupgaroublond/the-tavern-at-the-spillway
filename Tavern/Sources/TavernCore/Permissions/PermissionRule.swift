import Foundation

/// A rule that defines whether a specific tool type is always allowed or always denied.
///
/// Rules are evaluated before prompting the user. If a matching rule exists,
/// the decision is made automatically.
public struct PermissionRule: Codable, Equatable, Identifiable, Sendable {

    /// Unique identifier for this rule
    public let id: UUID

    /// The tool name pattern this rule matches (e.g. "bash", "read", "edit")
    public let toolPattern: String

    /// Whether matching tools are allowed or denied
    public let decision: PermissionDecision

    /// When this rule was created
    public let createdAt: Date

    /// Optional human-readable note about why this rule exists
    public let note: String?

    public init(
        id: UUID = UUID(),
        toolPattern: String,
        decision: PermissionDecision,
        createdAt: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.toolPattern = toolPattern
        self.decision = decision
        self.createdAt = createdAt
        self.note = note
    }

    /// Check if this rule matches a given tool name
    /// - Parameter toolName: The name of the tool to check
    /// - Returns: true if the rule's pattern matches the tool name
    public func matches(toolName: String) -> Bool {
        // Exact match (case-insensitive)
        if toolPattern.lowercased() == toolName.lowercased() {
            return true
        }

        // Wildcard match: "bash*" matches "bash", "bash_run", etc.
        if toolPattern.hasSuffix("*") {
            let prefix = String(toolPattern.dropLast()).lowercased()
            return toolName.lowercased().hasPrefix(prefix)
        }

        return false
    }
}

/// The decision a permission rule encodes
public enum PermissionDecision: String, Codable, Sendable {
    /// Tool is allowed to execute
    case allow
    /// Tool is denied from executing
    case deny
}
