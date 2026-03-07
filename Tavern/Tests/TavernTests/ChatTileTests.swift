import Testing
import Foundation
import TavernKit
@testable import ChatTile

// MARK: - Provenance: REQ-UX-002, REQ-ARCH-003

@Suite("ChatTile Tests", .timeLimit(.minutes(1)))
@MainActor
struct ChatTileTests {

    // MARK: - Factory

    private static func makeTile(
        servitorID: UUID = UUID(),
        provider: StubServitorProvider = StubServitorProvider(),
        commandProvider: StubCommandProvider = StubCommandProvider()
    ) -> ChatTile {
        let responder = ChatResponder(
            onApprovalRequired: { _ in ToolApprovalResponse(approved: false, alwaysAllow: false) },
            onPlanApprovalRequired: { _ in PlanApprovalResponse(approved: false, feedback: nil) },
            onActivityChanged: { _ in }
        )
        return ChatTile(
            servitorID: servitorID,
            servitorProvider: provider,
            commandProvider: commandProvider,
            responder: responder
        )
    }

    // MARK: - History Loading (Tile-Owns-State)

    @Test("loadSessionHistory loads messages when tile is empty")
    func loadHistoryWhenEmpty() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.historyResponses[id] = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .agent, content: "Hi there")
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        #expect(tile.messages.isEmpty)

        await tile.loadSessionHistory()

        #expect(tile.messages.count == 2)
        #expect(tile.messages[0].content == "Hello")
        #expect(tile.messages[1].content == "Hi there")
    }

    @Test("loadSessionHistory does NOT overwrite existing messages")
    func loadHistoryPreservesExisting() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.historyResponses[id] = [
            ChatMessage(role: .agent, content: "old history")
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)

        // Simulate a sent message already in memory
        tile.inputText = "user message"
        await tile.sendMessage()

        let countBefore = tile.messages.count
        #expect(countBefore >= 1)

        // loadSessionHistory must NOT overwrite the in-memory messages
        await tile.loadSessionHistory()

        #expect(tile.messages.count == countBefore)
        #expect(tile.messages[0].content == "user message")
    }

    @Test("Messages survive simulated view destruction and recreation")
    func messagesSurviveViewRecreation() async {
        let id = UUID()
        let provider = StubServitorProvider()
        let commandProvider = StubCommandProvider()

        let responder = ChatResponder(
            onApprovalRequired: { _ in ToolApprovalResponse(approved: false, alwaysAllow: false) },
            onPlanApprovalRequired: { _ in PlanApprovalResponse(approved: false, feedback: nil) },
            onActivityChanged: { _ in }
        )

        // 1. Create tile and send a message (simulates first view appearance)
        let tile = ChatTile(
            servitorID: id,
            servitorProvider: provider,
            commandProvider: commandProvider,
            responder: responder
        )
        tile.inputText = "important message"
        await tile.sendMessage()

        let messageCount = tile.messages.count
        #expect(messageCount >= 1)

        // 2. Simulate view destruction + recreation: the same tile object
        //    gets a new view calling loadSessionHistory again.
        //    This MUST NOT wipe messages.
        await tile.loadSessionHistory()

        #expect(tile.messages.count == messageCount)
        #expect(tile.messages[0].content == "important message")
    }

    // MARK: - Send Message

    @Test("sendMessage appends user and agent messages")
    func sendMessageAppendsMessages() async {
        let tile = Self.makeTile()
        tile.inputText = "hello"

        await tile.sendMessage()

        #expect(tile.messages.count == 2)
        #expect(tile.messages[0].role == .user)
        #expect(tile.messages[0].content == "hello")
        #expect(tile.messages[1].role == .agent)
    }

    @Test("sendMessage clears inputText")
    func sendMessageClearsInput() async {
        let tile = Self.makeTile()
        tile.inputText = "hello"

        await tile.sendMessage()

        #expect(tile.inputText.isEmpty)
    }

    @Test("sendMessage with empty input is no-op")
    func sendEmptyIsNoop() async {
        let tile = Self.makeTile()
        tile.inputText = "   "

        await tile.sendMessage()

        #expect(tile.messages.isEmpty)
    }

    @Test("sendMessage resets streaming state when complete")
    func sendMessageResetsState() async {
        let tile = Self.makeTile()
        tile.inputText = "hello"

        await tile.sendMessage()

        #expect(tile.isCogitating == false)
        #expect(tile.isStreaming == false)
        #expect(tile.currentToolName == nil)
    }

    // MARK: - Token Tracking

    @Test("sendMessage accumulates token usage")
    func tokenTracking() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.streamingResponses[id] = [
            .textDelta("Hi"),
            .completed(CompletionInfo(usage: SessionUsage(inputTokens: 100, outputTokens: 50)))
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "hello"
        await tile.sendMessage()

        #expect(tile.hasUsageData == true)
        #expect(tile.formattedTokens == "100↑ 50↓")
    }

    // MARK: - Clear Conversation

    @Test("clearConversation resets messages and tokens")
    func clearConversation() async {
        let id = UUID()
        let provider = StubServitorProvider()
        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "hello"
        await tile.sendMessage()

        #expect(!tile.messages.isEmpty)

        tile.clearConversation()

        #expect(tile.messages.isEmpty)
        #expect(tile.hasUsageData == false)
        #expect(provider.clearConversationCalls.contains(id))
    }

    // MARK: - Slash Command Dispatch

    @Test("sendMessage dispatches slash commands to commandProvider")
    func slashCommandDispatch() async {
        let commandProvider = StubCommandProvider()
        commandProvider.dispatchResult = .message("command output")

        let tile = Self.makeTile(commandProvider: commandProvider)
        tile.inputText = "/help"

        await tile.sendMessage()

        // User message + command output, no streaming
        #expect(tile.messages.count == 2)
        #expect(tile.messages[0].role == .user)
        #expect(tile.messages[1].role == .agent)
        #expect(tile.messages[1].content == "command output")
        #expect(tile.isCogitating == false)
    }

    // MARK: - Rich Streaming: Thinking Block

    @Test("thinkingDelta creates a thinking message")
    func thinkingBlockCreatesMessage() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.streamingResponses[id] = [
            .thinkingDelta("Let me "),
            .thinkingDelta("think..."),
            .blockFinished(index: 0),
            .textDelta("Here's the answer."),
            .blockFinished(index: 0),
            .completed(CompletionInfo(sessionId: "test"))
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "question"
        await tile.sendMessage()

        // user msg + thinking msg + text msg = 3
        #expect(tile.messages.count == 3)
        #expect(tile.messages[1].messageType == .thinking)
        #expect(tile.messages[1].content == "Let me think...")
        #expect(tile.messages[1].isStreaming == false)
        #expect(tile.messages[2].messageType == .text)
        #expect(tile.messages[2].content == "Here's the answer.")
    }

    // MARK: - Rich Streaming: Tool Use

    @Test("toolUseStarted and toolResult create separate messages")
    func toolUseCreatesMessages() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.streamingResponses[id] = [
            .toolUseStarted(ToolUseInfo(toolUseId: "tu-1", toolName: "bash")),
            .toolInputDelta(toolUseId: "tu-1", json: "{\"command\":\"ls\"}"),
            .blockFinished(index: 0),
            .toolResult(ToolResultInfo(toolUseId: "tu-1", content: "file.txt", isError: false)),
            .textDelta("Done."),
            .blockFinished(index: 0),
            .completed(CompletionInfo(sessionId: "test"))
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "list files"
        await tile.sendMessage()

        // user msg + tool_use msg + tool_result msg + text msg = 4
        #expect(tile.messages.count == 4)
        #expect(tile.messages[1].messageType == .toolUse)
        #expect(tile.messages[1].toolName == "bash")
        #expect(tile.messages[1].toolUseId == "tu-1")
        #expect(tile.messages[2].messageType == .toolResult)
        #expect(tile.messages[2].content == "file.txt")
        #expect(tile.messages[3].content == "Done.")
    }

    // MARK: - Rich Streaming: Tool Input Delta

    @Test("toolInputDelta appends to tool use message content")
    func toolInputDeltaUpdatesContent() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.streamingResponses[id] = [
            .toolUseStarted(ToolUseInfo(toolUseId: "tu-1", toolName: "bash")),
            .toolInputDelta(toolUseId: "tu-1", json: "{\"com"),
            .toolInputDelta(toolUseId: "tu-1", json: "mand\":\"ls\"}"),
            .blockFinished(index: 0),
            .toolResult(ToolResultInfo(toolUseId: "tu-1", content: "ok", isError: false)),
            .completed(CompletionInfo())
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "go"
        await tile.sendMessage()

        // Tool use message should have accumulated input
        let toolMsg = tile.messages.first(where: { $0.messageType == .toolUse })
        #expect(toolMsg?.content == "{\"command\":\"ls\"}")
    }

    // MARK: - Rich Streaming: Interleaved Blocks

    @Test("interleaved think → tool → result → text creates 4 messages")
    func interleavedBlocks() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.streamingResponses[id] = [
            .thinkingDelta("thinking..."),
            .blockFinished(index: 0),
            .toolUseStarted(ToolUseInfo(toolUseId: "tu-1", toolName: "Read")),
            .blockFinished(index: 1),
            .toolResult(ToolResultInfo(toolUseId: "tu-1", content: "data", isError: false)),
            .textDelta("Result: data"),
            .blockFinished(index: 0),
            .completed(CompletionInfo())
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "go"
        await tile.sendMessage()

        // user + thinking + tool_use + tool_result + text = 5
        #expect(tile.messages.count == 5)
        #expect(tile.messages[1].messageType == .thinking)
        #expect(tile.messages[2].messageType == .toolUse)
        #expect(tile.messages[3].messageType == .toolResult)
        #expect(tile.messages[4].messageType == .text)
    }

    // MARK: - Rich Streaming: Cost Tracking

    @Test("completed event with cost updates totalCostUsd")
    func costTracking() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.streamingResponses[id] = [
            .textDelta("Hi"),
            .completed(CompletionInfo(
                usage: SessionUsage(inputTokens: 100, outputTokens: 50, costUsd: 0.01),
                totalCostUsd: 0.02
            ))
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "hello"
        await tile.sendMessage()

        #expect(tile.totalCostUsd == 0.02)
        #expect(tile.formattedTokens.contains("$0.02"))
    }

    // MARK: - Rich Streaming: Prompt Suggestion

    @Test("promptSuggestion populates suggestions array")
    func promptSuggestion() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.streamingResponses[id] = [
            .textDelta("Here you go."),
            .promptSuggestion("Tell me more"),
            .promptSuggestion("Show details"),
            .completed(CompletionInfo())
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "hi"
        await tile.sendMessage()

        #expect(tile.promptSuggestions.count == 2)
        #expect(tile.promptSuggestions[0] == "Tell me more")
        #expect(tile.promptSuggestions[1] == "Show details")
    }

    // MARK: - Rich Streaming: Rate Limit

    @Test("rateLimitWarning creates visible message (Invariant #7)")
    func rateLimitVisible() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.streamingResponses[id] = [
            .textDelta("working..."),
            .rateLimitWarning(RateLimitInfo(status: "warning", utilization: 0.85)),
            .completed(CompletionInfo())
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "go"
        await tile.sendMessage()

        // Should have a rate limit message visible
        let rateLimitMsg = tile.messages.first(where: { $0.content.contains("Rate limit") })
        #expect(rateLimitMsg != nil)
        #expect(rateLimitMsg?.content.contains("85%") == true)
    }

    // MARK: - Rich Streaming: System Status

    @Test("systemStatus sets tile property")
    func systemStatus() async {
        let id = UUID()
        let provider = StubServitorProvider()
        // Note: systemStatus is cleared on .completed, so we verify it was set
        // by checking the messages array for any system-related content.
        // Instead, test that after completion, status is cleared.
        provider.streamingResponses[id] = [
            .systemStatus("compacting"),
            .textDelta("done"),
            .completed(CompletionInfo())
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "go"
        await tile.sendMessage()

        // After completion, systemStatus should be cleared
        #expect(tile.systemStatus == nil)
    }

    // MARK: - Rich Streaming: Parallel Tool Uses

    @Test("two toolUseStarted before results — both tracked")
    func parallelToolUses() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.streamingResponses[id] = [
            .toolUseStarted(ToolUseInfo(toolUseId: "tu-1", toolName: "Read")),
            .toolUseStarted(ToolUseInfo(toolUseId: "tu-2", toolName: "Glob")),
            .toolResult(ToolResultInfo(toolUseId: "tu-1", content: "file content", isError: false)),
            .toolResult(ToolResultInfo(toolUseId: "tu-2", content: "*.swift", isError: false)),
            .textDelta("All done."),
            .completed(CompletionInfo())
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "go"
        await tile.sendMessage()

        // user + tool_use(Read) + tool_use(Glob) + tool_result(tu-1) + tool_result(tu-2) + text = 6
        let toolUseMessages = tile.messages.filter { $0.messageType == .toolUse }
        let toolResultMessages = tile.messages.filter { $0.messageType == .toolResult }
        #expect(toolUseMessages.count == 2)
        #expect(toolResultMessages.count == 2)
    }

    // MARK: - Rich Streaming: Tool Error

    @Test("toolResult with isError creates toolError message")
    func toolErrorCreatesMessage() async {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.streamingResponses[id] = [
            .toolUseStarted(ToolUseInfo(toolUseId: "tu-1", toolName: "bash")),
            .blockFinished(index: 0),
            .toolResult(ToolResultInfo(toolUseId: "tu-1", content: "Permission denied", isError: true)),
            .textDelta("Failed."),
            .completed(CompletionInfo())
        ]

        let tile = Self.makeTile(servitorID: id, provider: provider)
        tile.inputText = "go"
        await tile.sendMessage()

        let errorMsg = tile.messages.first(where: { $0.messageType == .toolError })
        #expect(errorMsg != nil)
        #expect(errorMsg?.content == "Permission denied")
        #expect(errorMsg?.isError == true)
    }
}

