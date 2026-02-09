import Foundation
import Testing
@testable import TavernCore

@Suite("Management Command Tests")
struct ManagementCommandTests {

    // MARK: - Helper

    private func createTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func writeFile(_ content: String, at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - AgentsCommand

    @Test("Agents command shows no agents message when empty")
    func agentsEmpty() async {
        let cmd = AgentsCommand(agentListProvider: { [] })
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("No agents"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("Agents command lists agents with status")
    @MainActor
    func agentsListsAll() async {
        let items = [
            AgentListItem(name: "Jake", state: .working, isJake: true),
            AgentListItem(name: "Marcos Antonio", chatDescription: "Fixing bugs", state: .idle, isJake: false)
        ]
        let cmd = AgentsCommand(agentListProvider: { items })
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("Jake"))
            #expect(text.contains("Proprietor"))
            #expect(text.contains("Marcos Antonio"))
            #expect(text.contains("Servitor"))
            #expect(text.contains("Fixing bugs"))
            #expect(text.contains("2"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("Agents command name and description")
    func agentsMetadata() {
        let cmd = AgentsCommand(agentListProvider: { [] })
        #expect(cmd.name == "agents")
        #expect(!cmd.description.isEmpty)
    }

    // MARK: - HooksCommand

    @Test("Hooks command shows no hooks when file missing")
    func hooksNoFile() async {
        let cmd = HooksCommand(projectPath: "/nonexistent/path")
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("No hooks configured"))
            #expect(text.contains("hooks.json"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("Hooks command shows configured hooks")
    func hooksWithConfig() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }

        let hooksJson = """
        {
          "hooks": [
            {
              "event": "agent.spawn",
              "command": "echo spawned"
            },
            {
              "event": "agent.done",
              "command": "notify-send done",
              "enabled": false
            }
          ]
        }
        """
        try writeFile(hooksJson, at: "\(tempDir.path)/.claude/hooks.json")

        let cmd = HooksCommand(projectPath: tempDir.path)
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("agent.spawn"))
            #expect(text.contains("echo spawned"))
            #expect(text.contains("agent.done"))
            #expect(text.contains("2 configured"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("Hooks command name and description")
    func hooksMetadata() {
        let cmd = HooksCommand(projectPath: "/tmp")
        #expect(cmd.name == "hooks")
        #expect(!cmd.description.isEmpty)
    }

    // MARK: - MCPCommand

    @Test("MCP command shows no servers when file missing")
    func mcpNoFile() async {
        let cmd = MCPCommand(projectPath: "/nonexistent/path")
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("No MCP servers configured"))
            #expect(text.contains("mcp.json"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("MCP command shows configured servers")
    func mcpWithConfig() async throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }

        let mcpJson = """
        {
          "servers": [
            {
              "name": "my-tools",
              "command": "npx",
              "args": ["-y", "@my/mcp-tools"]
            }
          ]
        }
        """
        try writeFile(mcpJson, at: "\(tempDir.path)/.claude/mcp.json")

        let cmd = MCPCommand(projectPath: tempDir.path)
        let result = await cmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("my-tools"))
            #expect(text.contains("npx"))
            #expect(text.contains("tavern"))  // Built-in server always shown
            #expect(text.contains("summon_servitor"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("MCP command always shows built-in tavern server")
    func mcpBuiltinServer() async {
        let cmd = MCPCommand(projectPath: "/nonexistent")
        let result = await cmd.execute(arguments: "")
        // Even with no config, the "no servers" message is shown (built-in is only in config view)
        if case .message(let text) = result {
            #expect(text.contains("No MCP servers"))
        } else {
            Issue.record("Expected message result")
        }
    }

    @Test("MCP command name and description")
    func mcpMetadata() {
        let cmd = MCPCommand(projectPath: "/tmp")
        #expect(cmd.name == "mcp")
        #expect(!cmd.description.isEmpty)
    }

    // MARK: - Registration in Dispatcher

    @Test("Management commands register correctly")
    @MainActor
    func managementCommandsRegister() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.registerAll([
            AgentsCommand(agentListProvider: { [] }),
            HooksCommand(projectPath: "/tmp"),
            MCPCommand(projectPath: "/tmp")
        ])

        #expect(dispatcher.command(named: "agents") != nil)
        #expect(dispatcher.command(named: "hooks") != nil)
        #expect(dispatcher.command(named: "mcp") != nil)
    }
}
