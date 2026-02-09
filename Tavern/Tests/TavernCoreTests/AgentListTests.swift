import Foundation
import Testing
@testable import TavernCore

@Suite("AgentListItem Tests")
struct AgentListItemTests {

    // Test helper
    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @Test("Item has all required properties")
    func itemHasRequiredProperties() {
        let item = AgentListItem(
            id: UUID(),
            name: "TestAgent",
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
        let item = AgentListItem.from(jake: jake)

        #expect(item.isJake == true)
        #expect(item.name == "Jake")
        #expect(item.id == jake.id)
        #expect(item.chatDescription == nil)
    }

    @Test("Item from Servitor uses chatDescription")
    func itemFromServitorUsesChatDescription() {
        let agent = Servitor(
            name: "Frodo",
            assignment: "Carry the ring",
            chatDescription: "Ring duty",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )
        let item = AgentListItem.from(servitor: agent)

        #expect(item.isJake == false)
        #expect(item.name == "Frodo")
        #expect(item.chatDescription == "Ring duty")
        #expect(item.id == agent.id)
    }

    @Test("Item from Servitor without description has nil chatDescription")
    func itemFromServitorWithoutDescription() {
        let agent = Servitor(
            name: "Sam",
            assignment: "Help Frodo",
            projectURL: Self.testProjectURL(),
            loadSavedSession: false
        )
        let item = AgentListItem.from(servitor: agent)

        #expect(item.chatDescription == nil)
    }

    @Test("State label returns human readable text")
    func stateLabelReturnsReadableText() {
        #expect(AgentListItem(name: "A", state: .idle).stateLabel == "Idle")
        #expect(AgentListItem(name: "A", state: .working).stateLabel == "Working")
        #expect(AgentListItem(name: "A", state: .waiting).stateLabel == "Needs attention")
        #expect(AgentListItem(name: "A", state: .done).stateLabel == "Done")
        #expect(AgentListItem(name: "A", state: .error).stateLabel == "Error")
    }

    @Test("NeedsAttention is true for waiting and error states")
    func needsAttentionForWaitingAndError() {
        #expect(AgentListItem(name: "A", state: .idle).needsAttention == false)
        #expect(AgentListItem(name: "A", state: .working).needsAttention == false)
        #expect(AgentListItem(name: "A", state: .waiting).needsAttention == true)
        #expect(AgentListItem(name: "A", state: .done).needsAttention == false)
        #expect(AgentListItem(name: "A", state: .error).needsAttention == true)
    }
}

@Suite("AgentListViewModel Tests")
struct AgentListViewModelTests {

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    @MainActor
    func createTestSetup() -> (AgentListViewModel, Jake, ServitorSpawner) {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            projectURL: projectURL
        )
        let viewModel = AgentListViewModel(jake: jake, spawner: spawner)
        return (viewModel, jake, spawner)
    }

    @Test("List shows Jake by default")
    @MainActor
    func listShowsJakeByDefault() {
        let (viewModel, jake, _) = createTestSetup()

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.isJake == true)
        #expect(viewModel.items.first?.id == jake.id)
    }

    @Test("List shows all spawned agents")
    @MainActor
    func listShowsAllSpawnedAgents() throws {
        let (viewModel, _, spawner) = createTestSetup()

        try spawner.summon(assignment: "Task 1")
        try spawner.summon(assignment: "Task 2")
        try spawner.summon(assignment: "Task 3")

        viewModel.refreshItems()

        // Jake + 3 agents
        #expect(viewModel.items.count == 4)
        #expect(viewModel.items.first?.isJake == true)
    }

    @Test("List shows agent state")
    @MainActor
    func listShowsAgentState() throws {
        let (viewModel, jake, _) = createTestSetup()

        #expect(viewModel.items.first?.state == jake.state)
    }

    @Test("Selection works")
    @MainActor
    func selectionWorks() throws {
        let (viewModel, jake, spawner) = createTestSetup()

        let agent = try spawner.summon(assignment: "Test task")
        viewModel.refreshItems()

        // Initially Jake is selected
        #expect(viewModel.selectedAgentId == jake.id)
        #expect(viewModel.isSelected(id: jake.id) == true)

        // Select the spawned agent
        viewModel.selectAgent(id: agent.id)

        #expect(viewModel.selectedAgentId == agent.id)
        #expect(viewModel.isSelected(id: agent.id) == true)
        #expect(viewModel.isSelected(id: jake.id) == false)
    }

    @Test("Jake is always selected by default")
    @MainActor
    func jakeSelectedByDefault() {
        let (viewModel, jake, _) = createTestSetup()

        #expect(viewModel.selectedAgentId == jake.id)
    }

    @Test("SelectedItem returns correct item")
    @MainActor
    func selectedItemReturnsCorrectItem() throws {
        let (viewModel, jake, spawner) = createTestSetup()

        // Initially Jake
        #expect(viewModel.selectedItem?.id == jake.id)
        #expect(viewModel.selectedItem?.isJake == true)

        // After selecting another agent
        let agent = try spawner.summon(assignment: "Test")
        viewModel.refreshItems()
        viewModel.selectAgent(id: agent.id)

        #expect(viewModel.selectedItem?.id == agent.id)
        #expect(viewModel.selectedItem?.isJake == false)
    }

    @Test("AgentsDidChange updates list")
    @MainActor
    func agentsDidChangeUpdateslist() throws {
        let (viewModel, _, spawner) = createTestSetup()

        #expect(viewModel.items.count == 1) // Just Jake

        try spawner.summon(assignment: "Task")
        viewModel.agentsDidChange()

        #expect(viewModel.items.count == 2) // Jake + agent
    }

    @Test("AgentsDidChange selects Jake when selected agent removed")
    @MainActor
    func agentsDidChangeSelectsJakeWhenSelectedRemoved() throws {
        let (viewModel, jake, spawner) = createTestSetup()

        let agent = try spawner.summon(assignment: "Task")
        viewModel.refreshItems()
        viewModel.selectAgent(id: agent.id)

        #expect(viewModel.selectedAgentId == agent.id)

        // Remove the selected agent
        try spawner.dismiss(agent)
        viewModel.agentsDidChange()

        // Should fall back to Jake
        #expect(viewModel.selectedAgentId == jake.id)
    }

    @Test("SelectAgent ignores invalid ID")
    @MainActor
    func selectAgentIgnoresInvalidId() {
        let (viewModel, jake, _) = createTestSetup()

        let fakeId = UUID()
        viewModel.selectAgent(id: fakeId)

        // Should still have Jake selected
        #expect(viewModel.selectedAgentId == jake.id)
    }

    @Test("User-spawned agent has no assignment")
    @MainActor
    func userSpawnedAgentHasNoAssignment() throws {
        let (viewModel, _, spawner) = createTestSetup()

        let agent = try spawner.summon()  // No assignment
        viewModel.refreshItems()

        let item = viewModel.items.first { $0.id == agent.id }
        #expect(item != nil)
        #expect(item?.chatDescription == nil)  // No description yet
    }
}