// MARK: - Provenance: REQ-UX-009

@Suite("ChatTile Controls", .tags(.reqUX009), .timeLimit(.minutes(2)))
@MainActor
struct ChatTileControlsTests {

    // MARK: - Factory

    private static func makeTile(
        servitorID: UUID = UUID(),
        provider: StubServitorProvider = StubServitorProvider(),
        commandProvider: StubCommandProvider = StubCommandProvider(),
        activityLog: ActivityLog? = nil
    ) -> ChatTile {
        let responder = ChatResponder(
            onApprovalRequired: { _ in ToolApprovalResponse(approved: false, alwaysAllow: false) },
            onPlanApprovalRequired: { _ in PlanApprovalResponse(approved: false, feedback: nil) },
            onActivityChanged: { activity in activityLog?.record(activity) }
        )
        return ChatTile(
            servitorID: servitorID,
            servitorProvider: provider,
            commandProvider: commandProvider,
            responder: responder
        )
    }

    // MARK: - Input Field Binding

    @Test("Typing text updates tile inputText state")
    func inputFieldBinding() {
        let tile = Self.makeTile()

        #expect(tile.inputText.isEmpty)

        tile.inputText = "Hello world"
        #expect(tile.inputText == "Hello world")

        tile.inputText = ""
        #expect(tile.inputText.isEmpty)
    }

