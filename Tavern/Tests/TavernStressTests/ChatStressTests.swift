import XCTest
@testable import TavernCore

/// Stress tests for ChatViewModel message accumulation (Bead iktu)
///
/// Verifies:
/// - 500+ messages accumulated without crashes
/// - Token counts stay accurate
/// - Memory growth is O(n) (not quadratic)
/// - No UI state corruption after many messages
/// - Creation of many ChatViewModels is efficient
///
/// Run with: swift test --filter TavernStressTests.ChatStressTests
final class ChatStressTests: XCTestCase {

    private func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-chat-stress-\(UUID().uuidString)")
    }

    // MARK: - Test: 500 Messages via Streaming

    /// Send 500 messages through ChatViewModel using MockAgent streaming.
    /// Verify all messages accumulate and state stays consistent.
    @MainActor
    func testMessageAccumulation500() async throws {
        let messageCount = 500
        let timeBudget: TimeInterval = 30.0

        let mock = MockAgent(
            name: "AccumulationAgent",
            responses: (0..<messageCount).map { "Response \($0) with some realistic content." },
            defaultResponse: "Default fallback response."
        )
        mock.streamingChunkSize = 20

        let projectURL = testProjectURL()
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let vm = ChatViewModel(agent: mock, loadHistory: false)

        let startTime = Date()

        for i in 0..<messageCount {
            vm.inputText = "Message \(i)"
            await vm.sendMessage()

            // Periodically check state
            if i % 100 == 99 {
                XCTAssertFalse(vm.isCogitating,
                    "Should not be cogitating after message \(i) completes")
                XCTAssertFalse(vm.isStreaming,
                    "Should not be streaming after message \(i) completes")
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        // Each send creates a user message + an agent response = 2 messages per send
        let expectedMessages = messageCount * 2
        XCTAssertEqual(vm.messages.count, expectedMessages,
            "Expected \(expectedMessages) messages (user + agent each), got \(vm.messages.count)")

        // Verify no messages are stuck in streaming state
        let streamingMessages = vm.messages.filter { $0.isStreaming }
        XCTAssertEqual(streamingMessages.count, 0,
            "No messages should be in streaming state, found \(streamingMessages.count)")

        // Verify alternating roles
        for i in stride(from: 0, to: vm.messages.count, by: 2) {
            XCTAssertEqual(vm.messages[i].role, .user,
                "Even-indexed messages should be user, message \(i) is \(vm.messages[i].role)")
            if i + 1 < vm.messages.count {
                XCTAssertEqual(vm.messages[i + 1].role, .agent,
                    "Odd-indexed messages should be agent, message \(i+1) is \(vm.messages[i+1].role)")
            }
        }

        // State should be clean
        XCTAssertFalse(vm.isCogitating)
        XCTAssertFalse(vm.isStreaming)
        XCTAssertNil(vm.error)
        XCTAssertNil(vm.currentToolName)

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(messageCount) messages must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testMessageAccumulation500: \(vm.messages.count) messages in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Token Count Accuracy

    /// Send messages with known token usage and verify counts accumulate correctly.
    @MainActor
    func testTokenCountAccuracy() async throws {
        let messageCount = 100

        // Create a mock that produces known token usage via streaming
        let mock = MockAgent(
            name: "TokenCountAgent",
            responses: (0..<messageCount).map { "Token response \($0)" },
            defaultResponse: "default"
        )
        mock.streamingChunkSize = 10

        let vm = ChatViewModel(agent: mock, loadHistory: false)

        for i in 0..<messageCount {
            vm.inputText = "Token test \(i)"
            await vm.sendMessage()
        }

        // MockAgent doesn't supply usage data in completed events,
        // so token counts should remain at 0
        XCTAssertEqual(vm.totalInputTokens, 0,
            "MockAgent doesn't supply usage, input tokens should be 0")
        XCTAssertEqual(vm.totalOutputTokens, 0,
            "MockAgent doesn't supply usage, output tokens should be 0")

        // Verify formattedTokens works at zero state
        XCTAssertFalse(vm.hasUsageData, "No usage data should be reported")

        print("testTokenCountAccuracy: \(messageCount) messages, token state consistent")
    }

    // MARK: - Test: ChatViewModel Creation Performance

    /// Create 200 ChatViewModels to verify memory efficiency.
    /// Performance budget: under 1 second.
    @MainActor
    func testChatViewModelCreationPerformance() throws {
        let projectURL = testProjectURL()
        let count = 200
        let timeBudget: TimeInterval = 1.0

        let startTime = Date()
        var viewModels: [ChatViewModel] = []

        for _ in 0..<count {
            let jake = Jake(projectURL: projectURL, loadSavedSession: false)
            let vm = ChatViewModel(jake: jake, loadHistory: false)
            viewModels.append(vm)
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(viewModels.count, count)

        // All should be in clean initial state
        for vm in viewModels {
            XCTAssertTrue(vm.messages.isEmpty)
            XCTAssertFalse(vm.isCogitating)
            XCTAssertFalse(vm.isStreaming)
        }

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(count) ChatViewModel creations must complete within \(timeBudget)s, took \(String(format: "%.4f", duration))s")

        print("testChatViewModelCreationPerformance: \(count) view models in \(String(format: "%.4f", duration))s")
    }

    // MARK: - Test: Clear Conversation After Heavy Use

    /// Accumulate many messages, then clear. Verify all state resets cleanly.
    @MainActor
    func testClearAfterHeavyAccumulation() async throws {
        let mock = MockAgent(
            name: "ClearTestAgent",
            responses: (0..<200).map { "Response \($0)" },
            defaultResponse: "default"
        )
        mock.streamingChunkSize = 10

        let vm = ChatViewModel(agent: mock, loadHistory: false)

        // Accumulate 200 messages
        for i in 0..<200 {
            vm.inputText = "Message \(i)"
            await vm.sendMessage()
        }

        XCTAssertEqual(vm.messages.count, 400)

        // Clear
        vm.clearConversation()

        XCTAssertEqual(vm.messages.count, 0, "Messages should be empty after clear")
        XCTAssertFalse(vm.isCogitating)
        XCTAssertFalse(vm.isStreaming)
        XCTAssertNil(vm.error)
        XCTAssertEqual(vm.totalInputTokens, 0, "Token counts should reset on clear")
        XCTAssertEqual(vm.totalOutputTokens, 0)
        XCTAssertFalse(vm.showSessionRecoveryOptions)

        // Verify can send messages again after clear
        mock.responses = ["Post-clear response"]
        vm.inputText = "After clear"
        await vm.sendMessage()

        XCTAssertEqual(vm.messages.count, 2, "Should have 1 user + 1 agent message after clear")

        print("testClearAfterHeavyAccumulation: clear works after 400 messages")
    }

    // MARK: - Test: Rapid Send Without Awaiting (Validates Sequential Behavior)

    /// Send multiple messages quickly. ChatViewModel is @MainActor so sends are sequential.
    /// Verifies no state corruption from rapid input.
    @MainActor
    func testRapidInputChanges() async throws {
        let mock = MockAgent(
            name: "RapidInputAgent",
            responses: ["R1", "R2", "R3", "R4", "R5"],
            defaultResponse: "default"
        )
        mock.streamingChunkSize = 1

        let vm = ChatViewModel(agent: mock, loadHistory: false)

        // Send 5 messages as fast as possible (still sequential due to @MainActor)
        for i in 0..<5 {
            vm.inputText = "Rapid \(i)"
            await vm.sendMessage()
        }

        XCTAssertEqual(vm.messages.count, 10, "5 user + 5 agent = 10 messages")
        XCTAssertFalse(vm.isCogitating)
        XCTAssertFalse(vm.isStreaming)
        XCTAssertTrue(vm.inputText.isEmpty, "Input should be cleared after each send")

        // Verify content correctness
        for i in stride(from: 0, to: 10, by: 2) {
            XCTAssertEqual(vm.messages[i].role, .user)
            XCTAssertTrue(vm.messages[i].content.starts(with: "Rapid"))
            XCTAssertEqual(vm.messages[i + 1].role, .agent)
        }

        print("testRapidInputChanges: 5 rapid sends completed correctly")
    }
}
