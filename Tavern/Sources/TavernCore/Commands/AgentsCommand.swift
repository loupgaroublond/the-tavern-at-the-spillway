import Foundation

/// /agents — List and manage configured agents
///
/// Shows all active agents in the current project with their status,
/// type, and session information.
public struct AgentsCommand: SlashCommand {
    public let name = "agents"
    public let description = "List agents and their status"
    public let usage = "/agents"

    private let agentListProvider: @MainActor @Sendable () -> [AgentListItem]

    /// Create the agents command with a provider for agent list data
    /// - Parameter agentListProvider: Closure that returns current agent list items
    public init(agentListProvider: @MainActor @escaping @Sendable () -> [AgentListItem]) {
        self.agentListProvider = agentListProvider
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let items = await MainActor.run { agentListProvider() }

        if items.isEmpty {
            return .message("No agents configured.")
        }

        var lines: [String] = ["**Agents** (\(items.count))"]
        lines.append("")

        for item in items {
            let role = item.isJake ? "Proprietor" : "Servitor"
            let stateEmoji: String
            switch item.state {
            case .idle: stateEmoji = "○"
            case .working: stateEmoji = "●"
            case .waiting: stateEmoji = "◎"
            case .verifying: stateEmoji = "◈"
            case .done: stateEmoji = "✓"
            }

            var line = "\(stateEmoji) **\(item.name)** (\(role)) — \(item.stateLabel)"
            if let desc = item.chatDescription {
                line += "\n  \(desc)"
            }
            lines.append(line)
        }

        return .message(lines.joined(separator: "\n"))
    }
}
