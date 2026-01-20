import Foundation
import Testing
@testable import TavernCore

@Suite("TavernCore Tests")
struct TavernCoreTests {

    @Test("Version is set")
    func versionIsSet() {
        #expect(TavernCore.version == "0.1.0")
    }
}

@Suite("MockClaudeCode Tests")
struct MockClaudeCodeTests {

    @Test("Mock returns queued text response")
    func mockReturnsQueuedTextResponse() async throws {
        let mock = MockClaudeCode()
        mock.queueTextResponse("Hello from mock!")

        let result = try await mock.runSinglePrompt(
            prompt: "Test prompt",
            outputFormat: .text,
            options: nil
        )

        if case .text(let text) = result {
            #expect(text == "Hello from mock!")
        } else {
            Issue.record("Expected text result")
        }
    }

    @Test("Mock records sent prompts")
    func mockRecordsSentPrompts() async throws {
        let mock = MockClaudeCode()
        mock.queueTextResponse("Response 1")
        mock.queueTextResponse("Response 2")

        _ = try await mock.runSinglePrompt(prompt: "First prompt", outputFormat: .text, options: nil)
        _ = try await mock.runSinglePrompt(prompt: "Second prompt", outputFormat: .text, options: nil)

        #expect(mock.sentPrompts.count == 2)
        #expect(mock.sentPrompts[0] == "First prompt")
        #expect(mock.sentPrompts[1] == "Second prompt")
    }

    @Test("Mock throws configured error")
    func mockThrowsConfiguredError() async throws {
        let mock = MockClaudeCode()
        mock.errorToThrow = ClaudeCodeError.executionFailed("Test error")

        do {
            _ = try await mock.runSinglePrompt(prompt: "Test", outputFormat: .text, options: nil)
            Issue.record("Expected error to be thrown")
        } catch {
            // Expected
            #expect(error is ClaudeCodeError)
        }
    }

    @Test("Mock tracks cancel calls")
    func mockTracksCancelCalls() {
        let mock = MockClaudeCode()
        #expect(mock.wasCancelled == false)

        mock.cancel()

        #expect(mock.wasCancelled == true)
    }

    @Test("Mock reset clears state")
    func mockResetClearsState() async throws {
        let mock = MockClaudeCode()
        mock.queueTextResponse("Response")
        _ = try await mock.runSinglePrompt(prompt: "Test", outputFormat: .text, options: nil)
        mock.cancel()

        mock.reset()

        #expect(mock.queuedResponses.isEmpty)
        #expect(mock.sentPrompts.isEmpty)
        #expect(mock.wasCancelled == false)
    }

    @Test("Mock returns JSON response with session ID")
    func mockReturnsJSONResponseWithSessionID() async throws {
        let mock = MockClaudeCode()
        let sessionId = "test-session-123"
        mock.queueJSONResponse(result: "Success!", sessionId: sessionId)

        let result = try await mock.runSinglePrompt(
            prompt: "Test",
            outputFormat: .json,
            options: nil
        )

        #expect(result.sessionId == sessionId)
    }
}

@Suite("TestFixtures Tests")
struct TestFixturesTests {

    @Test("Creates temp directory")
    func createsTempDirectory() throws {
        let tempDir = try TestFixtures.createTempDirectory()

        #expect(FileManager.default.fileExists(atPath: tempDir.path))

        // Cleanup
        TestFixtures.cleanupTempDirectory(tempDir)
        #expect(!FileManager.default.fileExists(atPath: tempDir.path))
    }

    @Test("Test configuration is valid")
    func testConfigurationIsValid() {
        let config = TestFixtures.testConfiguration
        #expect(config.enableDebugLogging == false)
    }
}
