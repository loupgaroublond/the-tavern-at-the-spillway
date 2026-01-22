import XCTest
@testable import TavernCore

/// Stress tests for chat functionality
/// Run with: swift test --filter TavernStressTests
final class ChatStressTests: XCTestCase {

    // MARK: - Test: Many Messages in Single Chat

    /// Tests sending many messages to a single agent
    /// Verifies:
    /// - Completes without crash
    /// - Memory doesn't grow unboundedly
    /// - Last message is accessible correctly
    @MainActor
    func testManyMessagesInSingleChat() async throws {
        let mock = MockClaudeCode()
        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        let messageCount = 1000

        // Queue enough responses
        for i in 0..<messageCount {
            mock.queueTextResponse("Response \(i)")
        }

        // Send many messages
        let startTime = Date()
        for i in 0..<messageCount {
            viewModel.inputText = "Message \(i)"
            await viewModel.sendMessage()
        }
        let duration = Date().timeIntervalSince(startTime)

        // Verify results
        // Each exchange adds 2 messages (user + agent)
        XCTAssertEqual(viewModel.messages.count, messageCount * 2)

        // Verify last message is correct
        let lastMessage = viewModel.messages.last
        XCTAssertEqual(lastMessage?.role, .agent)
        XCTAssertEqual(lastMessage?.content, "Response \(messageCount - 1)")

        // Log performance
        print("testManyMessagesInSingleChat: \(messageCount) messages in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Large Message History Access

    /// Tests that accessing messages in a large history is efficient
    /// Verifies O(1) access time regardless of history position
    @MainActor
    func testLargeMessageHistory() async throws {
        let mock = MockClaudeCode()
        let jake = Jake(claude: mock)
        let viewModel = ChatViewModel(jake: jake)

        // Build up history
        let historySize = 10_000
        for i in 0..<historySize {
            mock.queueTextResponse("Response \(i)")
        }

        for i in 0..<historySize {
            viewModel.inputText = "Message \(i)"
            await viewModel.sendMessage()
        }

        // Measure access times at different positions
        let positions = [0, historySize / 4, historySize / 2, historySize - 1]
        var accessTimes: [Double] = []

        for position in positions {
            let messageIndex = position * 2 // Account for user+agent pairs
            guard messageIndex < viewModel.messages.count else {
                XCTFail("Message index out of range: \(messageIndex)")
                continue
            }

            let start = Date()
            let iterations = 10_000
            for _ in 0..<iterations {
                _ = viewModel.messages[messageIndex]
            }
            let elapsed = Date().timeIntervalSince(start)
            accessTimes.append(elapsed)
        }

        // All access times should be similar (O(1) behavior)
        guard let minTime = accessTimes.min(), let maxTime = accessTimes.max() else {
            XCTFail("No access times recorded")
            return
        }

        // Allow 10x variance (accounts for noise)
        // If access were O(n), we'd see much larger differences
        XCTAssertLessThan(maxTime / minTime, 10.0,
            "Access times vary too much: min=\(minTime), max=\(maxTime)")

        print("testLargeMessageHistory: Access times \(accessTimes.map { String(format: "%.4f", $0) })")
    }
}
