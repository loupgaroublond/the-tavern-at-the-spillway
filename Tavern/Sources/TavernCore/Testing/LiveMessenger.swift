import Foundation
import ClodKit
import os.log

// MARK: - Provenance: REQ-QA-005

// MARK: - LiveMessenger

/// Production messenger that calls real Claude via ClodKit SDK.
/// Parses stream_event messages with includePartialMessages: true
/// for real-time content block streaming (thinking, tool use, text).
///
/// When a `PermissionManager` is provided, tool execution is gated by
/// permission checks. Auto-decisions (allow/deny) are applied immediately.
/// When the manager returns nil (prompt user), the `approvalHandler` is
/// called to get the user's async decision.
public struct LiveMessenger: ServitorMessenger {

    private let permissionManager: PermissionManager?
    private let approvalHandler: ToolApprovalHandler?
    private let planApprovalHandler: PlanApprovalHandler?
    private let agentName: String

    /// Create a LiveMessenger with optional permission enforcement.
    /// - Parameters:
    ///   - permissionManager: Permission manager for tool checks (nil disables checks)
    ///   - approvalHandler: Async callback for user prompting (required when manager is non-nil)
    ///   - planApprovalHandler: Async callback for ExitPlanMode requests
    ///   - agentName: Name of the agent using this messenger (for approval request context)
    public init(
        permissionManager: PermissionManager? = nil,
        approvalHandler: ToolApprovalHandler? = nil,
        planApprovalHandler: PlanApprovalHandler? = nil,
        agentName: String = ""
    ) {
        self.permissionManager = permissionManager
        self.approvalHandler = approvalHandler
        self.planApprovalHandler = planApprovalHandler
        self.agentName = agentName
    }

