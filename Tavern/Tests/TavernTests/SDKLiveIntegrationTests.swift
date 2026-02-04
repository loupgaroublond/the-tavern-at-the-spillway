import XCTest
import ClaudeCodeSDK
@testable import TavernCore

/// Live integration tests that actually call the Claude CLI
/// These tests verify that the SDK can communicate with Claude correctly
///
/// Run with: swift test --filter SDKLiveIntegrationTests
/// Or individually: swift test --filter testBasicQueryWithoutMCP
///
/// Note: These tests require Claude Code CLI to be installed and authenticated.
/// They use real API calls but should be very cheap (minimal tokens).
final class SDKLiveIntegrationTests: XCTestCase {

    /// Timeout for live tests - 30 seconds should be plenty
    let testTimeout: TimeInterval = 30.0

    // MARK: - Basic Connectivity Tests

    /// Test the most basic query - no MCP, no options, just a simple prompt
    func testBasicQueryWithoutMCP() async throws {
        print("\n=== testBasicQueryWithoutMCP ===")

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "You are a test assistant. Respond with exactly: TEST_OK"
        // Use a temp directory as working directory
        options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())

        print("Creating query with prompt: 'Say TEST_OK'")
        print("Working directory: \(options.workingDirectory?.path ?? "nil")")

        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say TEST_OK", options: options)
            print("✓ Query created successfully")
        } catch {
            XCTFail("Failed to create query: \(error)")
            return
        }

        print("Collecting messages from stream...")
        var messages: [(type: String, hasContent: Bool)] = []
        var resultContent: String?

        do {
            for try await message in query {
                switch message {
                case .regular(let sdkMessage):
                    let hasContent = sdkMessage.content != nil
                    let hasData = sdkMessage.data != nil
                    messages.append((type: sdkMessage.type, hasContent: hasContent))
                    print("  Message #\(messages.count): type=\(sdkMessage.type), hasContent=\(hasContent), hasData=\(hasData)")

                    // Log raw data for debugging
                    if let data = sdkMessage.data {
                        print("    data keys: \(data.objectValue?.keys.sorted() ?? [])")
                    }

                    if sdkMessage.type == "result" {
                        // Try both content field and data.result field
                        resultContent = sdkMessage.content?.stringValue
                        if resultContent == nil, let dataResult = sdkMessage.data?.objectValue?["result"]?.stringValue {
                            resultContent = dataResult
                            print("    Got result from data.result: \(dataResult.prefix(50))...")
                        }
                        print("  Result content: \(resultContent ?? "nil")")
                    } else if sdkMessage.type == "assistant" {
                        // Try content field and data.message.content[0].text
                        if let content = sdkMessage.content?.stringValue {
                            print("  Assistant content: \(content.prefix(100))...")
                        }
                        if let messageObj = sdkMessage.data?.objectValue?["message"]?.objectValue,
                           let contentArray = messageObj["content"]?.arrayValue,
                           let firstContent = contentArray.first?.objectValue,
                           let text = firstContent["text"]?.stringValue {
                            print("    Got assistant text from data.message.content[0].text: \(text.prefix(50))...")
                            if resultContent == nil {
                                resultContent = text
                            }
                        }
                    }
                case .controlRequest(let req):
                    print("  Control request: \(req)")
                case .controlResponse(let resp):
                    print("  Control response: \(resp)")
                case .controlCancelRequest(let cancel):
                    print("  Cancel request: \(cancel)")
                case .keepAlive:
                    print("  Keep alive")
                }
            }
        } catch {
            XCTFail("Error while collecting messages: \(error)")
            return
        }

        print("\nTotal messages received: \(messages.count)")
        print("Message types: \(messages.map { $0.type })")

        // Verify we got messages
        XCTAssertGreaterThan(messages.count, 0, "Should receive at least one message")

        // Verify we got a system init message
        let hasSystemInit = messages.contains { $0.type == "system" }
        XCTAssertTrue(hasSystemInit, "Should receive system init message")

        // Verify we got a result message
        let hasResult = messages.contains { $0.type == "result" }
        XCTAssertTrue(hasResult, "Should receive result message")

        // Verify result has content
        XCTAssertNotNil(resultContent, "Result should have content")
        if let content = resultContent {
            XCTAssertFalse(content.isEmpty, "Result content should not be empty")
            print("✓ Got response: \(content.prefix(100))...")
        }

        // Check session ID
        let sessionId = await query.sessionId
        print("Session ID: \(sessionId ?? "nil")")
        XCTAssertNotNil(sessionId, "Should have a session ID after query")

        print("✓ testBasicQueryWithoutMCP PASSED\n")
    }

    /// Test query with a simple MCP server (no tools, just registration)
    func testQueryWithEmptyMCPServer() async throws {
        print("\n=== testQueryWithEmptyMCPServer ===")

        // Create an empty MCP server
        let emptyServer = SDKMCPServer(
            name: "test-empty",
            version: "1.0.0",
            tools: []
        )

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "You are a test assistant. Respond with exactly: MCP_OK"
        options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        options.sdkMcpServers["test-empty"] = emptyServer

        print("Creating query with empty MCP server...")
        print("MCP servers: \(options.sdkMcpServers.keys)")

        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say MCP_OK", options: options)
            print("✓ Query created successfully with MCP server")
        } catch {
            XCTFail("Failed to create query with MCP: \(error)")
            return
        }

        print("Collecting messages...")
        var messages: [(type: String, hasContent: Bool)] = []
        var resultContent: String?

        do {
            for try await message in query {
                switch message {
                case .regular(let sdkMessage):
                    messages.append((type: sdkMessage.type, hasContent: sdkMessage.content != nil))
                    print("  Message: type=\(sdkMessage.type)")
                    if sdkMessage.type == "result" {
                        resultContent = sdkMessage.content?.stringValue
                    }
                case .controlRequest, .controlResponse, .controlCancelRequest, .keepAlive:
                    break
                }
            }
        } catch {
            XCTFail("Error while collecting messages with MCP: \(error)")
            return
        }

        print("Total messages: \(messages.count)")
        XCTAssertGreaterThan(messages.count, 0, "Should receive messages with MCP")
        XCTAssertNotNil(resultContent, "Should have result content")

        print("✓ testQueryWithEmptyMCPServer PASSED\n")
    }

    /// Test query with MCP server that has tools
    func testQueryWithMCPTools() async throws {
        print("\n=== testQueryWithMCPTools ===")

        // Create an MCP server with a simple tool
        let testServer = SDKMCPServer(
            name: "test-tools",
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "test_tool",
                    description: "A test tool that does nothing. Don't call it.",
                    inputSchema: JSONSchema(
                        properties: [:],
                        required: []
                    ),
                    handler: { _ in
                        return MCPToolResult(content: [.text("Tool was called")])
                    }
                )
            ]
        )

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "You are a test assistant. Just say TOOLS_OK. Do not call any tools."
        options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        options.sdkMcpServers["test-tools"] = testServer

        print("Creating query with MCP tools server...")
        print("Tools registered: test_tool")

        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say TOOLS_OK", options: options)
            print("✓ Query created successfully with MCP tools")
        } catch {
            XCTFail("Failed to create query with MCP tools: \(error)")
            return
        }

        print("Collecting messages...")
        var resultContent: String?

        do {
            for try await message in query {
                switch message {
                case .regular(let sdkMessage):
                    print("  Message: type=\(sdkMessage.type)")
                    if sdkMessage.type == "result" {
                        resultContent = sdkMessage.content?.stringValue
                    }
                case .controlRequest:
                    print("  Control request received - method might be tool call")
                default:
                    break
                }
            }
        } catch {
            XCTFail("Error: \(error)")
            return
        }

        XCTAssertNotNil(resultContent, "Should have result")

        print("✓ testQueryWithMCPTools PASSED\n")
    }

    /// Test with handlers using TavernLogger (is logging the issue?)
    func testHandlerWithTavernLogger() async throws {
        print("\n=== testHandlerWithTavernLogger ===")

        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let projectURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-logger-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )

        let onSummon: @Sendable (Servitor) async -> Void = { servitor in
            print("  onSummon: \(servitor.name)")
        }
        let onDismiss: @Sendable (UUID) async -> Void = { id in
            print("  onDismiss: \(id)")
        }

        print("Created dependencies")

        // Create handlers EXACTLY like createTavernMCPServer
        let testServer = SDKMCPServer(
            name: "tavern",
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "summon_servitor",
                    description: "Summon one of your Regulars to handle work. Auto-generates a name. Usually call with no params.",
                    inputSchema: JSONSchema(
                        properties: [
                            "assignment": .string("What you need them for (optional)"),
                            "name": .string("Specific name (rare)")
                        ]
                    ),
                    handler: { args in
                        let assignment = args["assignment"] as? String
                        let name = args["name"] as? String

                        TavernLogger.coordination.info("MCP summon_servitor: assignment=\(assignment ?? "<none>"), name=\(name ?? "<auto>")")

                        do {
                            let servitor: Servitor
                            if let name = name {
                                servitor = try spawner.summon(name: name, assignment: assignment)
                            } else if let assignment = assignment {
                                servitor = try spawner.summon(assignment: assignment)
                            } else {
                                servitor = try spawner.summon()
                            }

                            await onSummon(servitor)

                            TavernLogger.coordination.info("MCP summon_servitor: summoned \(servitor.name) (id: \(servitor.id))")
                            return .text("Summoned \(servitor.name) (id: \(servitor.id))")
                        } catch {
                            TavernLogger.coordination.error("MCP summon_servitor failed: \(error.localizedDescription)")
                            return .error("Failed to summon servitor: \(error.localizedDescription)")
                        }
                    }
                ),
                MCPTool(
                    name: "dismiss_servitor",
                    description: "Send a Regular home. They're off-duty, not fired.",
                    inputSchema: JSONSchema(
                        properties: [
                            "id": .string("Servitor UUID")
                        ],
                        required: ["id"]
                    ),
                    handler: { args in
                        guard let idString = args["id"] as? String,
                              let id = UUID(uuidString: idString) else {
                            TavernLogger.coordination.error("MCP dismiss_servitor: invalid servitor ID")
                            return .error("Invalid servitor ID")
                        }

                        TavernLogger.coordination.info("MCP dismiss_servitor: id=\(id)")

                        do {
                            try spawner.dismiss(id: id)
                            await onDismiss(id)

                            TavernLogger.coordination.info("MCP dismiss_servitor: dismissed \(id)")
                            return .text("Dismissed servitor \(id)")
                        } catch {
                            TavernLogger.coordination.error("MCP dismiss_servitor failed: \(error.localizedDescription)")
                            return .error("Failed to dismiss servitor: \(error.localizedDescription)")
                        }
                    }
                )
            ]
        )

        print("Created MCP server with TavernLogger handlers")

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "Say LOGGER_OK"
        options.workingDirectory = projectURL
        options.sdkMcpServers["tavern"] = testServer

        print("Creating query with logger handlers...")

        let startTime = Date()
        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say LOGGER_OK", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✓ Query created in \(String(format: "%.2f", elapsed))s")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTFail("Failed after \(String(format: "%.2f", elapsed))s: \(error)")
            try? FileManager.default.removeItem(at: projectURL)
            return
        }

        var resultContent: String?
        for try await message in query {
            if case .regular(let sdkMessage) = message {
                print("  Message: \(sdkMessage.type)")
                if sdkMessage.type == "result" {
                    resultContent = sdkMessage.content?.stringValue
                }
            }
        }

        try? FileManager.default.removeItem(at: projectURL)

        XCTAssertNotNil(resultContent, "Should have result")
        print("✓ testHandlerWithTavernLogger PASSED\n")
    }

    /// Test with handlers that capture callbacks (like onSummon/onDismiss)
    func testHandlerWithCallbackCapture() async throws {
        print("\n=== testHandlerWithCallbackCapture ===")

        // Create callbacks like Tavern does
        let onSummon: @Sendable (Servitor) async -> Void = { servitor in
            print("  onSummon called for: \(servitor.name)")
        }
        let onDismiss: @Sendable (UUID) async -> Void = { id in
            print("  onDismiss called for: \(id)")
        }

        // Create real spawner
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let projectURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-callback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )

        print("Created spawner and callbacks")

        // Create MCP server with handlers that capture BOTH spawner AND callbacks
        let testServer = SDKMCPServer(
            name: "tavern",
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "summon_servitor",
                    description: "Summon one of your Regulars",
                    inputSchema: JSONSchema(
                        properties: [
                            "assignment": .string("What you need them for"),
                            "name": .string("Specific name")
                        ]
                    ),
                    handler: { args in
                        // Capture like real Tavern handler
                        do {
                            let servitor = try spawner.summon()
                            await onSummon(servitor)
                            return .text("Summoned \(servitor.name)")
                        } catch {
                            return .error("Failed: \(error)")
                        }
                    }
                ),
                MCPTool(
                    name: "dismiss_servitor",
                    description: "Send a Regular home",
                    inputSchema: JSONSchema(
                        properties: [
                            "id": .string("Servitor UUID")
                        ],
                        required: ["id"]
                    ),
                    handler: { args in
                        guard let idString = args["id"] as? String,
                              let id = UUID(uuidString: idString) else {
                            return .error("Invalid ID")
                        }
                        do {
                            try spawner.dismiss(id: id)
                            await onDismiss(id)
                            return .text("Dismissed")
                        } catch {
                            return .error("Failed: \(error)")
                        }
                    }
                )
            ]
        )

        print("Created MCP server with full capture")

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "Say CALLBACK_OK"
        options.workingDirectory = projectURL
        options.sdkMcpServers["tavern"] = testServer

        print("Creating query with callback-capturing handlers...")

        let startTime = Date()
        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say CALLBACK_OK", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✓ Query created in \(String(format: "%.2f", elapsed))s")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTFail("Failed after \(String(format: "%.2f", elapsed))s: \(error)")
            try? FileManager.default.removeItem(at: projectURL)
            return
        }

        var resultContent: String?
        for try await message in query {
            if case .regular(let sdkMessage) = message {
                print("  Message: \(sdkMessage.type)")
                if sdkMessage.type == "result" {
                    resultContent = sdkMessage.content?.stringValue
                }
            }
        }

        try? FileManager.default.removeItem(at: projectURL)

        XCTAssertNotNil(resultContent, "Should have result")
        print("✓ testHandlerWithCallbackCapture PASSED\n")
    }

    /// Test with handlers that capture spawner (is the closure capture the issue?)
    func testHandlerWithSpawnerCapture() async throws {
        print("\n=== testHandlerWithSpawnerCapture ===")

        // Create real spawner like Tavern does
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let projectURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-capture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )

        print("Created spawner")

        // Create MCP server with handlers that CAPTURE spawner (like real Tavern)
        let testServer = SDKMCPServer(
            name: "tavern",
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "summon_servitor",
                    description: "Summon one of your Regulars",
                    inputSchema: JSONSchema(
                        properties: [
                            "assignment": .string("What you need them for"),
                            "name": .string("Specific name")
                        ]
                    ),
                    handler: { args in
                        // Capture spawner in closure like real Tavern
                        _ = spawner.servitorCount  // Force capture
                        return .text("Summoned")
                    }
                ),
                MCPTool(
                    name: "dismiss_servitor",
                    description: "Send a Regular home",
                    inputSchema: JSONSchema(
                        properties: [
                            "id": .string("Servitor UUID")
                        ],
                        required: ["id"]
                    ),
                    handler: { _ in
                        _ = spawner.servitorCount  // Force capture
                        return .text("Dismissed")
                    }
                )
            ]
        )

        print("Created MCP server with spawner-capturing handlers")

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "Say CAPTURE_OK"
        options.workingDirectory = projectURL
        options.sdkMcpServers["tavern"] = testServer

        print("Creating query with spawner-capturing handlers...")

        let startTime = Date()
        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say CAPTURE_OK", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✓ Query created in \(String(format: "%.2f", elapsed))s")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTFail("Failed after \(String(format: "%.2f", elapsed))s: \(error)")
            // Cleanup
            try? FileManager.default.removeItem(at: projectURL)
            return
        }

        var resultContent: String?
        for try await message in query {
            if case .regular(let sdkMessage) = message {
                print("  Message: \(sdkMessage.type)")
                if sdkMessage.type == "result" {
                    resultContent = sdkMessage.content?.stringValue
                }
            }
        }

        // Cleanup
        try? FileManager.default.removeItem(at: projectURL)

        XCTAssertNotNil(resultContent, "Should have result")
        print("✓ testHandlerWithSpawnerCapture PASSED\n")
    }

    /// Test calling createTavernMCPServer directly with same setup as working test
    func testCreateTavernMCPServerDirect() async throws {
        print("\n=== testCreateTavernMCPServerDirect ===")

        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let projectURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-direct-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )

        print("Created dependencies (same as working test)")

        // This is the ONLY difference - using createTavernMCPServer instead of inline
        let tavernServer = createTavernMCPServer(
            spawner: spawner,
            onSummon: { servitor in
                print("  onSummon: \(servitor.name)")
            },
            onDismiss: { id in
                print("  onDismiss: \(id)")
            }
        )

        print("Called createTavernMCPServer, got \(tavernServer.toolCount) tools")

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "You are a test assistant. Just respond with OK. Do not use any tools."  // Avoid 'summon'
        options.workingDirectory = projectURL
        options.sdkMcpServers["tavern"] = tavernServer

        print("Creating query...")

        let startTime = Date()
        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say DIRECT_OK", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✓ Query created in \(String(format: "%.2f", elapsed))s")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTFail("Failed after \(String(format: "%.2f", elapsed))s: \(error)")
            try? FileManager.default.removeItem(at: projectURL)
            return
        }

        var resultContent: String?
        for try await message in query {
            if case .regular(let sdkMessage) = message {
                print("  Message: \(sdkMessage.type)")
                if sdkMessage.type == "result" {
                    resultContent = sdkMessage.content?.stringValue
                }
            }
        }

        try? FileManager.default.removeItem(at: projectURL)

        XCTAssertNotNil(resultContent, "Should have result")
        print("✓ testCreateTavernMCPServerDirect PASSED\n")
    }

    /// Test that "summon" in system prompt causes timeout with MCP server
    /// This reproduces the exact failure condition
    func testSummonWordInSystemPromptCausesTimeout() async throws {
        print("\n=== testSummonWordInSystemPromptCausesTimeout ===")
        print("This test verifies that 'summon' in system prompt + summon_servitor tool = timeout")

        let testServer = SDKMCPServer(
            name: "tavern",
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "summon_servitor",
                    description: "Test tool",
                    inputSchema: JSONSchema(properties: [:]),
                    handler: { _ in return .text("OK") }
                )
            ]
        )

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "Don't summon anyone."  // Contains "summon" - matches tool name
        options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        options.sdkMcpServers["tavern"] = testServer

        print("System prompt: '\(options.systemPrompt ?? "")'")
        print("Tool name: 'summon_servitor'")
        print("If this times out, the hypothesis is confirmed.")

        let startTime = Date()
        do {
            // Use a shorter timeout for this test since we expect it to fail
            let query = try await ClaudeCode.query(prompt: "Say TEST", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("Query created in \(String(format: "%.2f", elapsed))s - UNEXPECTED!")

            for try await message in query {
                if case .regular(let sdkMessage) = message {
                    print("  Message: \(sdkMessage.type)")
                }
            }
            // If we get here, the hypothesis is wrong
            print("⚠️  Test completed successfully - hypothesis may be wrong")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            print("Error after \(String(format: "%.2f", elapsed))s: \(error)")
            if elapsed > 50 {
                print("✓ Timeout confirms: 'summon' in prompt + summon_servitor tool = timeout")
            }
            // Don't fail - this test is just diagnostic
        }
    }

    /// Isolate what phrase causes the timeout
    func testIsolateTimeoutPhrase() async throws {
        print("\n=== testIsolateTimeoutPhrase ===")

        let testServer = SDKMCPServer(
            name: "tavern",
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "summon_servitor",
                    description: "Test tool",
                    inputSchema: JSONSchema(properties: [:]),
                    handler: { _ in return .text("OK") }
                )
            ]
        )

        // Test different prompts to isolate the issue
        let prompts = [
            "Say OK.",               // Control - should work
            "Do not",                // No apostrophe - should work
            "Don't",                 // Apostrophe - times out
            "It's fine.",            // Different apostrophe word
            "Test'test",             // Apostrophe in middle
        ]

        for prompt in prompts {
            var options = QueryOptions()
            options.maxTurns = 1
            options.systemPrompt = prompt
            options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            options.sdkMcpServers["tavern"] = testServer

            print("\nTesting: '\(prompt)'")
            let startTime = Date()
            do {
                let query = try await ClaudeCode.query(prompt: "Say TEST", options: options)
                let elapsed = Date().timeIntervalSince(startTime)
                print("  ✓ Created in \(String(format: "%.2f", elapsed))s")

                for try await message in query {
                    if case .regular(let sdkMessage) = message {
                        if sdkMessage.type == "result" {
                            print("  ✓ Got result")
                            break
                        }
                    }
                }
            } catch {
                let elapsed = Date().timeIntervalSince(startTime)
                print("  ✗ Timeout after \(String(format: "%.2f", elapsed))s")
            }
        }
    }

    /// Test the exact configuration that Tavern uses
    func testTavernMCPServerConfiguration() async throws {
        print("\n=== testTavernMCPServerConfiguration ===")

        // Create the same MCP server configuration Tavern uses
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let projectURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )

        let tavernServer = createTavernMCPServer(
            spawner: spawner,
            onSummon: { servitor in
                print("  onSummon called for: \(servitor.name)")
            },
            onDismiss: { id in
                print("  onDismiss called for: \(id)")
            }
        )

        print("Tavern MCP server created with \(tavernServer.toolCount) tools")

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "You are Jake. Just say TAVERN_OK. Do not use any tools."
        options.workingDirectory = projectURL
        options.sdkMcpServers["tavern"] = tavernServer

        print("Creating query with Tavern MCP server...")

        let startTime = Date()
        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say TAVERN_OK", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✓ Query created in \(String(format: "%.2f", elapsed))s")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTFail("Failed to create query after \(String(format: "%.2f", elapsed))s: \(error)")
            return
        }

        print("Collecting messages...")
        var messageTypes: [String] = []
        var resultContent: String?

        let collectStart = Date()
        do {
            for try await message in query {
                let elapsed = Date().timeIntervalSince(collectStart)
                switch message {
                case .regular(let sdkMessage):
                    messageTypes.append(sdkMessage.type)
                    print("  [\(String(format: "%.2f", elapsed))s] Message: \(sdkMessage.type)")
                    if sdkMessage.type == "result" {
                        resultContent = sdkMessage.content?.stringValue
                    }
                case .controlRequest:
                    print("  [\(String(format: "%.2f", elapsed))s] Control request")
                case .controlResponse:
                    print("  [\(String(format: "%.2f", elapsed))s] Control response")
                default:
                    break
                }
            }
        } catch {
            let elapsed = Date().timeIntervalSince(collectStart)
            XCTFail("Error after \(String(format: "%.2f", elapsed))s: \(error)")
            return
        }

        let totalTime = Date().timeIntervalSince(startTime)
        print("Total time: \(String(format: "%.2f", totalTime))s")
        print("Message types: \(messageTypes)")

        XCTAssertTrue(messageTypes.contains("system"), "Should have system message")
        XCTAssertTrue(messageTypes.contains("result"), "Should have result message")
        XCTAssertNotNil(resultContent, "Should have result content")

        // Cleanup
        try? FileManager.default.removeItem(at: projectURL)

        print("✓ testTavernMCPServerConfiguration PASSED\n")
    }

    /// Test with a single tool that has properties - isolate schema issue
    func testSingleToolWithProperties() async throws {
        print("\n=== testSingleToolWithProperties ===")

        let testServer = SDKMCPServer(
            name: "test-props",
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "my_tool",
                    description: "A test tool with properties",
                    inputSchema: JSONSchema(
                        properties: [
                            "arg1": .string("First argument")
                        ]
                    ),
                    handler: { _ in
                        return MCPToolResult(content: [.text("OK")])
                    }
                )
            ]
        )

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "Say PROPS_OK"
        options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        options.sdkMcpServers["test-props"] = testServer

        print("Creating query with single tool that has properties...")

        let startTime = Date()
        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say PROPS_OK", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✓ Query created in \(String(format: "%.2f", elapsed))s")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTFail("Failed after \(String(format: "%.2f", elapsed))s: \(error)")
            return
        }

        var resultContent: String?
        for try await message in query {
            if case .regular(let sdkMessage) = message {
                print("  Message: \(sdkMessage.type)")
                if sdkMessage.type == "result" {
                    resultContent = sdkMessage.content?.stringValue
                }
            }
        }

        XCTAssertNotNil(resultContent, "Should have result")
        print("✓ testSingleToolWithProperties PASSED\n")
    }

    // MARK: - Tavern Schema Isolation Tests

    /// Test with two simple tools (is it the number of tools?)
    func testTwoSimpleTools() async throws {
        print("\n=== testTwoSimpleTools ===")

        let testServer = SDKMCPServer(
            name: "test-two",
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "tool_one",
                    description: "First tool",
                    inputSchema: JSONSchema(
                        properties: ["arg": .string("Arg one")]
                    ),
                    handler: { _ in return .text("OK") }
                ),
                MCPTool(
                    name: "tool_two",
                    description: "Second tool",
                    inputSchema: JSONSchema(
                        properties: ["arg": .string("Arg two")]
                    ),
                    handler: { _ in return .text("OK") }
                )
            ]
        )

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "Say TWO_OK"
        options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        options.sdkMcpServers["test-two"] = testServer

        print("Creating query with two simple tools...")

        let startTime = Date()
        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say TWO_OK", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✓ Query created in \(String(format: "%.2f", elapsed))s")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTFail("Failed after \(String(format: "%.2f", elapsed))s: \(error)")
            return
        }

        var resultContent: String?
        for try await message in query {
            if case .regular(let sdkMessage) = message {
                print("  Message: \(sdkMessage.type)")
                if sdkMessage.type == "result" {
                    resultContent = sdkMessage.content?.stringValue
                }
            }
        }

        XCTAssertNotNil(resultContent, "Should have result")
        print("✓ testTwoSimpleTools PASSED\n")
    }

    /// Test with summon_servitor schema exactly (is it the schema structure?)
    func testSummonServitorSchemaOnly() async throws {
        print("\n=== testSummonServitorSchemaOnly ===")

        let testServer = SDKMCPServer(
            name: "test-summon",
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "summon_servitor",
                    description: "Summon one of your Regulars to handle work. Auto-generates a name. Usually call with no params.",
                    inputSchema: JSONSchema(
                        properties: [
                            "assignment": .string("What you need them for (optional)"),
                            "name": .string("Specific name (rare)")
                        ]
                    ),
                    handler: { _ in return .text("Summoned Test (id: 12345)") }
                )
            ]
        )

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "Say SUMMON_OK"
        options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        options.sdkMcpServers["test-summon"] = testServer

        print("Creating query with summon_servitor schema...")

        let startTime = Date()
        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say SUMMON_OK", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✓ Query created in \(String(format: "%.2f", elapsed))s")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTFail("Failed after \(String(format: "%.2f", elapsed))s: \(error)")
            return
        }

        var resultContent: String?
        for try await message in query {
            if case .regular(let sdkMessage) = message {
                print("  Message: \(sdkMessage.type)")
                if sdkMessage.type == "result" {
                    resultContent = sdkMessage.content?.stringValue
                }
            }
        }

        XCTAssertNotNil(resultContent, "Should have result")
        print("✓ testSummonServitorSchemaOnly PASSED\n")
    }

    /// Test with exact "tavern" server name (is the name special?)
    func testTavernNamedServer() async throws {
        print("\n=== testTavernNamedServer ===")

        let testServer = SDKMCPServer(
            name: "tavern",  // SAME NAME as real Tavern server
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "summon_servitor",
                    description: "Summon one of your Regulars",
                    inputSchema: JSONSchema(
                        properties: [
                            "assignment": .string("What you need them for"),
                            "name": .string("Specific name")
                        ]
                    ),
                    handler: { _ in return .text("Summoned") }
                ),
                MCPTool(
                    name: "dismiss_servitor",
                    description: "Send a Regular home",
                    inputSchema: JSONSchema(
                        properties: [
                            "id": .string("Servitor UUID")
                        ],
                        required: ["id"]
                    ),
                    handler: { _ in return .text("Dismissed") }
                )
            ]
        )

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "Say NAME_OK"
        options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        options.sdkMcpServers["tavern"] = testServer

        print("Creating query with 'tavern' named server...")

        let startTime = Date()
        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say NAME_OK", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✓ Query created in \(String(format: "%.2f", elapsed))s")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTFail("Failed after \(String(format: "%.2f", elapsed))s: \(error)")
            return
        }

        var resultContent: String?
        for try await message in query {
            if case .regular(let sdkMessage) = message {
                print("  Message: \(sdkMessage.type)")
                if sdkMessage.type == "result" {
                    resultContent = sdkMessage.content?.stringValue
                }
            }
        }

        XCTAssertNotNil(resultContent, "Should have result")
        print("✓ testTavernNamedServer PASSED\n")
    }

    /// Test with both Tavern tools but minimal handlers (no spawner)
    func testBothTavernToolsMinimalHandlers() async throws {
        print("\n=== testBothTavernToolsMinimalHandlers ===")

        let testServer = SDKMCPServer(
            name: "tavern-minimal",
            version: "1.0.0",
            tools: [
                MCPTool(
                    name: "summon_servitor",
                    description: "Summon one of your Regulars to handle work. Auto-generates a name. Usually call with no params.",
                    inputSchema: JSONSchema(
                        properties: [
                            "assignment": .string("What you need them for (optional)"),
                            "name": .string("Specific name (rare)")
                        ]
                    ),
                    handler: { _ in return .text("Summoned Test (id: 12345)") }
                ),
                MCPTool(
                    name: "dismiss_servitor",
                    description: "Send a Regular home. They're off-duty, not fired.",
                    inputSchema: JSONSchema(
                        properties: [
                            "id": .string("Servitor UUID")
                        ],
                        required: ["id"]
                    ),
                    handler: { _ in return .text("Dismissed") }
                )
            ]
        )

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "Say BOTH_OK"
        options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        options.sdkMcpServers["tavern-minimal"] = testServer

        print("Creating query with both Tavern tools (minimal handlers)...")

        let startTime = Date()
        let query: ClaudeQuery
        do {
            query = try await ClaudeCode.query(prompt: "Say BOTH_OK", options: options)
            let elapsed = Date().timeIntervalSince(startTime)
            print("✓ Query created in \(String(format: "%.2f", elapsed))s")
        } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            XCTFail("Failed after \(String(format: "%.2f", elapsed))s: \(error)")
            return
        }

        var resultContent: String?
        for try await message in query {
            if case .regular(let sdkMessage) = message {
                print("  Message: \(sdkMessage.type)")
                if sdkMessage.type == "result" {
                    resultContent = sdkMessage.content?.stringValue
                }
            }
        }

        XCTAssertNotNil(resultContent, "Should have result")
        print("✓ testBothTavernToolsMinimalHandlers PASSED\n")
    }

    // MARK: - Timeout Investigation Tests

    /// Test to measure where time is spent during query
    func testQueryTimingBreakdown() async throws {
        print("\n=== testQueryTimingBreakdown ===")

        var options = QueryOptions()
        options.maxTurns = 1
        options.systemPrompt = "Say OK"
        options.workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())

        let t0 = Date()
        print("T+0.00s: Starting query...")

        let query = try await ClaudeCode.query(prompt: "OK", options: options)
        let t1 = Date()
        print("T+\(String(format: "%.2f", t1.timeIntervalSince(t0)))s: Query object created")

        var firstMessageTime: Date?
        var lastMessageTime: Date?
        var messageCount = 0

        for try await message in query {
            messageCount += 1
            let now = Date()
            if firstMessageTime == nil {
                firstMessageTime = now
                print("T+\(String(format: "%.2f", now.timeIntervalSince(t0)))s: First message received")
            }
            lastMessageTime = now

            if case .regular(let sdk) = message {
                print("T+\(String(format: "%.2f", now.timeIntervalSince(t0)))s: Message \(messageCount): \(sdk.type)")
            }
        }

        let t2 = Date()
        print("T+\(String(format: "%.2f", t2.timeIntervalSince(t0)))s: Stream completed")

        print("\nTiming Summary:")
        print("  Query creation: \(String(format: "%.2f", t1.timeIntervalSince(t0)))s")
        if let first = firstMessageTime {
            print("  Time to first message: \(String(format: "%.2f", first.timeIntervalSince(t1)))s")
        }
        if let first = firstMessageTime, let last = lastMessageTime {
            print("  Message stream duration: \(String(format: "%.2f", last.timeIntervalSince(first)))s")
        }
        print("  Total: \(String(format: "%.2f", t2.timeIntervalSince(t0)))s")

        XCTAssertGreaterThan(messageCount, 0, "Should receive messages")
        print("✓ testQueryTimingBreakdown PASSED\n")
    }
}
