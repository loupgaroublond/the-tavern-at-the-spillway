import Foundation
import Testing
@testable import TavernCore

@Suite("Custom Command Integration Tests")
struct CustomCommandIntegrationTests {

    // MARK: - Dispatcher removeAll

    @Test("removeAll removes matching commands")
    @MainActor
    func removeAllMatching() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.registerAll([
            TestSlashCommand(name: "builtin"),
            CustomCommand(name: "custom", description: "custom", template: "", source: .project)
        ])

        #expect(dispatcher.commands.count == 2)

        dispatcher.removeAll { $0 is CustomCommand }

        #expect(dispatcher.commands.count == 1)
        #expect(dispatcher.commands[0].name == "builtin")
    }

    @Test("removeAll with no matches leaves commands unchanged")
    @MainActor
    func removeAllNoMatch() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "builtin"))

        dispatcher.removeAll { $0 is CustomCommand }

        #expect(dispatcher.commands.count == 1)
    }

    // MARK: - Custom Commands in Autocomplete

    @Test("Custom commands appear in autocomplete")
    @MainActor
    func customCommandsInAutocomplete() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "help"))
        dispatcher.register(CustomCommand(
            name: "review", description: "Review code", template: "$ARGUMENTS", source: .project
        ))

        let autocomplete = SlashCommandAutocomplete(dispatcher: dispatcher)
        autocomplete.update(for: "/r")

        #expect(autocomplete.isVisible)
        #expect(autocomplete.suggestions.count == 1)
        #expect(autocomplete.suggestions[0].name == "review")
    }

    @Test("Namespaced commands match on namespace prefix")
    @MainActor
    func namespacedAutocomplete() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.registerAll([
            CustomCommand(name: "git:amend", description: "Amend", template: "", source: .project),
            CustomCommand(name: "git:push", description: "Push", template: "", source: .project),
            CustomCommand(name: "deploy", description: "Deploy", template: "", source: .project)
        ])

        let matches = dispatcher.matchingCommands(prefix: "git:")
        #expect(matches.count == 2)
        let names = matches.map(\.name)
        #expect(names.contains("git:amend"))
        #expect(names.contains("git:push"))
    }

    @Test("Namespaced commands match on partial after colon")
    @MainActor
    func namespacedPartialMatch() {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.registerAll([
            CustomCommand(name: "git:amend", description: "Amend", template: "", source: .project),
            CustomCommand(name: "git:push", description: "Push", template: "", source: .project)
        ])

        let matches = dispatcher.matchingCommands(prefix: "git:a")
        #expect(matches.count == 1)
        #expect(matches[0].name == "git:amend")
    }

    // MARK: - Parser with Namespaced Commands

    @Test("Parser handles namespaced command names")
    func parserNamespaced() {
        let result = SlashCommandParser.parse("/git:amend --no-edit")
        #expect(result == .command(name: "git:amend", arguments: "--no-edit"))
    }

    @Test("Parser partial command with colon")
    func parserPartialWithColon() {
        let partial = SlashCommandParser.partialCommand(from: "/git:")
        #expect(partial == "git:")
    }

    @Test("Parser partial command with colon and text")
    func parserPartialWithColonAndText() {
        let partial = SlashCommandParser.partialCommand(from: "/git:am")
        #expect(partial == "git:am")
    }

    // MARK: - Custom Command Dispatch

    @Test("Custom command dispatches and substitutes arguments")
    @MainActor
    func dispatchCustomCommand() async {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(CustomCommand(
            name: "greet",
            description: "Greet someone",
            template: "Hello, $ARGUMENTS! Welcome to the Tavern.",
            source: .project
        ))

        let result = await dispatcher.dispatch(name: "greet", arguments: "World")
        #expect(result == .message("Hello, World! Welcome to the Tavern."))
    }

    @Test("Namespaced custom command dispatches correctly")
    @MainActor
    func dispatchNamespacedCommand() async {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(CustomCommand(
            name: "git:amend",
            description: "Amend last commit",
            template: "Amending commit with: $ARGUMENTS",
            source: .project
        ))

        let result = await dispatcher.dispatch(name: "git:amend", arguments: "fix typo")
        #expect(result == .message("Amending commit with: fix typo"))
    }

    // MARK: - Help Integration

    @Test("Help command lists custom commands alongside built-in")
    @MainActor
    func helpIncludesCustom() async {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.register(TestSlashCommand(name: "help", description: "List commands"))
        dispatcher.register(CustomCommand(
            name: "review",
            description: "Review code",
            template: "$ARGUMENTS",
            source: .project
        ))

        // The help command reads from dispatcher.commands
        let helpCmd = HelpCommand(dispatcher: dispatcher)
        let result = await helpCmd.execute(arguments: "")
        if case .message(let text) = result {
            #expect(text.contains("/review"))
            #expect(text.contains("Review code"))
        } else {
            Issue.record("Expected message result")
        }
    }
}
