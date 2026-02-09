import Foundation
import Testing
@testable import TavernCore

@Suite("SlashCommandAutocomplete Tests")
struct SlashCommandAutocompleteTests {

    @MainActor
    private func makeAutocomplete() -> (SlashCommandAutocomplete, SlashCommandDispatcher) {
        let dispatcher = SlashCommandDispatcher()
        dispatcher.registerAll([
            TestSlashCommand(name: "compact", description: "Compact context"),
            TestSlashCommand(name: "cost", description: "Token usage stats"),
            TestSlashCommand(name: "context", description: "Context usage"),
            TestSlashCommand(name: "status", description: "Show status"),
            TestSlashCommand(name: "model", description: "Change model"),
            TestSlashCommand(name: "stats", description: "Usage statistics")
        ])
        let autocomplete = SlashCommandAutocomplete(dispatcher: dispatcher)
        return (autocomplete, dispatcher)
    }

    @Test("Starts hidden with no suggestions")
    @MainActor
    func startsHidden() {
        let (ac, _) = makeAutocomplete()
        #expect(ac.isVisible == false)
        #expect(ac.suggestions.isEmpty)
        #expect(ac.selectedIndex == 0)
    }

    @Test("Bare slash shows all commands")
    @MainActor
    func bareSlashShowsAll() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/")
        #expect(ac.isVisible == true)
        #expect(ac.suggestions.count == 6)
    }

    @Test("Partial input filters commands")
    @MainActor
    func partialInputFilters() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/co")
        #expect(ac.isVisible == true)
        let names = ac.suggestions.map(\.name)
        #expect(names == ["compact", "context", "cost"])
    }

    @Test("No matches hides popup")
    @MainActor
    func noMatchesHides() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/zzz")
        #expect(ac.isVisible == false)
        #expect(ac.suggestions.isEmpty)
    }

    @Test("Regular text hides popup")
    @MainActor
    func regularTextHides() {
        let (ac, _) = makeAutocomplete()
        // First show it
        ac.update(for: "/")
        #expect(ac.isVisible == true)
        // Then type regular text
        ac.update(for: "hello")
        #expect(ac.isVisible == false)
    }

    @Test("Command with space hides popup")
    @MainActor
    func commandWithSpaceHides() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/model sonnet")
        #expect(ac.isVisible == false)
    }

    @Test("Hide method clears state")
    @MainActor
    func hideMethod() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/co")
        #expect(ac.isVisible == true)
        ac.hide()
        #expect(ac.isVisible == false)
        #expect(ac.suggestions.isEmpty)
        #expect(ac.selectedIndex == 0)
    }

    // MARK: - Keyboard Navigation

    @Test("moveDown advances selection")
    @MainActor
    func moveDownAdvances() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/co")
        #expect(ac.selectedIndex == 0)
        ac.moveDown()
        #expect(ac.selectedIndex == 1)
        ac.moveDown()
        #expect(ac.selectedIndex == 2)
    }

    @Test("moveDown wraps around")
    @MainActor
    func moveDownWraps() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/co") // 3 matches
        ac.moveDown() // 1
        ac.moveDown() // 2
        ac.moveDown() // wraps to 0
        #expect(ac.selectedIndex == 0)
    }

    @Test("moveUp wraps to end")
    @MainActor
    func moveUpWraps() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/co") // 3 matches
        ac.moveUp() // wraps to 2
        #expect(ac.selectedIndex == 2)
    }

    @Test("moveUp decrements selection")
    @MainActor
    func moveUpDecrements() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/co")
        ac.moveDown() // 1
        ac.moveDown() // 2
        ac.moveUp()   // 1
        #expect(ac.selectedIndex == 1)
    }

    @Test("moveDown on empty does nothing")
    @MainActor
    func moveDownEmpty() {
        let (ac, _) = makeAutocomplete()
        ac.moveDown()
        #expect(ac.selectedIndex == 0)
    }

    // MARK: - Selection / Completion

    @Test("selectedCompletion returns command text")
    @MainActor
    func selectedCompletion() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/co") // matches: compact, context, cost
        let completion = ac.selectedCompletion()
        #expect(completion == "/compact ")
    }

    @Test("selectedCompletion after moveDown returns correct command")
    @MainActor
    func selectedCompletionAfterMove() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/co")
        ac.moveDown() // selects "context"
        let completion = ac.selectedCompletion()
        #expect(completion == "/context ")
    }

    @Test("selectedCompletion returns nil when hidden")
    @MainActor
    func selectedCompletionWhenHidden() {
        let (ac, _) = makeAutocomplete()
        let completion = ac.selectedCompletion()
        #expect(completion == nil)
    }

    @Test("Update resets selection to 0")
    @MainActor
    func updateResetsSelection() {
        let (ac, _) = makeAutocomplete()
        ac.update(for: "/co")
        ac.moveDown()
        ac.moveDown()
        #expect(ac.selectedIndex == 2)
        ac.update(for: "/com")
        #expect(ac.selectedIndex == 0)
    }
}
