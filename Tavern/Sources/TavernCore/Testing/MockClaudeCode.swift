import Foundation
import ClaudeCodeSDK

/// Mock helpers for testing with ClodeMonster SDK
/// Since ClodeMonster uses static functions and AsyncSequence, mocking requires
/// different patterns than the old protocol-based SDK.
///
/// For unit testing agents, consider:
/// 1. Testing at a higher level (integration tests with real SDK)
/// 2. Using ClodeMonster's MockTransport for transport-level mocking
/// 3. Dependency injection with protocol wrappers if needed

// MARK: - Test Response Helpers

/// Helper to create mock SDKMessage responses for testing
public enum MockSDKMessage {

    /// Create a result message with text content
    /// SDKMessage.content for "result" type returns rawJSON["result"]
    public static func result(text: String) -> SDKMessage {
        SDKMessage(type: "result", rawJSON: [
            "type": .string("result"),
            "result": .string(text)
        ])
    }

    /// Create an assistant message
    /// SDKMessage.content for "assistant" type extracts from message.content[0].text
    public static func assistant(text: String) -> SDKMessage {
        SDKMessage(type: "assistant", rawJSON: [
            "type": .string("assistant"),
            "message": .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string(text)
                    ])
                ])
            ])
        ])
    }

    /// Create a system init message with session ID
    public static func systemInit(sessionId: String) -> SDKMessage {
        SDKMessage(type: "system", rawJSON: [
            "type": .string("system"),
            "subtype": .string("init"),
            "session_id": .string(sessionId)
        ])
    }
}

// MARK: - Mock Query Stream

/// A mock AsyncSequence that yields predetermined messages
/// Use this for unit testing components that consume ClaudeQuery
public struct MockQueryStream: AsyncSequence {
    public typealias Element = StdoutMessage

    private let messages: [StdoutMessage]

    public init(messages: [StdoutMessage]) {
        self.messages = messages
    }

    /// Convenience init with a simple result
    public init(result: String, sessionId: String = UUID().uuidString) {
        self.messages = [
            .regular(MockSDKMessage.systemInit(sessionId: sessionId)),
            .regular(MockSDKMessage.result(text: result))
        ]
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(messages: messages)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var messages: [StdoutMessage]
        private var index = 0

        init(messages: [StdoutMessage]) {
            self.messages = messages
        }

        public mutating func next() async throws -> StdoutMessage? {
            guard index < messages.count else { return nil }
            let message = messages[index]
            index += 1
            return message
        }
    }
}
