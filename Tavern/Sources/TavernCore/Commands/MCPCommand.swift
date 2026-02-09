import Foundation

/// /mcp — View MCP server status
///
/// Shows the status of configured MCP servers for the current project,
/// including connection state and available tools.
///
/// MCP server configuration is read from `<projectPath>/.claude/mcp.json`.
public struct MCPCommand: SlashCommand {
    public let name = "mcp"
    public let description = "View MCP server status"
    public let usage = "/mcp"

    private let projectPath: String

    /// Create the MCP command
    /// - Parameter projectPath: Path to the project root directory
    public init(projectPath: String) {
        self.projectPath = projectPath
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let mcpFile = (projectPath as NSString).appendingPathComponent(".claude/mcp.json")

        guard FileManager.default.fileExists(atPath: mcpFile) else {
            return .message("""
                **MCP Servers**

                No MCP servers configured.

                Create `.claude/mcp.json` in your project to configure MCP servers.

                Example:
                ```json
                {
                  "servers": [
                    {
                      "name": "my-tools",
                      "command": "npx",
                      "args": ["-y", "@my/mcp-tools"]
                    }
                  ]
                }
                ```
                """)
        }

        guard let data = FileManager.default.contents(atPath: mcpFile),
              let content = String(data: data, encoding: .utf8) else {
            return .error("Failed to read MCP configuration at \(mcpFile)")
        }

        // Parse and display servers
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["servers"] as? [[String: Any]] else {
            return .message("""
                **MCP Servers** (raw)

                ```json
                \(content)
                ```

                _Could not parse server configuration. Showing raw content._
                """)
        }

        var lines: [String] = ["**MCP Servers** (\(servers.count) configured)"]
        lines.append("")

        for server in servers {
            let name = server["name"] as? String ?? "unnamed"
            let command = server["command"] as? String ?? "unknown"
            let args = server["args"] as? [String] ?? []
            let argsStr = args.joined(separator: " ")

            // Built-in Tavern MCP server is always connected
            let status = "○"  // Default to unknown status (real status requires runtime check)

            lines.append("\(status) **\(name)**")
            lines.append("  Command: `\(command) \(argsStr)`")
        }

        // Always show the built-in Tavern MCP server
        lines.append("")
        lines.append("● **tavern** (built-in)")
        lines.append("  Tools: `summon_servitor`, `dismiss_servitor`")

        lines.append("")
        lines.append("Config: `.claude/mcp.json`")

        return .message(lines.joined(separator: "\n"))
    }
}