    /// Build the canUseTool callback from the permission manager and approval handler.
    /// Returns nil if no permission manager is configured.
    private func buildCanUseToolCallback() -> CanUseToolCallback? {
        // Need a callback if we have a permission manager OR a plan approval handler
        guard permissionManager != nil || planApprovalHandler != nil else { return nil }

        let manager = permissionManager
        let handler = approvalHandler
        let planHandler = planApprovalHandler
        let name = agentName

        return { toolName, input, context in
            TavernLogger.permissions.info("canUseTool called for '\(toolName)' (agent: \(name))")

            // Intercept ExitPlanMode — route to plan approval handler
            if toolName == "ExitPlanMode" {
                guard let planHandler else {
                    TavernLogger.permissions.info("ExitPlanMode with no plan handler, allowing (agent: \(name))")
                    return .allowTool(toolUseID: context.toolUseID)
                }

                // Extract allowed prompts from the input
                var allowedPrompts: [(tool: String, prompt: String)] = []
                if let promptsValue = input["allowedPrompts"],
                   case .array(let prompts) = promptsValue {
                    for prompt in prompts {
                        if case .object(let dict) = prompt,
                           case .string(let tool) = dict["tool"],
                           case .string(let promptText) = dict["prompt"] {
                            allowedPrompts.append((tool: tool, prompt: promptText))
                        }
                    }
                }

                let request = PlanApprovalRequest(
                    agentName: name,
                    allowedPrompts: allowedPrompts
                )

                let response = await planHandler(request)
                if response.approved {
                    TavernLogger.permissions.info("Plan approved for agent: \(name)")
                    return .allowTool(toolUseID: context.toolUseID)
                } else {
                    let feedback = response.feedback ?? "Plan rejected by user"
                    TavernLogger.permissions.info("Plan rejected for agent: \(name) — \(feedback)")
                    return .denyTool(feedback, toolUseID: context.toolUseID)
                }
            }

            // Standard permission evaluation
            guard let manager else {
                return .allowTool(toolUseID: context.toolUseID)
            }

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
        // Prevent nested-session detection when Tavern is launched from Claude Code
        options.environment["CLAUDECODE"] = ""

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
        // Prevent nested-session detection when Tavern is launched from Claude Code
        opts.environment["CLAUDECODE"] = ""
        // Enable partial messages for real-time content block streaming
        opts.includePartialMessages = true
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

                    // Track active content blocks by index for start/delta/stop correlation
                    var activeBlocks: [Int: ContentBlockState] = [:]
                    var seenToolUseIds: Set<String> = []

                    for try await message in query {
                        if cancelled.value {
                            try await query.interrupt()
                            continuation.finish()
                            return
                        }

                        guard case .regular(let sdkMessage) = message else { continue }

                        switch sdkMessage.type {

                        // ── stream_event: content blocks ──
                        case "stream_event":
                            guard let event = sdkMessage.rawJSON["event"]?.objectValue else { continue }
                            guard let eventType = event["type"]?.stringValue else { continue }
                            let index = event["index"]?.intValue ?? 0

                            switch eventType {

                            case "content_block_start":
                                guard let block = event["content_block"]?.objectValue,
                                      let blockType = block["type"]?.stringValue else { continue }

                                var state = ContentBlockState(blockType: blockType)

                                if blockType == "tool_use" {
                                    let id = block["id"]?.stringValue ?? ""
                                    let name = block["name"]?.stringValue ?? ""
                                    state.toolUseId = id
                                    state.toolName = name
                                    if !seenToolUseIds.contains(id) {
                                        seenToolUseIds.insert(id)
                                        continuation.yield(.toolUseStarted(ToolUseInfo(
                                            toolUseId: id, toolName: name
                                        )))
                                    }
                                }

                                activeBlocks[index] = state

                            case "content_block_delta":
                                guard let delta = event["delta"]?.objectValue,
                                      let deltaType = delta["type"]?.stringValue else { continue }

                                switch deltaType {
                                case "text_delta":
                                    if let text = delta["text"]?.stringValue {
                                        continuation.yield(.textDelta(text))
                                    }
                                case "thinking_delta":
                                    if let thinking = delta["thinking"]?.stringValue {
                                        continuation.yield(.thinkingDelta(thinking))
                                    }
                                case "input_json_delta":
                                    if let json = delta["partial_json"]?.stringValue {
                                        activeBlocks[index]?.accumulatedInput += json
                                        if let id = activeBlocks[index]?.toolUseId {
                                            continuation.yield(.toolInputDelta(toolUseId: id, json: json))
                                        }
                                    }
                                default:
                                    break
                                }

                            case "content_block_stop":
                                if activeBlocks.removeValue(forKey: index) != nil {
                                    continuation.yield(.blockFinished(index: index))
                                }

                            default:
                                break
                            }

                        // ── user message: tool results ──
                        case "user":
                            if let resultValue = sdkMessage.toolUseResult {
                                if let resultObj = resultValue.objectValue {
                                    let toolUseId = resultObj["tool_use_id"]?.stringValue ?? ""
                                    let content = Self.extractToolResultContent(resultObj["content"])
                                    let isError = resultObj["is_error"]?.boolValue ?? false
                                    continuation.yield(.toolResult(ToolResultInfo(
                                        toolUseId: toolUseId, content: content, isError: isError
                                    )))
                                }
                            } else if let msg = sdkMessage.rawJSON["message"]?.objectValue,
                                      let contentArray = msg["content"]?.arrayValue {
                                for block in contentArray {
                                    guard let obj = block.objectValue,
                                          obj["type"]?.stringValue == "tool_result" else { continue }
                                    let toolUseId = obj["tool_use_id"]?.stringValue ?? ""
                                    let content = Self.extractToolResultContent(obj["content"])
                                    let isError = obj["is_error"]?.boolValue ?? false
                                    continuation.yield(.toolResult(ToolResultInfo(
                                        toolUseId: toolUseId, content: content, isError: isError
                                    )))
                                }
                            }

                        // ── result message: completion ──
                        case "result":
                            let info = Self.parseCompletionInfo(from: sdkMessage)
                            continuation.yield(.completed(info))

                        // ── system messages ──
                        case "system":
                            let subtype = sdkMessage.rawJSON["subtype"]?.stringValue
                            if subtype == "status",
                               let status = sdkMessage.rawJSON["status"]?.stringValue {
                                continuation.yield(.systemStatus(status))
                            }

                        // ── tool progress ──
                        case "tool_progress":
                            let toolUseId = sdkMessage.rawJSON["tool_use_id"]?.stringValue ?? ""
                            let toolName = sdkMessage.rawJSON["tool_name"]?.stringValue ?? ""
                            let elapsed = Self.numericDouble(sdkMessage.rawJSON["elapsed_time_seconds"]) ?? 0
                            continuation.yield(.toolProgress(ToolProgressInfo(
                                toolUseId: toolUseId, toolName: toolName, elapsedSeconds: elapsed
                            )))

                        // ── prompt suggestion ──
                        case "prompt_suggestion":
                            if let suggestion = sdkMessage.rawJSON["suggestion"]?.stringValue {
                                continuation.yield(.promptSuggestion(suggestion))
                            }

                        // ── rate limit ──
                        case "rate_limit":
                            if let info = sdkMessage.rawJSON["rate_limit_info"]?.objectValue {
                                let status = info["status"]?.stringValue ?? "unknown"
                                let utilization = Self.numericDouble(info["utilization"])
                                let resetsAt: Date? = Self.numericDouble(info["resetsAt"]).map {
                                    Date(timeIntervalSince1970: $0)
                                }
                                continuation.yield(.rateLimitWarning(RateLimitInfo(
                                    status: status, utilization: utilization, resetsAt: resetsAt
                                )))
                            }

                        // ── assistant (cumulative, fallback if partial messages somehow off) ──
                        case "assistant":
                            break

                        default:
                            break
                        }
                    }

                    // The result message handler above should have emitted .completed.
                    // Ensure the stream finishes cleanly.
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

    // MARK: - Private Helpers

    /// State tracking for an active content block during streaming
    private struct ContentBlockState {
        let blockType: String       // "text", "thinking", "tool_use"
        var toolUseId: String?      // for tool_use blocks
        var toolName: String?       // for tool_use blocks
        var accumulatedInput: String = ""  // for tool_use JSON input
    }

    /// Extract numeric double from JSONValue that might be .int or .double
    /// ClodKit's JSONValue has no doubleValue accessor; .int and .double are separate cases
    private static func numericDouble(_ value: JSONValue?) -> Double? {
        guard let value else { return nil }
        switch value {
        case .double(let d): return d
        case .int(let i): return Double(i)
        default: return nil
        }
    }

    /// Extract tool result content — can be a string or array of content blocks
    private static func extractToolResultContent(_ value: JSONValue?) -> String {
        guard let value else { return "" }
        switch value {
        case .string(let s):
            return s
        case .array(let blocks):
            return blocks.compactMap { block -> String? in
                guard let obj = block.objectValue,
                      let text = obj["text"]?.stringValue else { return nil }
                return text
            }.joined(separator: "\n")
        default:
            return ""
        }
    }

    /// Parse a result SDKMessage into CompletionInfo
    private static func parseCompletionInfo(from msg: SDKMessage) -> CompletionInfo {
        let json = msg.rawJSON
        let usageObj = json["usage"]?.objectValue
        let usage: SessionUsage? = usageObj.map { u in
            SessionUsage(
                inputTokens: u["input_tokens"]?.intValue ?? 0,
                outputTokens: u["output_tokens"]?.intValue ?? 0,
                cacheReadInputTokens: u["cache_read_input_tokens"]?.intValue ?? 0,
                cacheCreationInputTokens: u["cache_creation_input_tokens"]?.intValue ?? 0,
                costUsd: numericDouble(u["cost_usd"]) ?? 0
            )
        }
        return CompletionInfo(
            sessionId: json["session_id"]?.stringValue,
            usage: usage,
            costUsd: numericDouble(json["total_cost_usd"]),
            totalCostUsd: numericDouble(json["total_cost_usd"]),
            durationMs: json["duration_ms"]?.intValue,
            stopReason: json["stop_reason"]?.stringValue,
            numTurns: json["num_turns"]?.intValue
        )
    }
}

/// Thread-unsafe mutable box marked @unchecked Sendable for use in
/// structured concurrency where access is logically sequential.
/// Used internally by LiveMessenger and MockMessenger streaming to share cancellation state.
final class UnsafeSendableBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
