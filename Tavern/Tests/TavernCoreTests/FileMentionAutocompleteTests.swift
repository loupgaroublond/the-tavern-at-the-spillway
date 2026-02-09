import Foundation
import Testing
@testable import TavernCore

@Suite("FileMentionAutocomplete Tests")
struct FileMentionAutocompleteTests {

    // MARK: - Mention Prefix Extraction

    @Suite("extractMentionPrefix")
    struct ExtractMentionPrefix {

        @Test("Bare @ returns empty string prefix")
        func bareAt() {
            let result = FileMentionAutocomplete.extractMentionPrefix(from: "@")
            #expect(result == "")
        }

        @Test("@ with partial path returns the path")
        func atWithPartialPath() {
            let result = FileMentionAutocomplete.extractMentionPrefix(from: "@Sourc")
            #expect(result == "Sourc")
        }

        @Test("@ at start of input")
        func atAtStart() {
            let result = FileMentionAutocomplete.extractMentionPrefix(from: "@Package.swift")
            #expect(result == "Package.swift")
        }

        @Test("@ after space")
        func atAfterSpace() {
            let result = FileMentionAutocomplete.extractMentionPrefix(from: "check @Sources/")
            #expect(result == "Sources/")
        }

        @Test("@ after newline")
        func atAfterNewline() {
            let result = FileMentionAutocomplete.extractMentionPrefix(from: "hello\n@Sources")
            #expect(result == "Sources")
        }

        @Test("@ in middle of word returns nil")
        func atInMiddleOfWord() {
            let result = FileMentionAutocomplete.extractMentionPrefix(from: "foo@bar")
            #expect(result == nil)
        }

        @Test("No @ returns nil")
        func noAt() {
            let result = FileMentionAutocomplete.extractMentionPrefix(from: "hello world")
            #expect(result == nil)
        }

        @Test("@ mention with space after path returns nil (completed mention)")
        func completedMention() {
            let result = FileMentionAutocomplete.extractMentionPrefix(from: "@Package.swift more text")
            #expect(result == nil)
        }

        @Test("Multiple @ signs uses the last one")
        func multipleAtSigns() {
            let result = FileMentionAutocomplete.extractMentionPrefix(from: "@old.txt @new")
            #expect(result == "new")
        }

        @Test("@ with subdirectory path")
        func subdirectoryPath() {
            let result = FileMentionAutocomplete.extractMentionPrefix(from: "@Sources/TavernCore/Chat")
            #expect(result == "Sources/TavernCore/Chat")
        }
    }

    // MARK: - Replace Active Mention

    @Suite("replaceActiveMention")
    struct ReplaceActiveMention {

        @Test("Replaces bare @ with path")
        func replacesBareAt() {
            let result = FileMentionAutocomplete.replaceActiveMention(in: "@", with: "Package.swift")
            #expect(result == "@Package.swift ")
        }

        @Test("Replaces partial mention with full path")
        func replacesPartialMention() {
            let result = FileMentionAutocomplete.replaceActiveMention(in: "@Pack", with: "Package.swift")
            #expect(result == "@Package.swift ")
        }

        @Test("Preserves text before the mention")
        func preservesPrefix() {
            let result = FileMentionAutocomplete.replaceActiveMention(in: "look at @Sour", with: "Sources/TavernCore")
            #expect(result == "look at @Sources/TavernCore ")
        }

        @Test("Returns nil when no @ present")
        func noAtReturnsNil() {
            let result = FileMentionAutocomplete.replaceActiveMention(in: "hello", with: "file.txt")
            #expect(result == nil)
        }

        @Test("Adds trailing space after inserted path")
        func addsTrailingSpace() {
            let result = FileMentionAutocomplete.replaceActiveMention(in: "@test", with: "test.swift")
            #expect(result == "@test.swift ")
            #expect(result?.hasSuffix(" ") == true)
        }
    }

    // MARK: - ViewModel Behavior (with real filesystem)