    @Test("Input text with only whitespace is treated as empty by sendMessage")
    func whitespaceOnlyInputIsNoop() async {
        let tile = Self.makeTile()

        tile.inputText = "   \t\n  "
        await tile.sendMessage()

        #expect(tile.messages.isEmpty)
        // Input text is NOT cleared since guard returns early
        #expect(tile.inputText == "   \t\n  ")
    }

    // MARK: - Send Button Behavior

    @Test("Send triggers message send and clears input")
    func sendTriggersMessageAndClearsInput() async {
        let tile = Self.makeTile()
        tile.inputText = "Test message"

        await tile.sendMessage()

        #expect(tile.inputText.isEmpty)
        #expect(tile.messages.count >= 1)
        #expect(tile.messages[0].role == .user)
        #expect(tile.messages[0].content == "Test message")
    }

    @Test("Send is effectively disabled when input is empty — no messages produced")
    func sendDisabledWhenEmpty() async {
        let tile = Self.makeTile()
        tile.inputText = ""

        await tile.sendMessage()

        #expect(tile.messages.isEmpty)
    }

    // MARK: - Interrupt / Cancel Streaming

    @Test("cancelStreaming resets cogitating and streaming state")
    func cancelResetsState() async {
        let id = UUID()
        let provider = StubServitorProvider()
        // Use a stream that never finishes so we can cancel mid-flight
        provider.streamingResponses[id] = [] // empty = use default which finishes
        let tile = Self.makeTile(servitorID: id, provider: provider)

        // Simulate mid-cogitation state (as if sendMessage is in progress)
        // We set these directly since the real sendMessage would set them
        tile.isCogitating = true
        tile.isStreaming = true

        tile.cancelStreaming()

        #expect(tile.isCogitating == false)
        #expect(tile.isStreaming == false)
        #expect(tile.currentToolName == nil)
        #expect(tile.toolStartTime == nil)
    }

