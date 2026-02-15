import XCTest
import TavernCore

/// Diagnostic tests for ClodKit integration
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

    /// Test that SDK types are accessible
    /// This verifies ClodKit is properly linked
    func testSDKTypesAccessible() {
        // These types should be accessible via @_exported import in TavernCore
        // If they're not, the SDK isn't properly linked
        let options = QueryOptions()
        XCTAssertNotNil(options)
        print("✓ QueryOptions accessible from ClodKit")
    }

    // MARK: - Tests requiring network access (skipped in CI)
    // TODO: Add integration tests that actually call Claude
    // These would need to be opt-in tests due to network/API usage
}
