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

    /// Test that Claude Code CLI returns valid JSON
    func testClaudeCodeReturnsValidJSON() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Just ask for version in JSON format - quick, no API call
        process.arguments = ["-l", "-c", "claude --version --output-format json"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        print("stdout: \(output)")
        print("stderr: \(errorOutput)")
        print("exit code: \(process.terminationStatus)")

        if process.terminationStatus != 0 {
            XCTFail("""
                Claude Code CLI failed.
                Exit code: \(process.terminationStatus)
                stderr: \(errorOutput)
                stdout: \(output)
                """)
            return
        }

        // Try to parse as JSON
        guard let jsonData = output.data(using: .utf8) else {
            XCTFail("Output is not valid UTF-8: \(output)")
            return
        }

        do {
            _ = try JSONSerialization.jsonObject(with: jsonData)
            print("✓ Output is valid JSON")
        } catch {
            XCTFail("""
                Output is not valid JSON.
                Error: \(error)
                Raw output: \(output)
                """)
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

    /// Test that JSON format fails (documenting the SDK bug)
    func testJsonFormatBug() async throws {
        var config = ClaudeCodeConfiguration.default
        config.enableDebugLogging = true

        let client = try ClaudeCodeClient(configuration: config)

        // This should fail because of the SDK bug
        do {
            _ = try await client.runSinglePrompt(
                prompt: "hi",
                outputFormat: .json,
                options: nil
            )
            XCTFail("Expected jsonParsingError due to SDK bug")
        } catch let error as ClaudeCodeError {
            // We expect this to fail with jsonParsingError
            if case .jsonParsingError = error {
                print("✓ Confirmed SDK bug: JSON format returns array, SDK expects object")
            } else {
                XCTFail("Expected jsonParsingError, got: \(error)")
            }
        }
    }
}
