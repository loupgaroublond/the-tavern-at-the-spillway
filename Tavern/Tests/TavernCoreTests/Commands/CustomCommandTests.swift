import Foundation
import Testing
@testable import TavernCore

@Suite("CustomCommand Tests")
struct CustomCommandTests {

    // MARK: - Argument Substitution

    @Test("$ARGUMENTS replaced with full argument string")
    func argumentsSubstitution() {
        let result = CustomCommand.substitute(
            template: "Review this: $ARGUMENTS",
            arguments: "file.swift --strict"
        )
        #expect(result == "Review this: file.swift --strict")
    }

    @Test("$ARGUMENTS replaced with empty string when no arguments")
    func argumentsSubstitutionEmpty() {
        let result = CustomCommand.substitute(
            template: "Review this: $ARGUMENTS",
            arguments: ""
        )
        #expect(result == "Review this: ")
    }

    @Test("Multiple $ARGUMENTS occurrences all replaced")
    func multipleArgumentsSubstitution() {
        let result = CustomCommand.substitute(
            template: "First: $ARGUMENTS\nSecond: $ARGUMENTS",
            arguments: "hello"
        )
        #expect(result == "First: hello\nSecond: hello")
    }

    @Test("$1 replaced with first positional argument")
    func positionalArgFirst() {
        let result = CustomCommand.substitute(
            template: "File: $1",
            arguments: "main.swift tests.swift"
        )
        #expect(result == "File: main.swift")
    }

    @Test("$2 replaced with second positional argument")
    func positionalArgSecond() {
        let result = CustomCommand.substitute(
            template: "From $1 to $2",
            arguments: "main develop"
        )
        #expect(result == "From main to develop")
    }

    @Test("Missing positional args replaced with empty string")
    func missingPositionalArg() {
        let result = CustomCommand.substitute(
            template: "A=$1 B=$2 C=$3",
            arguments: "only-one"
        )
        #expect(result == "A=only-one B= C=")
    }

    @Test("No arguments means all positional placeholders become empty")
    func noArgumentsPositional() {
        let result = CustomCommand.substitute(
            template: "A=$1 B=$2",
            arguments: ""
        )
        #expect(result == "A= B=")
    }

    @Test("Mixed $ARGUMENTS and positional placeholders")
    func mixedSubstitution() {
        let result = CustomCommand.substitute(
            template: "All: $ARGUMENTS\nFirst: $1\nSecond: $2",
            arguments: "alpha beta"
        )
        #expect(result == "All: alpha beta\nFirst: alpha\nSecond: beta")
    }

    @Test("Template without placeholders passes through unchanged")
    func noPlaceholders() {
        let result = CustomCommand.substitute(
            template: "Just some text with no placeholders",
            arguments: "ignored"
        )
        #expect(result == "Just some text with no placeholders")
    }

    @Test("$10 and above handled correctly (no collision with $1)")
    func doubleDigitPositional() {
        let args = (1...10).map { "arg\($0)" }.joined(separator: " ")
        let result = CustomCommand.substitute(
            template: "First: $1, Tenth: $10",
            arguments: args
        )
        #expect(result == "First: arg1, Tenth: arg10")
    }

    // MARK: - Command Properties

    @Test("Usage includes [arguments] when template has $ARGUMENTS")
    func usageWithArguments() {
        let cmd = CustomCommand(
            name: "review",
            description: "Review code",
            template: "Review: $ARGUMENTS",
            source: .project
        )
        #expect(cmd.usage == "/review [arguments]")
    }

    @Test("Usage includes [arguments] when template has positional placeholders")
    func usageWithPositional() {
        let cmd = CustomCommand(
            name: "deploy",
            description: "Deploy to env",
            template: "Deploy $1 to $2",
            source: .project
        )
        #expect(cmd.usage == "/deploy [arguments]")
    }

    @Test("Usage is simple when no placeholders")
    func usageWithoutPlaceholders() {
        let cmd = CustomCommand(
            name: "status",
            description: "Show status",
            template: "Show the current project status.",
            source: .user
        )
        #expect(cmd.usage == "/status")
    }

    // MARK: - Execution

    @Test("Execute returns template with substituted arguments")
    func executeSubstitutes() async {
        let cmd = CustomCommand(
            name: "greet",
            description: "Greet",
            template: "Hello, $ARGUMENTS!",
            source: .project
        )
        let result = await cmd.execute(arguments: "World")
        #expect(result == .message("Hello, World!"))
    }

    @Test("Source is preserved")
    func sourcePreserved() {
        let projectCmd = CustomCommand(name: "a", description: "a", template: "", source: .project)
        let userCmd = CustomCommand(name: "b", description: "b", template: "", source: .user)
        #expect(projectCmd.source == .project)
        #expect(userCmd.source == .user)
    }
}
