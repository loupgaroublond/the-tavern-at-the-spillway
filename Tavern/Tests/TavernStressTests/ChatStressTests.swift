import XCTest
@testable import TavernCore

/// Stress tests for chat functionality
/// Run with: swift test --filter TavernStressTests
///
/// NOTE: These tests previously used MockClaudeCode for mocking responses.
/// With ClodKit, agents call Clod.query() directly
/// without dependency injection. These tests are skipped until a mocking
/// strategy is implemented.
final class ChatStressTests: XCTestCase {

    private func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-stress-\(UUID().uuidString)")
    }

    // MARK: - Test: ChatViewModel Creation Performance

    /// Tests that creating many ChatViewModels is efficient
    @MainActor
    func testChatViewModelCreationPerformance() throws {
        let projectURL = testProjectURL()
        let count = 100

        let startTime = Date()
        var viewModels: [ChatViewModel] = []

        for _ in 0..<count {
            let jake = Jake(projectURL: projectURL, loadSavedSession: false)
            let vm = ChatViewModel(jake: jake, loadHistory: false)
            viewModels.append(vm)
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(viewModels.count, count)
        print("testChatViewModelCreationPerformance: \(count) view models in \(String(format: "%.4f", duration))s")
    }

    // MARK: - Tests requiring SDK mocking (skipped)
    // TODO: These tests need dependency injection or SDK mocking to work
    // - testManyMessagesInSingleChat
    // - testLargeMessageHistory
}
