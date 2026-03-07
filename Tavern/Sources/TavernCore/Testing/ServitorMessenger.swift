import Foundation
import ClodKit

// MARK: - Provenance: REQ-ARCH-009, REQ-QA-002, REQ-QA-005

// SessionUsage and StreamEvent have moved to TavernKit.

// MARK: - ServitorMessenger Protocol

/// Protocol abstracting the Claude SDK communication layer.
/// Jake and Mortal use this to send messages — `LiveMessenger` calls real Claude,
/// `MockMessenger` returns canned responses for testing.
public protocol ServitorMessenger: Sendable {
    /// Send a prompt to Claude and get a response (batch mode)
    /// - Parameters:
    ///   - prompt: The user's message
    ///   - options: Query options (system prompt, session ID, etc.)
    /// - Returns: Tuple of (response text, session ID if available)
    func query(prompt: String, options: QueryOptions) async throws -> (response: String, sessionId: String?)

    /// Send a prompt to Claude and receive a stream of events (streaming mode)
    /// - Parameters:
    ///   - prompt: The user's message
    ///   - options: Query options (system prompt, session ID, etc.)
    /// - Returns: A stream of StreamEvent values and a cancellation handle
    func queryStreaming(prompt: String, options: QueryOptions) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void)

    /// Fetch account information from the Claude SDK.
    /// Creates a lightweight query to retrieve account and initialization data.
    /// - Parameter options: Query options (working directory, etc.)
    /// - Returns: Account info and initialization result
    func fetchAccountInfo(options: QueryOptions) async throws -> (account: AccountInfo, initResult: SDKControlInitializeResponse)

    // MARK: - MCP Runtime Control

    /// Get the status of all configured MCP servers for the current session.
    func mcpServerStatus() async throws -> [McpServerStatus]

    /// Reconnect a named MCP server.
    func reconnectMcpServer(name: String) async throws

    /// Enable or disable a named MCP server.
    func toggleMcpServer(name: String, enabled: Bool) async throws
}
