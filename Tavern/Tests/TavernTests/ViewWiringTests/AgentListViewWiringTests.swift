import XCTest
import SwiftUI
import ViewInspector
@testable import TavernCore
@testable import Tavern

/// Grade 1-2 wiring tests: verify AgentListView correctly binds to AgentListViewModel
/// These run as unit tests (no app launch, no GUI, no focus stealing).
/// ViewInspector introspects the SwiftUI view hierarchy at test time.
@MainActor
final class AgentListViewWiringTests: XCTestCase {

    private func makeViewModel() -> AgentListViewModel {
        let projectURL = URL(fileURLWithPath: "/tmp/tavern-wiring-test")
        let jake = Jake(projectURL: projectURL, loadSavedSession: false)
        let registry = AgentRegistry()
        let nameGen = NameGenerator(theme: .lotr)
        let spawner = ServitorSpawner(
            registry: registry,
            nameGenerator: nameGen,
            projectURL: projectURL
        )
        return AgentListViewModel(jake: jake, spawner: spawner)
    }

    // MARK: - List Rendering

    /// Agent list renders and contains the list view
    func testAgentListExists() throws {
        let viewModel = makeViewModel()
        let view = AgentListView(viewModel: viewModel)

        let sut = try view.inspect()
        let list = try sut.find(viewWithAccessibilityIdentifier: "agentList")
        XCTAssertNotNil(list)
    }

    // MARK: - Spawn Button

    /// Spawn agent button exists in toolbar
    func testSpawnButtonExists() throws {
        let viewModel = makeViewModel()
        let view = AgentListView(
            viewModel: viewModel,
            onSpawnAgent: { }
        )

        let sut = try view.inspect()
        let spawnButton = try sut.find(viewWithAccessibilityIdentifier: "spawnAgentButton")
        XCTAssertNotNil(spawnButton)
    }

    // MARK: - Jake Row

    /// Jake always appears in the list as the first item
    func testJakeAppearsInList() throws {
        let viewModel = makeViewModel()
        viewModel.refreshItems()

        // Jake should be in the items list
        XCTAssertFalse(viewModel.items.isEmpty, "Items should contain at least Jake")
        XCTAssertTrue(viewModel.items[0].isJake, "First item should be Jake")
        XCTAssertEqual(viewModel.items[0].name, "Jake")
    }

    /// Jake is selected by default
    func testJakeSelectedByDefault() throws {
        let viewModel = makeViewModel()

        XCTAssertNotNil(viewModel.selectedAgentId, "Should have a selection by default")
        XCTAssertEqual(viewModel.selectedAgentId, viewModel.items.first?.id,
                       "Jake should be selected by default")
    }

    // MARK: - Selection Binding

    /// Selection binding updates when selectAgent is called
    func testSelectionBindingUpdates() throws {
        let viewModel = makeViewModel()

        // Initially Jake is selected
        let jakeId = viewModel.items[0].id

        // Selecting Jake again should keep it selected
        viewModel.selectAgent(id: jakeId)
        XCTAssertEqual(viewModel.selectedAgentId, jakeId)
    }
}
