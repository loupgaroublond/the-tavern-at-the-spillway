//
//  SessionStorageIntegrationTests.swift
//  ClaudeCodeSDKTests
//
//  Integration tests for session storage that use REAL Claude sessions.
//  These tests create actual sessions via the Claude CLI and verify
//  that the SDK can correctly parse and rehydrate them.
//

import XCTest
@testable import ClaudeCodeSDK
import Foundation
import Darwin

final class SessionStorageIntegrationTests: XCTestCase {

    /// Resolve path using C realpath() to handle macOS firmlinks like /var -> /private/var
    private func resolveRealPath(_ path: String) -> String {
        var resolved = [CChar](repeating: 0, count: Int(PATH_MAX))
        if realpath(path, &resolved) != nil {
            // Convert CChar array to String, truncating at null terminator
            let data = resolved.withUnsafeBufferPointer { ptr -> Data in
                let length = strnlen(ptr.baseAddress!, Int(PATH_MAX))
                return Data(bytes: ptr.baseAddress!, count: length)
            }
            return String(decoding: data, as: UTF8.self)
        }
        return path
    }

    var tempDirectory: URL!
    var client: ClaudeCodeClient!

    override func setUp() async throws {
        // Create a unique temp directory for this test
        let tempBase = FileManager.default.temporaryDirectory
        var tempDir = tempBase.appendingPathComponent("claude-sdk-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Resolve symlinks (macOS /var -> /private/var) so paths match Claude CLI
        tempDir = tempDir.resolvingSymlinksInPath()
        tempDirectory = tempDir

        // Create a client pointing to this directory
        var config = ClaudeCodeConfiguration()
        config.workingDirectory = tempDirectory.path
        config.enableDebugLogging = true
        client = try ClaudeCodeClient(configuration: config)
    }

    override func tearDown() async throws {
        // Clean up temp directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Real Session Tests

    /// Test that we can create a real session and read it back
    func testCreateAndReadRealSession() async throws {
        // Skip if Claude CLI not available
        guard await isClaudeAvailable() else {
            throw XCTSkip("Claude CLI not available")
        }

        // Step 1: Create a real session by sending a message
        let prompt = "Say exactly: TEST_RESPONSE_123"
        let result = try await client.runSinglePrompt(
            prompt: prompt,
            outputFormat: .json,
            options: nil
        )

        // Extract session ID from result
        guard case .json(let resultMessage) = result else {
            XCTFail("Expected JSON result")
            return
        }

        let sessionId = resultMessage.sessionId
        XCTAssertFalse(sessionId.isEmpty, "Session ID should not be empty")

        // Step 2: Use ClaudeNativeSessionStorage to read the session back
        let storage = ClaudeNativeSessionStorage()
        let messages = try await storage.getMessages(
            sessionId: sessionId,
            projectPath: tempDirectory.path
        )

        // Step 3: Verify we got both user and assistant messages
        XCTAssertGreaterThanOrEqual(messages.count, 2, "Should have at least user + assistant message")

        let userMessages = messages.filter { $0.role == .user }
        let assistantMessages = messages.filter { $0.role == .assistant }

        XCTAssertEqual(userMessages.count, 1, "Should have exactly 1 user message")
        XCTAssertGreaterThanOrEqual(assistantMessages.count, 1, "Should have at least 1 assistant message")

        // Verify user message content
        if let userMsg = userMessages.first {
            XCTAssertTrue(userMsg.content.contains("TEST_RESPONSE_123"), "User message should contain prompt")
        }

        // Verify assistant message has content
        if let assistantMsg = assistantMessages.first {
            XCTAssertFalse(assistantMsg.content.isEmpty, "Assistant message should not be empty")
        }
    }

    /// Test that we can resume a session and read the full history
    func testResumeSessionAndReadHistory() async throws {
        guard await isClaudeAvailable() else {
            throw XCTSkip("Claude CLI not available")
        }

        // Step 1: Create initial session
        let result1 = try await client.runSinglePrompt(
            prompt: "Remember the number 42",
            outputFormat: .json,
            options: nil
        )

        guard case .json(let msg1) = result1 else {
            XCTFail("Expected JSON result")
            return
        }
        let sessionId = msg1.sessionId

        // Step 2: Resume and add another message
        let result2 = try await client.resumeConversation(
            sessionId: sessionId,
            prompt: "What number did I ask you to remember?",
            outputFormat: .json,
            options: nil
        )

        guard case .json(_) = result2 else {
            XCTFail("Expected JSON result for resumed session")
            return
        }

        // Step 3: Read back all messages
        let storage = ClaudeNativeSessionStorage()
        let messages = try await storage.getMessages(
            sessionId: sessionId,
            projectPath: tempDirectory.path
        )

        // Should have 2 user messages and 2 assistant messages
        let userMessages = messages.filter { $0.role == .user }
        let assistantMessages = messages.filter { $0.role == .assistant }

        XCTAssertEqual(userMessages.count, 2, "Should have 2 user messages")
        XCTAssertEqual(assistantMessages.count, 2, "Should have 2 assistant messages")
    }

    /// Test parsing of the actual JSONL file structure
    func testParseRealJSONLStructure() async throws {
        guard await isClaudeAvailable() else {
            throw XCTSkip("Claude CLI not available")
        }

        // Create a session
        let result = try await client.runSinglePrompt(
            prompt: "Hi",
            outputFormat: .json,
            options: nil
        )

        guard case .json(let msg) = result else {
            XCTFail("Expected JSON result")
            return
        }

        // Find the JSONL file
        let projectsPath = NSString(string: "~/.claude/projects").expandingTildeInPath
        // Use realpath() to resolve firmlinks (e.g., /var -> /private/var on macOS)
        let resolvedPath = resolveRealPath(tempDirectory.path)
        // Claude CLI replaces both slashes and underscores with dashes
        let encodedPath = resolvedPath
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        let sessionFile = "\(projectsPath)/\(encodedPath)/\(msg.sessionId).jsonl"

        // Verify the file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionFile), "Session file should exist at \(sessionFile)")

        // Read and parse it manually to verify structure
        let data = try Data(contentsOf: URL(fileURLWithPath: sessionFile))
        let content = String(data: data, encoding: .utf8)!
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Find user and assistant lines
        var foundUser = false
        var foundAssistant = false

        for line in lines {
            if let json = try? JSONSerialization.jsonObject(with: line.data(using: .utf8)!) as? [String: Any] {
                let type = json["type"] as? String
                if type == "user" { foundUser = true }
                if type == "assistant" { foundAssistant = true }
            }
        }

        XCTAssertTrue(foundUser, "JSONL should contain user message")
        XCTAssertTrue(foundAssistant, "JSONL should contain assistant message")

        // Now verify SDK can parse all of them
        let storage = ClaudeNativeSessionStorage()
        let messages = try await storage.getMessages(sessionId: msg.sessionId, projectPath: tempDirectory.path)

        let sdkUserCount = messages.filter { $0.role == .user }.count
        let sdkAssistantCount = messages.filter { $0.role == .assistant }.count

        XCTAssertEqual(sdkUserCount, 1, "SDK should parse 1 user message")
        XCTAssertEqual(sdkAssistantCount, 1, "SDK should parse 1 assistant message (currently failing!)")
    }

    // MARK: - Helpers

    private func isClaudeAvailable() async -> Bool {
        do {
            return try await client.validateCommand("claude")
        } catch {
            return false
        }
    }
}
