import Foundation

/// Represents a tool that is requesting approval to execute.
///
/// When PermissionManager cannot auto-decide (no matching rule, mode is normal),
/// it creates a ToolApprovalRequest and surfaces it to the UI for user input.
public struct ToolApprovalRequest: Identifiable, Sendable {

    /// Unique identifier for this request
    public let id: UUID

    /// The name of the tool requesting approval
    public let toolName: String

    /// Description of what the tool wants to do
    public let toolDescription: String

    /// The agent that triggered the tool use
    public let agentName: String

    /// When the request was created
    public let requestedAt: Date

    public init(
        id: UUID = UUID(),
        toolName: String,
        toolDescription: String = "",
        agentName: String = "",
        requestedAt: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.toolDescription = toolDescription
        self.agentName = agentName
        self.requestedAt = requestedAt
    }
}

/// The user's response to a tool approval request
public struct ToolApprovalResponse: Sendable {

    /// Whether the tool is approved to execute
    public let approved: Bool

    /// Whether to create an always-allow rule for this tool type
    public let alwaysAllow: Bool

    public init(approved: Bool, alwaysAllow: Bool = false) {
        self.approved = approved
        self.alwaysAllow = alwaysAllow
    }
}
