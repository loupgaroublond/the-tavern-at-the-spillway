import Foundation

// MARK: - Tool Approval Handler

/// Async callback invoked when PermissionManager cannot auto-decide (returns nil)
/// and the user must be prompted. The handler should present ToolApprovalView,
/// wait for the user's decision, and return the response.
///
/// Called from LiveMessenger's canUseTool closure. The closure suspends until
/// the user approves or denies the tool.
public typealias ToolApprovalHandler = @Sendable (ToolApprovalRequest) async -> ToolApprovalResponse

// MARK: - Tool Approval Request

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

// MARK: - Plan Approval

/// Async callback invoked when an agent calls ExitPlanMode.
/// The handler presents the plan for user review and returns the decision.
public typealias PlanApprovalHandler = @Sendable (PlanApprovalRequest) async -> PlanApprovalResponse

/// Represents a plan submitted by an agent for user review.
/// Created when an agent in plan mode calls ExitPlanMode.
public struct PlanApprovalRequest: Identifiable, Sendable {

    /// Unique identifier for this request
    public let id: UUID

    /// The agent that submitted the plan
    public let agentName: String

    /// Prompts the agent requested to be allowed (bash commands, etc.)
    public let allowedPrompts: [(tool: String, prompt: String)]

    /// When the request was created
    public let requestedAt: Date

    public init(
        id: UUID = UUID(),
        agentName: String,
        allowedPrompts: [(tool: String, prompt: String)] = [],
        requestedAt: Date = Date()
    ) {
        self.id = id
        self.agentName = agentName
        self.allowedPrompts = allowedPrompts
        self.requestedAt = requestedAt
    }
}

/// The user's response to a plan approval request
public struct PlanApprovalResponse: Sendable {

    /// Whether the plan is approved
    public let approved: Bool

    /// Feedback if the plan was rejected
    public let feedback: String?

    public init(approved: Bool, feedback: String? = nil) {
        self.approved = approved
        self.feedback = feedback
    }
}
