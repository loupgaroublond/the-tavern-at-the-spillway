import Foundation

/// /hooks — View and manage lifecycle hooks
///
/// Shows configured lifecycle hooks for the current project.
/// Hooks are shell commands that run in response to agent lifecycle events
/// (e.g., on agent spawn, on task completion, on session start).
///
/// Hook configuration is stored in `<projectPath>/.claude/hooks.json`.
public struct HooksCommand: SlashCommand {
    public let name = "hooks"
    public let description = "View lifecycle hooks configuration"
    public let usage = "/hooks"

    private let projectPath: String

    /// Create the hooks command
    /// - Parameter projectPath: Path to the project root directory
    public init(projectPath: String) {
        self.projectPath = projectPath
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let hooksFile = (projectPath as NSString).appendingPathComponent(".claude/hooks.json")

        guard FileManager.default.fileExists(atPath: hooksFile) else {
            return .message("""
                **Hooks**

                No hooks configured.

                Create `.claude/hooks.json` in your project to define lifecycle hooks.

                Example:
                ```json
                {
                  "hooks": [
                    {
                      "event": "agent.spawn",
                      "command": "echo 'Agent spawned'"
                    }
                  ]
                }
                ```
                """)
        }

        guard let data = FileManager.default.contents(atPath: hooksFile),
              let content = String(data: data, encoding: .utf8) else {
            return .error("Failed to read hooks configuration at \(hooksFile)")
        }

        // Parse and display hooks
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [[String: Any]] else {
            return .message("""
                **Hooks** (raw)

                ```json
                \(content)
                ```

                _Could not parse hooks structure. Showing raw content._
                """)
        }

        var lines: [String] = ["**Hooks** (\(hooks.count) configured)"]
        lines.append("")

        for (index, hook) in hooks.enumerated() {
            let event = hook["event"] as? String ?? "unknown"
            let command = hook["command"] as? String ?? "unknown"
            let enabled = hook["enabled"] as? Bool ?? true

            let status = enabled ? "●" : "○"
            lines.append("\(index + 1). \(status) **\(event)** → `\(command)`")
        }

        lines.append("")
        lines.append("Config: `.claude/hooks.json`")

        return .message(lines.joined(separator: "\n"))
    }
}
