import Foundation
import ClaudeCodeSDK

/// Test fixtures and helpers for Tavern tests
public enum TestFixtures {

    // MARK: - Session Fixtures

    /// Create a mock SessionInfo for testing
    /// Note: SessionInfo doesn't have a public memberwise init, so we use JSON decoding
    public static func makeSessionInfo(
        id: String = UUID().uuidString,
        created: String? = nil,
        lastActive: String? = nil,
        totalCostUsd: Double? = nil,
        project: String? = nil
    ) -> SessionInfo? {
        let json: [String: Any?] = [
            "id": id,
            "created": created,
            "last_active": lastActive,
            "total_cost_usd": totalCostUsd,
            "project": project
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: json.compactMapValues { $0 }),
              let session = try? JSONDecoder().decode(SessionInfo.self, from: data) else {
            return nil
        }
        return session
    }

    // MARK: - Configuration Fixtures

    /// Default test configuration (doesn't make real API calls)
    public static var testConfiguration: ClaudeCodeConfiguration {
        var config = ClaudeCodeConfiguration.default
        config.enableDebugLogging = false
        return config
    }

    // MARK: - Response Fixtures

    /// A simple successful text response
    public static let successTextResponse = "Task completed successfully."

    /// A simple error response
    public static let errorResponse = "Error: Something went wrong."

    /// Jake's greeting response
    public static let jakeGreeting = """
        Well well WELL, look who just walked into the Tavern!

        *wipes down the bar with a suspicious rag*

        I'm Jake, The Proprietor. You need something done? I got PEOPLE for that!
        (They're technically processes but we don't discriminate here at the spillway!)

        What can I do ya for?
        """
}

// MARK: - Temporary Directory Helper

extension TestFixtures {
    /// Create a temporary directory for testing
    public static func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TavernTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Clean up a temporary directory
    public static func cleanupTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
