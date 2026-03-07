import Foundation
import Testing
import ClodKit
@testable import TavernCore

// MARK: - Provenance: REQ-ARCH-009, REQ-DET-003

@Suite("MCP Server Management", .timeLimit(.minutes(1)))
struct MCPManagementTests {

    // MARK: - Helpers

    private func makeDirectory() throws -> ProjectDirectory {
        try TestFixtures.createTestDirectory()
    }

    private func makeRecord(
        name: String = "TestServitor",
        id: UUID = UUID(),
        mcpServers: [String: MCPServerEntry] = [:]
    ) -> ServitorRecord {
        ServitorRecord(
            name: name,
            id: id,
            mcpServers: mcpServers
        )
    }

    // MARK: - MCP Config Persistence Tests

    @Test("MCP config parsed from markdown JSON code block", .tags(.reqARCH009))
    func testMCPConfigParsedFromMarkdown() throws {
        let directory = try makeDirectory()

        let mcpServers: [String: MCPServerEntry] = [
            "filesystem": MCPServerEntry(
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
                env: ["NODE_ENV": "production"]
            ),
            "github": MCPServerEntry(
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-github"],
                env: nil
            )
        ]

        let record = makeRecord(name: "MCPTester", mcpServers: mcpServers)
        try directory.saveServitor(record)

        // Verify the file contains the JSON code block
        let fileURL = directory.servitorURL(name: "MCPTester").appendingPathComponent("servitor.md")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content.contains("```json mcp-servers"))
        #expect(content.contains("filesystem"))
        #expect(content.contains("github"))
        #expect(content.contains("```"))

        // Round-trip: load back and verify
        let loaded = try #require(try directory.loadServitor(name: "MCPTester"))
        #expect(loaded.mcpServers.count == 2)

        let fs = try #require(loaded.mcpServers["filesystem"])
        #expect(fs.command == "npx")
        #expect(fs.args == ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"])
        #expect(fs.env == ["NODE_ENV": "production"])

