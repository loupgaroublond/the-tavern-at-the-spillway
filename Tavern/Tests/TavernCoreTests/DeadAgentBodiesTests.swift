// MARK: - Provenance: REQ-VIW-005

import Foundation
import Testing
@testable import TavernCore
import TavernKit

// MARK: - Dead Agent Bodies Tests (REQ-VIW-005)
//
// REQ-VIW-005 specifies:
//   - Dead agents leave persistent views showing their final state
//   - Dead agent views are accessible for review and debugging
//   - The user must manually dismiss dead agent views
//
// Current implementation status: NON-CONFORMANT (per attestation report).
// MortalSpawner.dismiss() removes the mortal from the registry entirely,
// so dismissed mortals vanish from the sidebar. The tests below document
// both the intended behavior (via .done state) and the current gap
// (dismiss removes rather than retains).

@Suite("Dead Agent Bodies", .tags(.reqVIW005), .timeLimit(.minutes(2)))
struct DeadAgentBodiesTests {

    // MARK: - Helpers

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    private static func makeSpawner(
        registry: ServitorRegistry = ServitorRegistry(),
        projectURL: URL? = nil
    ) -> MortalSpawner {
        MortalSpawner(
            registry: registry,
            nameGenerator: NameGenerator(theme: .lotr),
            projectURL: projectURL ?? testProjectURL(),
            messengerFactory: { _ in MockMessenger() }
        )
    }

    // MARK: - ServitorListItem dead state representation

    @Test("Done state has distinct label from active states")
    func doneStateHasDistinctLabel() {
        let doneItem = ServitorListItem(name: "Finished", state: .done)
        let idleItem = ServitorListItem(name: "Active", state: .idle)
        let workingItem = ServitorListItem(name: "Busy", state: .working)

        #expect(doneItem.stateLabel == "Done")
        #expect(doneItem.stateLabel != idleItem.stateLabel)
        #expect(doneItem.stateLabel != workingItem.stateLabel)
    }

    @Test("Done servitors do not flag needsAttention")
    func doneServitorsDoNotNeedAttention() {
        let doneItem = ServitorListItem(name: "Finished", state: .done)
        #expect(doneItem.needsAttention == false)
    }

