import Foundation
import Testing
@testable import TavernCore

/// A test command that records its executions
struct TestSlashCommand: SlashCommand {
    let name: String
    let description: String
    let fixedResult: SlashCommandResult

    init(name: String, description: String = "Test command", result: SlashCommandResult = .message("ok")) {
        self.name = name
        self.description = description
        self.fixedResult = result
    }

    func execute(arguments: String) async -> SlashCommandResult {
        fixedResult
    }
}

@Suite("SlashCommandDispatcher Tests")
struct SlashCommandDispatcherTests {

    @Test("Register and look up a command")
    @MainActor
    func registerAndLookup() {
        let dispatcher = SlashCommandDispatcher()
        let cmd = TestSlashCommand(name: "test")

        dispatcher.register(cmd)

        let found = dispatcher.command(named: "test")
        #expect(found?.name == "test")
    }

    @Test("Lookup is case-insensitive")
    @MainActor
    func lookupCaseInsensitive() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "compact"))

        let found = dispatcher.command(named: "COMPACT")
        #expect(found?.name == "compact")
    }

    @Test("Unknown command returns nil from lookup")
    @MainActor
    func unknownCommandReturnsNil() {
        let dispatcher = SlashCommandDispatcher()

        let found = dispatcher.command(named: "nonexistent")
        #expect(found == nil)
    }

    @Test("Dispatch routes to correct command")
    @MainActor
    func dispatchRoutesToCommand() async {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "test", result: .message("hello from test")))

        let result = await dispatcher.dispatch(name: "test", arguments: "")
        #expect(result == .message("hello from test"))
    }

    @Test("Dispatch unknown command returns error")
    @MainActor
    func dispatchUnknownReturnsError() async {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "known"))

        let result = await dispatcher.dispatch(name: "unknown", arguments: "")
        if case .error(let msg) = result {
            #expect(msg.contains("Unknown command: /unknown"))
            #expect(msg.contains("/known"))
        } else {
            Issue.record("Expected error result, got \(result)")
        }
    }

    @Test("Commands are sorted by name")
    @MainActor
    func commandsSortedByName() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "zebra"))
        dispatcher.register(TestSlashCommand(name: "alpha"))
        dispatcher.register(TestSlashCommand(name: "middle"))

        let names = dispatcher.commands.map(\.name)
        #expect(names == ["alpha", "middle", "zebra"])
    }

    @Test("Re-registering same name replaces command")
    @MainActor
    func reRegisterReplacesCommand() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "test", description: "first"))
        dispatcher.register(TestSlashCommand(name: "test", description: "second"))

        #expect(dispatcher.commands.count == 1)
        #expect(dispatcher.commands[0].description == "second")
    }

    @Test("registerAll registers multiple commands")
    @MainActor
    func registerAllMultiple() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.registerAll([
            TestSlashCommand(name: "alpha"),
            TestSlashCommand(name: "beta"),
            TestSlashCommand(name: "gamma")
        ])

        #expect(dispatcher.commands.count == 3)
    }

    // MARK: - Autocomplete filtering

    @Test("Empty prefix returns all commands")
    @MainActor
    func emptyPrefixReturnsAll() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.registerAll([
            TestSlashCommand(name: "compact"),
            TestSlashCommand(name: "cost"),
            TestSlashCommand(name: "status")
        ])

        let matches = dispatcher.matchingCommands(prefix: "")
        #expect(matches.count == 3)
    }

    @Test("Prefix filters matching commands")
    @MainActor
    func prefixFiltersCommands() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.registerAll([
            TestSlashCommand(name: "compact"),
            TestSlashCommand(name: "cost"),
            TestSlashCommand(name: "context"),
            TestSlashCommand(name: "status")
        ])

        let matches = dispatcher.matchingCommands(prefix: "co")
        let names = matches.map(\.name)
        #expect(names == ["compact", "context", "cost"])
    }

    @Test("Prefix filtering is case-insensitive")
    @MainActor
    func prefixFilteringCaseInsensitive() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "compact"))

        let matches = dispatcher.matchingCommands(prefix: "COM")
        #expect(matches.count == 1)
        #expect(matches[0].name == "compact")
    }

    @Test("No matches returns empty array")
    @MainActor
    func noMatchesReturnsEmpty() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "compact"))

        let matches = dispatcher.matchingCommands(prefix: "zzz")
        #expect(matches.isEmpty)
    }
}