        let gh = try #require(loaded.mcpServers["github"])
        #expect(gh.command == "npx")
        #expect(gh.args == ["-y", "@modelcontextprotocol/server-github"])
        #expect(gh.env == nil)
    }

    @Test("Empty default MCP config for new servitors", .tags(.reqARCH009))
    func testEmptyDefaultMCPConfig() throws {
        let directory = try makeDirectory()

        let record = makeRecord(name: "PlainServitor")
        try directory.saveServitor(record)

        let loaded = try #require(try directory.loadServitor(name: "PlainServitor"))
        #expect(loaded.mcpServers.isEmpty)

        // Verify no MCP block in the file
        let fileURL = directory.servitorURL(name: "PlainServitor").appendingPathComponent("servitor.md")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(!content.contains("mcp-servers"))
    }

    @Test("MCP config survives save-load round-trip alongside other fields", .tags(.reqARCH009))
    func testMCPConfigWithOtherFields() throws {
        let directory = try makeDirectory()
        let id = UUID()

        let record = ServitorRecord(
            name: "FullServitor",
            id: id,
            assignment: "Build things",
            sessionId: "sess-abc",
            sessionMode: .acceptEdits,
            description: "A worker with MCP servers",
            mcpServers: [
                "test-server": MCPServerEntry(command: "/usr/bin/test-server", args: ["--port", "8080"])
            ]
        )

        try directory.saveServitor(record)
        let loaded = try #require(try directory.loadServitor(name: "FullServitor"))

        #expect(loaded.id == id)
        #expect(loaded.assignment == "Build things")
        #expect(loaded.sessionId == "sess-abc")
        #expect(loaded.sessionMode == .acceptEdits)
        #expect(loaded.description == "A worker with MCP servers")
        #expect(loaded.mcpServers.count == 1)

        let server = try #require(loaded.mcpServers["test-server"])
        #expect(server.command == "/usr/bin/test-server")
        #expect(server.args == ["--port", "8080"])
    }

    // MARK: - Jake Always Has Tavern Server

    @Test("Jake always has tavern server in MCP config", .tags(.reqARCH009))
    func testJakeAlwaysHasTavernServer() async throws {
        let url = try TestFixtures.createTempDirectory()
        let mock = MockMessenger(responses: ["Hello from Jake!"])
        let jake = Jake(projectURL: url, messenger: mock)

        // Inject the tavern MCP server (normally done by TavernProject)
        let tavernServer = SDKMCPServer(name: "tavern", tools: [])
        jake.mcpServer = tavernServer

        // Send a message to trigger query
        _ = try await jake.send("test")

        // The tavern server is always present in sdkMcpServers
        let options = try #require(mock.queryOptions.first)
        #expect(options.sdkMcpServers["tavern"] != nil)
    }

    @Test("Jake merges tavern server with user-configured external servers", .tags(.reqARCH009))
    func testJakeMergesBuiltInWithUserConfigured() async throws {
        let url = try TestFixtures.createTempDirectory()
        let mock = MockMessenger(responses: ["Hello!"])
        let jake = Jake(projectURL: url, messenger: mock)

        // Set the built-in tavern MCP server
        let tavernServer = SDKMCPServer(name: "tavern", tools: [])
        jake.mcpServer = tavernServer

        // Set user-configured external MCP servers
        jake.externalMCPServers = [
            "filesystem": MCPServerConfig(command: "npx", args: ["-y", "server-fs"])
        ]

        _ = try await jake.send("test")

        let options = try #require(mock.queryOptions.first)
        // Built-in tavern server is in sdkMcpServers
        #expect(options.sdkMcpServers["tavern"] != nil)
        // External server is in mcpServers
        #expect(options.mcpServers["filesystem"] != nil)
        #expect(options.mcpServers["filesystem"]?.command == "npx")
    }

    // MARK: - MCPServerEntry → MCPServerConfig Conversion

    @Test("MCPServerEntry converts to MCPServerConfig correctly")
    func testMCPServerEntryConversion() {
        let entry = MCPServerEntry(
            command: "node",
            args: ["server.js", "--port", "3000"],
            env: ["TOKEN": "secret"]
        )

        let config = entry.toMCPServerConfig()
        #expect(config.command == "node")
        #expect(config.args == ["server.js", "--port", "3000"])
        #expect(config.env == ["TOKEN": "secret"])
    }

    @Test("Dictionary of MCPServerEntry converts to MCPServerConfig dictionary")
    func testDictionaryConversion() {
        let entries: [String: MCPServerEntry] = [
            "a": MCPServerEntry(command: "cmd-a"),
            "b": MCPServerEntry(command: "cmd-b", args: ["--verbose"])
        ]

        let configs = entries.toMCPServerConfigs()
        #expect(configs.count == 2)
        #expect(configs["a"]?.command == "cmd-a")
        #expect(configs["b"]?.command == "cmd-b")
        #expect(configs["b"]?.args == ["--verbose"])
    }

    // MARK: - MCP Runtime Control (Mock)

    @Test("MCP status queried through mock messenger", .tags(.reqARCH009))
    func testMCPStatusQueried() async throws {
        let mock = MockMessenger(responses: ["response"])
        mock.mcpStatuses = [
            McpServerStatus(name: "tavern", status: "connected"),
            McpServerStatus(name: "filesystem", status: "failed", error: "Connection refused")
        ]

        let statuses = try await mock.mcpServerStatus()
        #expect(statuses.count == 2)
        #expect(statuses[0].name == "tavern")
        #expect(statuses[0].status == "connected")
        #expect(statuses[1].name == "filesystem")
        #expect(statuses[1].status == "failed")
        #expect(statuses[1].error == "Connection refused")
        #expect(mock.mcpStatusCalls == 1)
    }

    @Test("Server reconnect called through mock messenger", .tags(.reqARCH009))
    func testServerReconnectCalled() async throws {
        let mock = MockMessenger(responses: ["response"])

        try await mock.reconnectMcpServer(name: "filesystem")
        try await mock.reconnectMcpServer(name: "github")

        #expect(mock.reconnectCalls == ["filesystem", "github"])
    }

    @Test("Server toggle called through mock messenger", .tags(.reqARCH009))
    func testServerToggleCalled() async throws {
        let mock = MockMessenger(responses: ["response"])

        try await mock.toggleMcpServer(name: "filesystem", enabled: false)
        try await mock.toggleMcpServer(name: "filesystem", enabled: true)

        #expect(mock.toggleCalls.count == 2)
        #expect(mock.toggleCalls[0].name == "filesystem")
        #expect(mock.toggleCalls[0].enabled == false)
        #expect(mock.toggleCalls[1].name == "filesystem")
        #expect(mock.toggleCalls[1].enabled == true)
    }

    // MARK: - ClodSession MCP Runtime Control

    @Test("ClodSession routes MCP status through messenger", .tags(.reqARCH009))
    func testClodSessionMCPStatus() async throws {
        let mock = MockMessenger()
        mock.mcpStatuses = [McpServerStatus(name: "tavern", status: "connected")]

        let config = ClodSession.Config(
            systemPrompt: "test",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            servitorName: "test"
        )
        let session = ClodSession(config: config, messenger: mock)

        let statuses = try await session.mcpServerStatus()
        #expect(statuses.count == 1)
        #expect(statuses[0].name == "tavern")
        #expect(mock.mcpStatusCalls == 1)
    }

    @Test("ClodSession routes reconnect through messenger", .tags(.reqARCH009))
    func testClodSessionReconnect() async throws {
        let mock = MockMessenger()
        let config = ClodSession.Config(
            systemPrompt: "test",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            servitorName: "test"
        )
        let session = ClodSession(config: config, messenger: mock)

        try await session.reconnectMcpServer(name: "test-server")
        #expect(mock.reconnectCalls == ["test-server"])
    }

    @Test("ClodSession routes toggle through messenger", .tags(.reqARCH009))
    func testClodSessionToggle() async throws {
        let mock = MockMessenger()
        let config = ClodSession.Config(
            systemPrompt: "test",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            servitorName: "test"
        )
        let session = ClodSession(config: config, messenger: mock)

        try await session.toggleMcpServer(name: "test-server", enabled: false)
        #expect(mock.toggleCalls.count == 1)
        #expect(mock.toggleCalls[0].name == "test-server")
        #expect(mock.toggleCalls[0].enabled == false)
    }

    // MARK: - External MCP Servers in buildOptions

    @Test("External MCP servers appear in query options", .tags(.reqARCH009))
    func testExternalMCPServersInQueryOptions() async throws {
        let url = try TestFixtures.createTempDirectory()
        let mock = MockMessenger(responses: ["ok"])
        let mortal = Mortal(name: "Worker", projectURL: url, messenger: mock)

        mortal.externalMCPServers = [
            "my-server": MCPServerConfig(command: "my-cmd", args: ["--flag"])
        ]

        _ = try await mortal.send("hello")

        let options = try #require(mock.queryOptions.first)
        #expect(options.mcpServers["my-server"] != nil)
        #expect(options.mcpServers["my-server"]?.command == "my-cmd")
    }
}
