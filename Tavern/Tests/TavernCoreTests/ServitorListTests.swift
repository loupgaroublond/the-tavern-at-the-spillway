import Foundation
import Testing
@testable import TavernCore

@Suite("ServitorListItem Tests")
struct ServitorListItemTests {

    // Test helper
    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @Test("Item has all required properties")
    func itemHasRequiredProperties() {
        let item = ServitorListItem(
            id: UUID(),
            name: "TestServitor",
            chatDescription: "Working on something",
            state: .working,
            isJake: false
        )

        #expect(!item.name.isEmpty)
        #expect(item.state == .working)
        #expect(item.chatDescription == "Working on something")
        #expect(!item.isJake)
    }

    @Test("Item from Jake marks isJake true")
    func itemFromJakeMarksIsJake() {
        let jake = Jake(projectURL: Self.testProjectURL(), loadSavedSession: false)
        let item = ServitorListItem.from(jake: jake)

        #expect(item.isJake == true)
        #expect(item.name == "Jake")
        #expect(item.id == jake.id)
        #expect(item.chatDescription == nil)
    }

    @Test("Item from Mortal uses chatDescription")
    func itemFromMortalUsesChatDescription() {
        let mortal = Mortal(
            name: "Frodo",
            assignment: "Carry the ring",
            chatDescription: "Ring duty",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )
        let item = ServitorListItem.from(mortal: mortal)

        #expect(item.isJake == false)
        #expect(item.name == "Frodo")
        #expect(item.chatDescription == "Ring duty")
        #expect(item.id == mortal.id)
    }

    @Test("Item from Mortal without description has nil chatDescription")
    func itemFromMortalWithoutDescription() {
        let mortal = Mortal(
            name: "Sam",
            assignment: "Help Frodo",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )
        let item = ServitorListItem.from(mortal: mortal)

        #expect(item.chatDescription == nil)
    }

    @Test("State label returns human readable text")
    func stateLabelReturnsReadableText() {
        #expect(ServitorListItem(name: "A", state: .idle).stateLabel == "Idle")
        #expect(ServitorListItem(name: "A", state: .working).stateLabel == "Working")
        #expect(ServitorListItem(name: "A", state: .waiting).stateLabel == "Needs attention")
        #expect(ServitorListItem(name: "A", state: .done).stateLabel == "Done")
        #expect(ServitorListItem(name: "A", state: .error).stateLabel == "Error")
    }

    @Test("NeedsAttention is true for waiting and error states")
    func needsAttentionForWaitingAndError() {
        #expect(ServitorListItem(name: "A", state: .idle).needsAttention == false)
        #expect(ServitorListItem(name: "A", state: .working).needsAttention == false)
        #expect(ServitorListItem(name: "A", state: .waiting).needsAttention == true)
        #expect(ServitorListItem(name: "A", state: .done).needsAttention == false)
        #expect(ServitorListItem(name: "A", state: .error).needsAttention == true)
    }
}

@Suite("ServitorListViewModel Tests")
struct ServitorListViewModelTests {

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @MainActor
    func createTestSetup() -> (ServitorListViewModel, Jake, MortalSpawner) {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let registry = ServitorRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )
        let viewModel = ServitorListViewModel(jake: jake, spawner: spawner)
        return (viewModel, jake, spawner)
    }

    @Test("List shows Jake by default", .tags(.reqUX002))
    @MainActor
    func listShowsJakeByDefault() {
        let (viewModel, jake, _) = createTestSetup()

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.isJake == true)
        #expect(viewModel.items.first?.id == jake.id)
    }

    @Test("List shows all spawned servitors", .tags(.reqUX003))
    @MainActor
    func listShowsAllSpawnedServitors() throws {
        let (viewModel, _, spawner) = createTestSetup()

        try spawner.summon(assignment: "Task 1")
        try spawner.summon(assignment: "Task 2")
        try spawner.summon(assignment: "Task 3")

        viewModel.refreshItems()

        // Jake + 3 servitors
        #expect(viewModel.items.count == 4)
        #expect(viewModel.items.first?.isJake == true)
    }

    @Test("List shows servitor state")
    @MainActor
    func listShowsServitorState() throws {
        let (viewModel, jake, _) = createTestSetup()

        #expect(viewModel.items.first?.state == jake.state)
    }

    @Test("Selection works", .tags(.reqOPM004))
    @MainActor
    func selectionWorks() throws {
        let (viewModel, jake, spawner) = createTestSetup()

        let mortal = try spawner.summon(assignment: "Test task")
        viewModel.refreshItems()

        // Initially Jake is selected
        #expect(viewModel.selectedServitorId == jake.id)
        #expect(viewModel.isSelected(id: jake.id) == true)

        // Select the spawned servitor
        viewModel.selectServitor(id: mortal.id)

        #expect(viewModel.selectedServitorId == mortal.id)
        #expect(viewModel.isSelected(id: mortal.id) == true)
        #expect(viewModel.isSelected(id: jake.id) == false)
    }

    @Test("Jake is always selected by default")
    @MainActor
    func jakeSelectedByDefault() {
        let (viewModel, jake, _) = createTestSetup()

        #expect(viewModel.selectedServitorId == jake.id)
    }

    @Test("SelectedItem returns correct item")
    @MainActor
    func selectedItemReturnsCorrectItem() throws {
        let (viewModel, jake, spawner) = createTestSetup()

        // Initially Jake
        #expect(viewModel.selectedItem?.id == jake.id)
        #expect(viewModel.selectedItem?.isJake == true)

        // After selecting another servitor
        let mortal = try spawner.summon(assignment: "Test")
        viewModel.refreshItems()
        viewModel.selectServitor(id: mortal.id)

        #expect(viewModel.selectedItem?.id == mortal.id)
        #expect(viewModel.selectedItem?.isJake == false)
    }

    @Test("ServitorsDidChange updates list")
    @MainActor
    func servitorsDidChangeUpdateslist() throws {
        let (viewModel, _, spawner) = createTestSetup()

        #expect(viewModel.items.count == 1) // Just Jake

        try spawner.summon(assignment: "Task")
        viewModel.servitorsDidChange()

        #expect(viewModel.items.count == 2) // Jake + servitor
    }

    @Test("ServitorsDidChange selects Jake when selected servitor removed")
    @MainActor
    func servitorsDidChangeSelectsJakeWhenSelectedRemoved() throws {
        let (viewModel, jake, spawner) = createTestSetup()

        let mortal = try spawner.summon(assignment: "Task")
        viewModel.refreshItems()
        viewModel.selectServitor(id: mortal.id)

        #expect(viewModel.selectedServitorId == mortal.id)

        // Remove the selected servitor
        try spawner.dismiss(mortal)
        viewModel.servitorsDidChange()

        // Should fall back to Jake
        #expect(viewModel.selectedServitorId == jake.id)
    }

    @Test("SelectServitor ignores invalid ID")
    @MainActor
    func selectServitorIgnoresInvalidId() {
        let (viewModel, jake, _) = createTestSetup()

        let fakeId = UUID()
        viewModel.selectServitor(id: fakeId)

        // Should still have Jake selected
        #expect(viewModel.selectedServitorId == jake.id)
    }

    @Test("User-spawned servitor has no assignment")
    @MainActor
    func userSpawnedServitorHasNoAssignment() throws {
        let (viewModel, _, spawner) = createTestSetup()

        let mortal = try spawner.summon()  // No assignment
        viewModel.refreshItems()

        let item = viewModel.items.first { $0.id == mortal.id }
        #expect(item != nil)
        #expect(item?.chatDescription == nil)  // No description yet
    }
}
