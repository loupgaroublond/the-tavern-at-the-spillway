import Foundation

/// /servitors — List and manage configured servitors
///
/// Shows all active agents in the current project with their status,
/// type, and session information.
public struct ServitorsCommand: SlashCommand {
    public let name = "servitors"
    public let description = "List servitors and their status"
    public let usage = "/servitors"

    private let servitorListProvider: @MainActor @Sendable () -> [ServitorListItem]

    /// Create the agents command with a provider for agent list data
    /// - Parameter servitorListProvider: Closure that returns current agent list items
    public init(servitorListProvider: @MainActor @escaping @Sendable () -> [ServitorListItem]) {
        self.servitorListProvider = servitorListProvider
    }

    public func execute(arguments: String) async -> SlashCommandResult {
        let items = await MainActor.run { servitorListProvider() }

        if items.isEmpty {
            return .message("No servitors configured.")
        }

        var lines: [String] = ["**Servitors** (\(items.count))"]
        lines.append("")

        for item in items {
            let role = item.isJake ? "Proprietor" : "Mortal"
            let stateEmoji: String
            switch item.state {
            case .idle: stateEmoji = "○"
            case .working: stateEmoji = "●"
            case .waiting: stateEmoji = "◎"
            case .verifying: stateEmoji = "◈"
            case .done: stateEmoji = "✓"
            case .error: stateEmoji = "✗"
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
