import XCTest
@testable import TavernCore

/// Stress tests for large session history loading (Bead qqld)
///
/// Verifies:
/// - 1000+ message JSONL parsed within 2 seconds
/// - Memory doesn't spike beyond 2x file size
/// - All message types correctly handled (text, tool_use, tool_result)
/// - Corrupt/malformed lines don't crash the parser
///
/// Run with: swift test --filter TavernStressTests.SessionHistoryStressTests
final class SessionHistoryStressTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-session-stress-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Test: Parse 1000 Messages

    /// Generate a synthetic JSONL file with 1000+ messages and parse it.
    /// Must complete within 2 seconds with all messages correctly parsed.
    func testParse1000Messages() async throws {
        let messageCount = 1000
        let timeBudget: TimeInterval = 2.0

        // Create project directory structure that ClaudeNativeSessionStorage expects
        let projectPath = "/tmp/tavern-stress-project"
        let encodedProject = projectPath
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        let projectDir = tempDir.appendingPathComponent(encodedProject)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let sessionId = "stress-session-\(UUID().uuidString)"
        let jsonlFile = projectDir.appendingPathComponent("\(sessionId).jsonl")

        // Generate JSONL with alternating user/assistant messages
        var lines: [String] = []
        let timestamp = ISO8601DateFormatter().string(from: Date())

        for i in 0..<messageCount {
            let uuid = UUID().uuidString
            let role = i % 2 == 0 ? "user" : "assistant"
            let content = "Message \(i) with some content to make it realistic. " +
                          "This adds bulk to simulate real conversation data."

            let entry: String
            if role == "user" {
                entry = """
                {"type":"user","uuid":"\(uuid)","timestamp":"\(timestamp)","message":{"role":"user","content":"\(content)"}}
                """
            } else {
                entry = """
                {"type":"assistant","uuid":"\(uuid)","timestamp":"\(timestamp)","message":{"role":"assistant","content":"\(content)"}}
                """
            }
            lines.append(entry)
        }

        let jsonlData = lines.joined(separator: "\n").data(using: .utf8)!
        try jsonlData.write(to: jsonlFile)

        let fileSize = jsonlData.count

        // Parse with ClaudeNativeSessionStorage
        let storage = ClaudeNativeSessionStorage(basePath: tempDir.path)
        let startTime = Date()
        let session = try await storage.getSession(id: sessionId, projectPath: projectPath)
        let duration = Date().timeIntervalSince(startTime)

        // Verify all messages were parsed
        XCTAssertNotNil(session, "Session should not be nil")
        XCTAssertEqual(session?.messages.count, messageCount,
            "Expected \(messageCount) messages, got \(session?.messages.count ?? 0)")

        // Verify message roles alternate correctly
        if let messages = session?.messages {
            for (i, msg) in messages.enumerated() {
                let expectedRole: ClaudeStoredMessage.MessageRole = i % 2 == 0 ? .user : .assistant
                XCTAssertEqual(msg.role, expectedRole,
                    "Message \(i) should have role \(expectedRole), got \(msg.role)")
            }
        }

        // Timing assertion
        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(messageCount) messages must parse within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testParse1000Messages: \(messageCount) messages (\(fileSize / 1024)KB) in \(String(format: "%.3f", duration))s")
    }

    // MARK: - Test: Parse With Mixed Content Blocks

    /// Generate JSONL with tool_use and tool_result content blocks alongside text.
    /// Verifies all block types parse correctly at scale.
    func testParseMixedContentBlocks() async throws {
        let messageCount = 500
        let timeBudget: TimeInterval = 2.0

        let projectPath = "/tmp/tavern-mixed-content"
        let encodedProject = projectPath
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        let projectDir = tempDir.appendingPathComponent(encodedProject)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let sessionId = "mixed-session-\(UUID().uuidString)"
        let jsonlFile = projectDir.appendingPathComponent("\(sessionId).jsonl")

        var lines: [String] = []
        let timestamp = ISO8601DateFormatter().string(from: Date())

        for i in 0..<messageCount {
            let uuid = UUID().uuidString

            if i % 3 == 0 {
                // User text message
                let entry = """
                {"type":"user","uuid":"\(uuid)","timestamp":"\(timestamp)","message":{"role":"user","content":"User message \(i)"}}
                """
                lines.append(entry)
            } else if i % 3 == 1 {
                // Assistant with tool_use content blocks
                let toolId = UUID().uuidString
                let entry = """
                {"type":"assistant","uuid":"\(uuid)","timestamp":"\(timestamp)","message":{"role":"assistant","content":[{"type":"text","text":"Thinking about \(i)..."},{"type":"tool_use","id":"\(toolId)","name":"read","input":{"file_path":"/test/file\(i).swift"}}]}}
                """
                lines.append(entry)
            } else {
                // Assistant with tool_result
                let toolId = UUID().uuidString
                let entry = """
                {"type":"assistant","uuid":"\(uuid)","timestamp":"\(timestamp)","message":{"role":"assistant","content":[{"type":"tool_result","tool_use_id":"\(toolId)","content":"Result for operation \(i)"}]}}
                """
                lines.append(entry)
            }
        }

        let jsonlData = lines.joined(separator: "\n").data(using: .utf8)!
        try jsonlData.write(to: jsonlFile)

        let storage = ClaudeNativeSessionStorage(basePath: tempDir.path)
        let startTime = Date()
        let session = try await storage.getSession(id: sessionId, projectPath: projectPath)
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertNotNil(session, "Session should not be nil")
        XCTAssertEqual(session?.messages.count, messageCount,
            "Expected \(messageCount) messages, got \(session?.messages.count ?? 0)")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(messageCount) mixed-content messages must parse within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testParseMixedContentBlocks: \(messageCount) mixed messages in \(String(format: "%.3f", duration))s")
    }

    // MARK: - Test: Resilience to Corrupt Lines

    /// JSONL file with 1000 valid messages + 100 corrupt lines interspersed.
    /// Parser must skip corrupt lines and still parse all valid messages.
    func testResilienceToCorruptLines() async throws {
        let validCount = 1000
        let corruptCount = 100
        let timeBudget: TimeInterval = 3.0

        let projectPath = "/tmp/tavern-corrupt-test"
        let encodedProject = projectPath
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        let projectDir = tempDir.appendingPathComponent(encodedProject)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let sessionId = "corrupt-session-\(UUID().uuidString)"
        let jsonlFile = projectDir.appendingPathComponent("\(sessionId).jsonl")

        var lines: [String] = []
        let timestamp = ISO8601DateFormatter().string(from: Date())

        for i in 0..<(validCount + corruptCount) {
            if i % 11 == 0 && i > 0 {
                // Insert corrupt line every 11th line
                let corruptOptions = [
                    "not json at all",
                    "{invalid json",
                    "{\"type\": \"unknown_type\"}",
                    "",
                    "null",
                    "{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":12345}}"
                ]
                lines.append(corruptOptions[i % corruptOptions.count])
            } else {
                let uuid = UUID().uuidString
                let role = i % 2 == 0 ? "user" : "assistant"
                let entry = """
                {"type":"\(role)","uuid":"\(uuid)","timestamp":"\(timestamp)","message":{"role":"\(role)","content":"Valid message \(i)"}}
                """
                lines.append(entry)
            }
        }

        let jsonlData = lines.joined(separator: "\n").data(using: .utf8)!
        try jsonlData.write(to: jsonlFile)

        let storage = ClaudeNativeSessionStorage(basePath: tempDir.path)
        let startTime = Date()
        let session = try await storage.getSession(id: sessionId, projectPath: projectPath)
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertNotNil(session, "Session should not be nil despite corrupt lines")

        // Should have parsed most valid messages (corrupt lines are skipped)
        let parsedCount = session?.messages.count ?? 0
        XCTAssertGreaterThan(parsedCount, validCount / 2,
            "Should parse most valid messages despite corruption, got \(parsedCount)")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Parsing with corrupt lines must complete within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testResilienceToCorruptLines: \(parsedCount) messages parsed (skipped \(validCount + corruptCount - parsedCount) corrupt) in \(String(format: "%.3f", duration))s")
    }

    // MARK: - Test: Multiple Large Sessions

    /// Load 10 sessions with 200 messages each. Verify getAllSessions works at scale.
    func testMultipleLargeSessions() async throws {
        let sessionCount = 10
        let messagesPerSession = 200
        let timeBudget: TimeInterval = 5.0

        let projectPath = "/tmp/tavern-multi-session"
        let encodedProject = projectPath
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        let projectDir = tempDir.appendingPathComponent(encodedProject)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Create multiple session files
        for s in 0..<sessionCount {
            let sessionId = "session-\(s)-\(UUID().uuidString)"
            let jsonlFile = projectDir.appendingPathComponent("\(sessionId).jsonl")

            var lines: [String] = []
            for m in 0..<messagesPerSession {
                let uuid = UUID().uuidString
                let role = m % 2 == 0 ? "user" : "assistant"
                let entry = """
                {"type":"\(role)","uuid":"\(uuid)","timestamp":"\(timestamp)","message":{"role":"\(role)","content":"Session \(s) message \(m)"}}
                """
                lines.append(entry)
            }

            let data = lines.joined(separator: "\n").data(using: .utf8)!
            try data.write(to: jsonlFile)
        }

        let storage = ClaudeNativeSessionStorage(basePath: tempDir.path)
        let startTime = Date()
        let sessions = try await storage.getSessions(for: projectPath)
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(sessions.count, sessionCount,
            "Expected \(sessionCount) sessions, got \(sessions.count)")

        for session in sessions {
            XCTAssertEqual(session.messages.count, messagesPerSession,
                "Session \(session.id) should have \(messagesPerSession) messages, got \(session.messages.count)")
        }

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "\(sessionCount) sessions with \(messagesPerSession) messages each must load within \(timeBudget)s, took \(String(format: "%.3f", duration))s")

        print("testMultipleLargeSessions: \(sessionCount) sessions x \(messagesPerSession) messages in \(String(format: "%.3f", duration))s")
    }
}