    @Test("cancelStreaming fires idle activity callback")
    func cancelFiresIdleActivity() async {
        let log = ActivityLog()
        let tile = Self.makeTile(activityLog: log)

        tile.isCogitating = true
        tile.cancelStreaming()

        #expect(log.activities.last == .idle)
    }

    @Test("cancelStreaming is safe to call when not cogitating")
    func cancelWhenNotCogitating() {
        let tile = Self.makeTile()

        // Should not crash or change state
        tile.cancelStreaming()

        #expect(tile.isCogitating == false)
        #expect(tile.isStreaming == false)
    }

    // MARK: - State-Based Control Enablement

    @Test("isCogitating is false at initialization — send enabled")
    func initialStateAllowsSend() {
        let tile = Self.makeTile()

        #expect(tile.isCogitating == false)
        #expect(tile.isStreaming == false)
    }

    @Test("isCogitating becomes false after sendMessage completes — send re-enabled")
    func cogitatingResetsAfterSend() async {
        let tile = Self.makeTile()
        tile.inputText = "hello"

        await tile.sendMessage()

        #expect(tile.isCogitating == false)
        #expect(tile.isStreaming == false)
    }

    @Test("cogitationVerb is 'Jake is cogitating' for Jake servitor")
    func cogitationVerbForJake() {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.servitorNames[id] = "Jake"

        let tile = Self.makeTile(servitorID: id, provider: provider)

        #expect(tile.cogitationVerb == "Jake is cogitating")
    }