    @MainActor
    private func makeTempProject() throws -> (FileMentionAutocomplete, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("tavern-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create test files
        try "".write(to: tempDir.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try "".write(to: tempDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let srcDir = tempDir.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try "".write(to: srcDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let testsDir = tempDir.appendingPathComponent("Tests")
        try FileManager.default.createDirectory(at: testsDir, withIntermediateDirectories: true)

        let ac = FileMentionAutocomplete(projectRoot: tempDir)
        return (ac, tempDir)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Starts hidden with no suggestions")
    @MainActor
    func startsHidden() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        #expect(ac.isVisible == false)
        #expect(ac.suggestions.isEmpty)
        #expect(ac.selectedIndex == 0)
    }

    @Test("Bare @ shows project root files")
    @MainActor
    func bareAtShowsFiles() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@")
        #expect(ac.isVisible == true)
        #expect(ac.suggestions.count >= 3) // Sources, Tests dirs + Package.swift, README.md
    }

    @Test("Partial name filters suggestions")
    @MainActor
    func partialNameFilters() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@Pack")
        #expect(ac.isVisible == true)
        let names = ac.suggestions.map(\.name)
        #expect(names.contains("Package.swift"))
        #expect(!names.contains("README.md"))
    }

    @Test("No matches hides popup")
    @MainActor
    func noMatchesHides() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@zzzznonexistent")
        #expect(ac.isVisible == false)
        #expect(ac.suggestions.isEmpty)
    }

    @Test("Regular text hides popup")
    @MainActor
    func regularTextHides() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@")
        #expect(ac.isVisible == true)

        ac.update(for: "hello")
        #expect(ac.isVisible == false)
    }

    @Test("Hide method clears state")
    @MainActor
    func hideMethod() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@")
        #expect(ac.isVisible == true)

        ac.hide()
        #expect(ac.isVisible == false)
        #expect(ac.suggestions.isEmpty)
        #expect(ac.selectedIndex == 0)
    }

    // MARK: - Keyboard Navigation

    @Test("moveDown advances selection")
    @MainActor
    func moveDownAdvances() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@")
        #expect(ac.selectedIndex == 0)
        ac.moveDown()
        #expect(ac.selectedIndex == 1)
    }

    @Test("moveDown wraps around")
    @MainActor
    func moveDownWraps() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@")
        let count = ac.suggestions.count
        for _ in 0..<count {
            ac.moveDown()
        }
        #expect(ac.selectedIndex == 0)
    }

    @Test("moveUp wraps to end")
    @MainActor
    func moveUpWraps() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@")
        ac.moveUp()
        #expect(ac.selectedIndex == ac.suggestions.count - 1)
    }

    @Test("moveDown on empty does nothing")
    @MainActor
    func moveDownEmpty() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.moveDown()
        #expect(ac.selectedIndex == 0)
    }

    // MARK: - Completion

    @Test("selectedCompletion returns replacement text")
    @MainActor
    func selectedCompletion() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@Pack")
        let completion = ac.selectedCompletion(for: "@Pack")
        #expect(completion != nil)
        #expect(completion?.hasPrefix("@") == true)
        #expect(completion?.hasSuffix(" ") == true)
    }

    @Test("selectedCompletion returns nil when hidden")
    @MainActor
    func selectedCompletionWhenHidden() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        let completion = ac.selectedCompletion(for: "@Pack")
        #expect(completion == nil)
    }

    @Test("Update resets selection to 0")
    @MainActor
    func updateResetsSelection() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@")
        ac.moveDown()
        ac.moveDown()
        #expect(ac.selectedIndex == 2)

        ac.update(for: "@P")
        #expect(ac.selectedIndex == 0)
    }

    @Test("Subdirectory scanning works")
    @MainActor
    func subdirectoryScanning() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@Sources/")
        #expect(ac.isVisible == true)
        let names = ac.suggestions.map(\.name)
        #expect(names.contains("main.swift"))
    }

    @Test("Directories marked correctly in suggestions")
    @MainActor
    func directoriesMarked() throws {
        let (ac, tempDir) = try makeTempProject()
        defer { cleanup(tempDir) }

        ac.update(for: "@Sour")
        #expect(ac.isVisible == true)
        let sourcesSuggestion = ac.suggestions.first { $0.name == "Sources" }
        #expect(sourcesSuggestion?.isDirectory == true)
    }
}