    @Test("Done state is distinguishable from all other states")
    func doneStateIsDistinguishable() {
        let allStates: [ServitorState] = [.idle, .working, .waiting, .verifying, .error]
        let doneItem = ServitorListItem(name: "Dead", state: .done)

        for otherState in allStates {
            let otherItem = ServitorListItem(name: "Other", state: otherState)
            #expect(doneItem.state != otherItem.state,
                    "Done state must differ from \(otherState)")
        }
    }

    // MARK: - Mortal completion marks done state

    @Test("Mortal marked done has done state")
    func mortalMarkedDoneHasDoneState() {
        let mortal = Mortal(
            name: "Worker",
            assignment: "Do something",
            projectURL: Self.testProjectURL()
        )

        mortal.markDone()

        #expect(mortal.state == .done)
    }

    @Test("Done mortal produces done ServitorListItem")
    func doneMortalProducesDoneListItem() {
        let mortal = Mortal(
            name: "Worker",
            assignment: "Do something",
            projectURL: Self.testProjectURL()
        )

        mortal.markDone()

        let item = ServitorListItem.from(mortal: mortal)
        #expect(item.state == .done)
        #expect(item.stateLabel == "Done")
    }

    @Test("Done state is terminal - resetConversation does not revert it")
    func doneStateIsTerminal() {
        let mortal = Mortal(
            name: "Worker",
            assignment: "Do something",
            projectURL: Self.testProjectURL()
        )

        mortal.markDone()
        mortal.resetConversation()

        #expect(mortal.state == .done,
                "Done is a terminal state; resetConversation must not revert it")
    }

    // MARK: - List shows both alive and done servitors

    @Test("List contains both active and done servitors")
    @MainActor func listContainsBothActiveAndDone() throws {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL)
        let registry = ServitorRegistry()
        let spawner = Self.makeSpawner(registry: registry, projectURL: projectURL)

        _ = try spawner.summon(name: "Active-Worker", assignment: "Task A")
        let mortal2 = try spawner.summon(name: "Done-Worker", assignment: "Task B")
        mortal2.markDone()

        let viewModel = ServitorListViewModel(jake: jake, spawner: spawner)

        // Jake + 2 mortals = 3 items
        #expect(viewModel.items.count == 3)

        let activeItem = viewModel.items.first { $0.name == "Active-Worker" }
        let doneItem = viewModel.items.first { $0.name == "Done-Worker" }

        #expect(activeItem != nil)
        #expect(doneItem != nil)
        #expect(activeItem?.state == .idle)
        #expect(doneItem?.state == .done)
    }

    @Test("Done servitors remain selectable")
    @MainActor func doneServitorsRemainSelectable() throws {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL)
        let registry = ServitorRegistry()
        let spawner = Self.makeSpawner(registry: registry, projectURL: projectURL)

        let mortal = try spawner.summon(name: "Done-Worker", assignment: "Task")
        mortal.markDone()

        let viewModel = ServitorListViewModel(jake: jake, spawner: spawner)
        viewModel.selectServitor(id: mortal.id)

        #expect(viewModel.selectedServitorId == mortal.id)
        #expect(viewModel.selectedItem?.state == .done)
    }

    // MARK: - Dismiss behavior (documents current gap)

    @Test("Dismissed mortal is removed from active list — GAP: REQ-VIW-005 requires retention")
    @MainActor func dismissedMortalIsRemovedFromActiveList() throws {
        // NOTE: REQ-VIW-005 requires that dead agents remain visible in the
        // sidebar until the user manually dismisses them. The current
        // implementation removes them immediately. This test documents the
        // current (non-conformant) behavior.

        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL)
        let registry = ServitorRegistry()
        let spawner = Self.makeSpawner(registry: registry, projectURL: projectURL)

        let mortal = try spawner.summon(name: "Soon-Dead", assignment: "Task")
        mortal.markDone()

        // Verify it's in the list before dismiss
        let viewModel = ServitorListViewModel(jake: jake, spawner: spawner)
        #expect(viewModel.items.contains { $0.name == "Soon-Dead" })

        // Dismiss removes from registry
        try spawner.dismiss(mortal)
        viewModel.servitorsDidChange()

        // Current behavior: mortal vanishes from list
        #expect(!viewModel.items.contains { $0.name == "Soon-Dead" },
                "Current behavior: dismissed mortal removed from list (REQ-VIW-005 gap)")
    }

    @Test("Selection falls back to Jake when dismissed mortal was selected")
    @MainActor func selectionFallsBackToJakeOnDismiss() throws {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL)
        let registry = ServitorRegistry()
        let spawner = Self.makeSpawner(registry: registry, projectURL: projectURL)

        let mortal = try spawner.summon(name: "Selected-Worker", assignment: "Task")
        let viewModel = ServitorListViewModel(jake: jake, spawner: spawner)

        viewModel.selectServitor(id: mortal.id)
        #expect(viewModel.selectedServitorId == mortal.id)

        try spawner.dismiss(mortal)
        viewModel.servitorsDidChange()

        #expect(viewModel.selectedServitorId == jake.id,
                "Selection should fall back to Jake when the selected mortal is dismissed")
    }

    // MARK: - Multiple lifecycle states coexist in list

    @Test("List shows servitors in various lifecycle states simultaneously")
    @MainActor func listShowsVariousLifecycleStates() throws {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL)
        let registry = ServitorRegistry()
        let spawner = Self.makeSpawner(registry: registry, projectURL: projectURL)

        _ = try spawner.summon(name: "Idle-One", assignment: nil)
        let done = try spawner.summon(name: "Done-One", assignment: "Completed task")
        let waiting = try spawner.summon(name: "Waiting-One", assignment: "Blocked task")

        done.markDone()
        waiting.markWaiting()

        let viewModel = ServitorListViewModel(jake: jake, spawner: spawner)

        // Verify all states represented
        let states = viewModel.items.map { $0.state }
        #expect(states.contains(.idle))
        #expect(states.contains(.done))
        #expect(states.contains(.waiting))

        // Jake is always first
        #expect(viewModel.items.first?.isJake == true)

        // All four entries present (Jake + 3 mortals)
        #expect(viewModel.items.count == 4)
    }

    @Test("Jake is always present regardless of mortal states")
    @MainActor func jakeAlwaysPresentRegardlessOfMortalStates() throws {
        let projectURL = Self.testProjectURL()
        let jake = Jake(projectURL: projectURL)
        let registry = ServitorRegistry()
        let spawner = Self.makeSpawner(registry: registry, projectURL: projectURL)

        // Empty list: just Jake
        let viewModel = ServitorListViewModel(jake: jake, spawner: spawner)
        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.isJake == true)

        // Add and complete a mortal
        let mortal = try spawner.summon(name: "Temp", assignment: "Quick job")
        mortal.markDone()
        viewModel.servitorsDidChange()

        #expect(viewModel.items.first?.isJake == true)
        #expect(viewModel.items.count == 2)

        // Dismiss the mortal
        try spawner.dismiss(mortal)
        viewModel.servitorsDidChange()

        // Jake survives
        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.isJake == true)
    }
}