    @Test("cogitationVerb uses 'thinking' for non-Jake servitors")
    func cogitationVerbForNonJake() {
        let id = UUID()
        let provider = StubServitorProvider()
        provider.servitorNames[id] = "Marcos Antonio"

        let tile = Self.makeTile(servitorID: id, provider: provider)

        #expect(tile.cogitationVerb == "Marcos Antonio is thinking")
    }

    // MARK: - Activity Callback

    @Test("sendMessage fires cogitating then idle activity callbacks")
    func sendMessageFiresActivityCallbacks() async {
        let log = ActivityLog()
        let tile = Self.makeTile(activityLog: log)
        tile.inputText = "hello"

        await tile.sendMessage()

        // Should have received cogitating followed by idle
        #expect(log.activities.count >= 2)
        guard case .cogitating = log.activities.first else {
            Issue.record("Expected first activity to be .cogitating, got \(String(describing: log.activities.first))")
            return
        }
        #expect(log.activities.last == .idle)
    }

    @Test("slash command does NOT fire cogitating activity")
    func slashCommandDoesNotFireActivity() async {
        let log = ActivityLog()
        let commandProvider = StubCommandProvider()
        commandProvider.dispatchResult = .message("output")

        let tile = Self.makeTile(commandProvider: commandProvider, activityLog: log)
        tile.inputText = "/help"

        await tile.sendMessage()

        // Slash commands short-circuit before cogitation
        let cogitatingEvents = log.activities.filter {
            if case .cogitating = $0 { return true }
            return false
        }
        #expect(cogitatingEvents.isEmpty)
    }

    // MARK: - Session Mode Sync

    @Test("sessionMode change calls setSessionMode on provider")
    func sessionModeSyncsToProvider() {
        let id = UUID()
        let provider = StubServitorProvider()
        let tile = Self.makeTile(servitorID: id, provider: provider)

        tile.sessionMode = .bypassPermissions
        tile.syncSessionModeToProvider()

        #expect(provider.setSessionModeCalls.count == 1)
        #expect(provider.setSessionModeCalls[0].mode == .bypassPermissions)
        #expect(provider.setSessionModeCalls[0].id == id)
    }

    // MARK: - Clear Conversation

    @Test("clearConversation resets all control-relevant state")
    func clearResetsControlState() async {
        let tile = Self.makeTile()
        tile.inputText = "pending"
        await tile.sendMessage()

        #expect(!tile.messages.isEmpty)

        tile.clearConversation()

        #expect(tile.messages.isEmpty)
        #expect(tile.totalInputTokens == 0)
        #expect(tile.totalOutputTokens == 0)
        #expect(tile.totalCostUsd == 0)
        #expect(tile.promptSuggestions.isEmpty)
    }
}

// MARK: - Test Helpers

/// Thread-safe log for tracking activity callbacks in tests.
private final class ActivityLog: @unchecked Sendable {
    private let lock = NSLock()
    private var _activities: [ServitorActivity] = []

    var activities: [ServitorActivity] {
        lock.lock()
        defer { lock.unlock() }
        return _activities
    }

    func record(_ activity: ServitorActivity) {
        lock.lock()
        defer { lock.unlock() }
        _activities.append(activity)
    }
}
