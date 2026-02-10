import Foundation
import ClodKit
import os.log

// MARK: - LiveMessenger

/// Production messenger that calls real Claude via ClodKit SDK.
/// Extracts response text from the ClaudeQuery stream, handling both
/// "result" and "assistant" message types.
///
/// When a `PermissionManager` is provided, tool execution is gated by
/// permission checks. Auto-decisions (allow/deny) are applied immediately.
/// When the manager returns nil (prompt user), the `approvalHandler` is
/// called to get the user's async decision.
public struct LiveMessenger: AgentMessenger {

    private let permissionManager: PermissionManager?
    private let approvalHandler: ToolApprovalHandler?
    private let agentName: String

    /// Create a LiveMessenger with optional permission enforcement.
    /// - Parameters:
    ///   - permissionManager: Permission manager for tool checks (nil disables checks)
    ///   - approvalHandler: Async callback for user prompting (required when manager is non-nil)
    ///   - agentName: Name of the agent using this messenger (for approval request context)
    public init(
        permissionManager: PermissionManager? = nil,
        approvalHandler: ToolApprovalHandler? = nil,
        agentName: String = ""
    ) {
        self.permissionManager = permissionManager
        self.approvalHandler = approvalHandler
        self.agentName = agentName
    }

    /// Build the canUseTool callback from the permission manager and approval handler.
    /// Returns nil if no permission manager is configured.
    private func buildCanUseToolCallback() -> CanUseToolCallback? {
        guard let manager = permissionManager else { return nil }

        let handler = approvalHandler
        let name = agentName

        return { toolName, input, context in
            TavernLogger.permissions.info("canUseTool called for '\(toolName)' (agent: \(name))")

            let decision = manager.evaluateTool(toolName)

            switch decision {
            case .allow:
                return .allowTool(toolUseID: context.toolUseID)

            case .deny:
                return .denyTool("Permission denied for tool '\(toolName)'", toolUseID: context.toolUseID)

            case nil:
                // User must decide — invoke the approval handler
                guard let handler else {
                    TavernLogger.permissions.error("No approval handler configured, denying tool '\(toolName)'")
                    return .denyTool("No approval handler available", toolUseID: context.toolUseID)
                }

                let request = ToolApprovalRequest(
                    toolName: toolName,
                    toolDescription: input.description,
                    agentName: name
                )

                let response = await handler(request)
                manager.processApprovalResponse(for: request, response: response)

                if response.approved {
                    return .allowTool(toolUseID: context.toolUseID)
                } else {
                    return .denyTool("User denied tool '\(toolName)'", toolUseID: context.toolUseID)
                }
            }
        }
    }

    public func query(prompt: String, options: QueryOptions) async throws -> (response: String, sessionId: String?) {
        var options = options
        options.canUseTool = buildCanUseToolCallback()

        let query = try await Clod.query(prompt: prompt, options: options)
        var responseText = ""
        var messageCount = 0

        for try await message in query {
            messageCount += 1
            switch message {
            case .regular(let sdkMessage):
                // Look for result message with the final response
                if sdkMessage.type == "result" {
                    if let content = sdkMessage.content?.stringValue {
                        responseText = content
                    }
                } else if sdkMessage.type == "assistant" {
                    // Fallback: extract content from assistant messages
                    if let content = sdkMessage.content?.stringValue, responseText.isEmpty {
                        responseText = content
                    }
                }
            case .controlRequest, .controlResponse, .controlCancelRequest, .keepAlive:
                break
            }
        }

        let sessionId = await query.sessionId
        return (response: responseText, sessionId: sessionId)
    }

    public func queryStreaming(prompt: String, options: QueryOptions) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        var opts = options
        opts.canUseTool = buildCanUseToolCallback()
        let options = opts

        // Shared cancellation state
        let cancelled = UnsafeSendableBox(false)
        // Hold query reference for interrupt support
        let queryBox = UnsafeSendableBox<ClaudeQuery?>(nil)

        let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            let task = Task {
                do {
                    let query = try await Clod.query(prompt: prompt, options: options)
                    queryBox.value = query

                    var lastText = ""

                    for try await message in query {
                        if cancelled.value {
                            try await query.interrupt()
                            continuation.finish()
                            return
                        }

                        switch message {
                        case .regular(let sdkMessage):
                            if sdkMessage.type == "assistant" {
                                if let content = sdkMessage.content?.stringValue, content.count > lastText.count {
                                    let delta = String(content.dropFirst(lastText.count))
                                    lastText = content
                                    continuation.yield(.textDelta(delta))
                                }
                            } else if sdkMessage.type == "result" {
                                // Result may contain the final complete text
                                if let content = sdkMessage.content?.stringValue, content.count > lastText.count {
                                    let delta = String(content.dropFirst(lastText.count))
                                    continuation.yield(.textDelta(delta))
                                }
                            }
                        case .controlRequest, .controlResponse, .controlCancelRequest, .keepAlive:
                            break
                        }
                    }

                    let sessionId = await query.sessionId
                    continuation.yield(.completed(sessionId: sessionId, usage: nil))
                    continuation.finish()
                } catch {
                    if cancelled.value {
                        continuation.finish()
                    } else {
                        continuation.yield(.error(error.localizedDescription))
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        let cancel: @Sendable () -> Void = {
            cancelled.value = true
            Task {
                try? await queryBox.value?.interrupt()
            }
        }

        return (stream: stream, cancel: cancel)
    }
}

/// Thread-unsafe mutable box marked @unchecked Sendable for use in
/// structured concurrency where access is logically sequential.
/// Used internally by LiveMessenger and MockMessenger streaming to share cancellation state.
final class UnsafeSendableBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
