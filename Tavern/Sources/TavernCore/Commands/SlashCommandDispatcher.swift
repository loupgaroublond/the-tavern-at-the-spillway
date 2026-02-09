import Foundation
import os.log

/// Registry and dispatcher for slash commands
///
/// Manages the set of available commands and routes parsed input to the correct handler.
/// Thread-safe via @MainActor (commands are UI operations).
@MainActor
public final class SlashCommandDispatcher: ObservableObject {

    /// All registered commands, sorted by name for autocomplete
    @Published public private(set) var commands: [any SlashCommand] = []

    public init() {}

    /// Register a slash command
    /// - Parameter command: The command to register
    public func register(_ command: any SlashCommand) {
        // Replace if already registered with same name
        commands.removeAll { $0.name == command.name }
        commands.append(command)
        commands.sort { $0.name < $1.name }
        TavernLogger.commands.info("Registered slash command: /\(command.name)")
    }

    /// Register multiple commands at once
    /// - Parameter newCommands: Commands to register
    public func registerAll(_ newCommands: [any SlashCommand]) {
        for command in newCommands {
            register(command)
        }
    }

    /// Look up a command by name
    /// - Parameter name: Command name (without slash)
    /// - Returns: The command if found
    public func command(named name: String) -> (any SlashCommand)? {
        commands.first { $0.name == name.lowercased() }
    }

    /// Dispatch a parsed command
    /// - Parameters:
    ///   - name: Command name
    ///   - arguments: Command arguments
    /// - Returns: The result of execution, or an error if command not found
    public func dispatch(name: String, arguments: String) async -> SlashCommandResult {
        guard let cmd = command(named: name) else {
            TavernLogger.commands.info("Unknown command: /\(name)")
            let available = commands.map { "/\($0.name)" }.joined(separator: ", ")
            return .error("Unknown command: /\(name)\nAvailable commands: \(available)")
        }

        TavernLogger.commands.info("Dispatching /\(name) with args: \"\(arguments)\"")
        let result = await cmd.execute(arguments: arguments)

        switch result {
        case .message(let text):
            TavernLogger.commands.debug("/\(name) completed with message (\(text.count) chars)")
        case .silent:
            TavernLogger.commands.debug("/\(name) completed silently")
        case .error(let error):
            TavernLogger.commands.debugError("/\(name) failed: \(error)")
        }

        return result
    }

    /// Remove all commands that satisfy a predicate
    /// - Parameter predicate: Closure that returns true for commands to remove
    public func removeAll(where predicate: (any SlashCommand) -> Bool) {
        commands.removeAll(where: predicate)
        TavernLogger.commands.debug("Removed commands matching predicate, \(self.commands.count) remaining")
    }

    /// Filter commands matching a partial name (for autocomplete)
    /// - Parameter prefix: Partial command name (without slash)
    /// - Returns: Matching commands sorted by name
    public func matchingCommands(prefix: String) -> [any SlashCommand] {
        if prefix.isEmpty {
            return commands
        }
        let lowered = prefix.lowercased()
        return commands.filter { $0.name.hasPrefix(lowered) }
    }
}
