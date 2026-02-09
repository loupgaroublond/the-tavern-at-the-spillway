import Foundation
import Testing
@testable import TavernCore

@Suite("SlashCommandParser Tests")
struct SlashCommandParserTests {

    // MARK: - parse() tests

    @Test("Parses simple command without arguments")
    func parsesSimpleCommand() {
        let result = SlashCommandParser.parse("/compact")
        #expect(result == .command(name: "compact", arguments: ""))
    }

    @Test("Parses command with arguments")
    func parsesCommandWithArguments() {
        let result = SlashCommandParser.parse("/model sonnet")
        #expect(result == .command(name: "model", arguments: "sonnet"))
    }

    @Test("Parses command with multiple arguments")
    func parsesCommandWithMultipleArguments() {
        let result = SlashCommandParser.parse("/model claude-sonnet-4-5 extended")
        #expect(result == .command(name: "model", arguments: "claude-sonnet-4-5 extended"))
    }

    @Test("Command names are lowercased")
    func commandNamesLowercased() {
        let result = SlashCommandParser.parse("/COMPACT")
        #expect(result == .command(name: "compact", arguments: ""))
    }

    @Test("Trims whitespace from input")
    func trimsWhitespace() {
        let result = SlashCommandParser.parse("  /cost  ")
        #expect(result == .command(name: "cost", arguments: ""))
    }

    @Test("Trims whitespace from arguments")
    func trimsArgumentWhitespace() {
        let result = SlashCommandParser.parse("/model  sonnet  ")
        #expect(result == .command(name: "model", arguments: "sonnet"))
    }

    @Test("Regular text is not a command")
    func regularTextNotCommand() {
        let result = SlashCommandParser.parse("hello world")
        #expect(result == .notACommand)
    }

    @Test("Empty string is not a command")
    func emptyStringNotCommand() {
        let result = SlashCommandParser.parse("")
        #expect(result == .notACommand)
    }

    @Test("Whitespace-only is not a command")
    func whitespaceNotCommand() {
        let result = SlashCommandParser.parse("   ")
        #expect(result == .notACommand)
    }

    @Test("Bare slash is not a command")
    func bareSlashNotCommand() {
        let result = SlashCommandParser.parse("/")
        #expect(result == .notACommand)
    }

    @Test("Slash followed by space is not a command")
    func slashSpaceNotCommand() {
        let result = SlashCommandParser.parse("/ stuff")
        #expect(result == .notACommand)
    }

    @Test("Slash followed by digit is not a command")
    func slashDigitNotCommand() {
        let result = SlashCommandParser.parse("/123")
        #expect(result == .notACommand)
    }

    @Test("Slash in middle of text is not a command")
    func slashInMiddleNotCommand() {
        let result = SlashCommandParser.parse("hello /compact")
        #expect(result == .notACommand)
    }

    // MARK: - partialCommand() tests

    @Test("Bare slash returns empty partial for all-commands display")
    func bareSlashReturnsEmptyPartial() {
        let result = SlashCommandParser.partialCommand(from: "/")
        #expect(result == "")
    }

    @Test("Partial command returns prefix")
    func partialCommandReturnsPrefix() {
        let result = SlashCommandParser.partialCommand(from: "/com")
        #expect(result == "com")
    }

    @Test("Partial command is lowercased")
    func partialCommandLowercased() {
        let result = SlashCommandParser.partialCommand(from: "/COM")
        #expect(result == "com")
    }

    @Test("Complete word without space returns partial")
    func completeWordWithoutSpaceReturnsPartial() {
        let result = SlashCommandParser.partialCommand(from: "/compact")
        #expect(result == "compact")
    }

    @Test("Command with space returns nil (no longer autocomplete)")
    func commandWithSpaceReturnsNil() {
        let result = SlashCommandParser.partialCommand(from: "/model sonnet")
        #expect(result == nil)
    }

    @Test("Regular text returns nil")
    func regularTextReturnsNil() {
        let result = SlashCommandParser.partialCommand(from: "hello")
        #expect(result == nil)
    }

    @Test("Slash-digit returns nil")
    func slashDigitReturnsNil() {
        let result = SlashCommandParser.partialCommand(from: "/123")
        #expect(result == nil)
    }
}
