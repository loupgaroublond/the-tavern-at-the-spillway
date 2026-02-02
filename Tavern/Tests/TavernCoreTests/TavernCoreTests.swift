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

    // Note: TestFixtures.testConfiguration was removed in SDK migration
    // The new SDK doesn't have the same configuration pattern
}

// MARK: - MockSDKMessage Tests (new SDK helper tests)

@Suite("MockSDKMessage Tests")
struct MockSDKMessageTests {

    @Test("Result message has correct type")
    func resultMessageHasCorrectType() {
        let msg = MockSDKMessage.result(text: "Hello")
        #expect(msg.type == "result")
        #expect(msg.content?.stringValue == "Hello")
    }

    @Test("Assistant message has correct type")
    func assistantMessageHasCorrectType() {
        let msg = MockSDKMessage.assistant(text: "Response")
        #expect(msg.type == "assistant")
        #expect(msg.content?.stringValue == "Response")
    }

    @Test("System init message has session ID")
    func systemInitMessageHasSessionId() {
        let msg = MockSDKMessage.systemInit(sessionId: "test-123")
        #expect(msg.type == "system")
        // The session_id is in the data, not content
        if case .object(let obj) = msg.data,
           case .string(let sessId) = obj["session_id"] {
            #expect(sessId == "test-123")
        } else {
            Issue.record("Expected session_id in data")
        }
    }
}

@Suite("MockQueryStream Tests")
struct MockQueryStreamTests {

    @Test("Stream yields all messages")
    func streamYieldsAllMessages() async throws {
        let stream = MockQueryStream(result: "Test response", sessionId: "s-123")

        var messages: [StdoutMessage] = []
        for try await msg in stream {
            messages.append(msg)
        }

        #expect(messages.count == 2) // system init + result
    }

    @Test("Stream convenience init creates correct messages")
    func streamConvenienceInitCreatesCorrectMessages() async throws {
        let stream = MockQueryStream(result: "Hello!", sessionId: "sess-abc")

        var resultContent: String?
        for try await msg in stream {
            if case .regular(let sdk) = msg, sdk.type == "result" {
                resultContent = sdk.content?.stringValue
            }
        }

        #expect(resultContent == "Hello!")
    }
}
