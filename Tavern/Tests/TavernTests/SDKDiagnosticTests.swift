import XCTest
import TavernCore

/// Diagnostic tests for ClaudeCodeSDK integration
/// Run these to verify the SDK is working correctly in your environment
final class SDKDiagnosticTests: XCTestCase {

    /// Test that Claude Code CLI is installed and accessible
    func testClaudeCodeIsInstalled() async throws {
        // Check that `claude` command exists
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which claude"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            XCTFail("""
                Claude Code CLI not found in PATH.
                Install with: npm install -g @anthropic-ai/claude-code

                Current PATH search result: \(output)
                """)
        } else {
            print("✓ Claude Code found at: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    /// Test that the SDK can create a client
    func testSDKClientCreation() throws {
        var config = ClaudeCodeConfiguration.default
        config.enableDebugLogging = true

        let client = try ClaudeCodeClient(configuration: config)
        XCTAssertNotNil(client)
        print("✓ ClaudeCodeClient created successfully")
    }

    /// Test a simple prompt using text format (workaround for SDK bug)
    /// This test is marked as potentially slow/network-dependent
    func testSimplePromptTextFormat() async throws {
        var config = ClaudeCodeConfiguration.default
        config.enableDebugLogging = true

        let client = try ClaudeCodeClient(configuration: config)

        // Very simple prompt that should return quickly
        // Using .text format because .json format has a bug in ClaudeCodeSDK
        // (Claude CLI returns array, SDK expects object)
        let result = try await client.runSinglePrompt(
            prompt: "Reply with exactly: PONG",
            outputFormat: .text,
            options: nil
        )

        switch result {
        case .text(let text):
            print("✓ Got text response: \(text)")
            XCTAssertTrue(text.contains("PONG"),
                "Expected response to contain 'PONG', got: \(text)")

        case .json(let message):
            // Shouldn't happen with .text format
            print("Got unexpected JSON: \(message.result ?? "nil")")
            XCTAssertTrue(message.result?.contains("PONG") ?? false)

        case .stream:
            XCTFail("Expected text response, got stream")
        }
    }

    /// Test that JSON format works correctly
    /// (Previous SDK bug was fixed: JSON array parsing now works)
    func testJsonFormatWorks() async throws {
        var config = ClaudeCodeConfiguration.default
        config.enableDebugLogging = true

        let client = try ClaudeCodeClient(configuration: config)

        // JSON format should work now that the SDK handles array responses
        let result = try await client.runSinglePrompt(
            prompt: "Reply with exactly: PONG",
            outputFormat: .json,
            options: nil
        )

        switch result {
        case .json(let message):
            XCTAssertNotNil(message.result, "Expected result text")
            print("✓ JSON format works: \(message.result ?? "nil")")

        case .text(let text):
            XCTFail("Expected JSON response, got text: \(text)")

        case .stream:
            XCTFail("Expected JSON response, got stream")
        }
    }
}
