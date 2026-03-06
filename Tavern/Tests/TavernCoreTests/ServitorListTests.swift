import Foundation
import Testing
@testable import TavernCore

@Suite("ServitorListItem Tests", .timeLimit(.minutes(1)))
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
    func itemFromJakeMarksIsJake() throws {
        let jake = Jake(projectURL: Self.testProjectURL())
        let item = ServitorListItem.from(jake: jake)

        #expect(item.isJake == true)
        #expect(item.name == "Jake")
        #expect(item.id == jake.id)
        #expect(item.chatDescription == nil)
    }

    @Test("Item from Mortal uses chatDescription")
    func itemFromMortalUsesChatDescription() throws {
        let mortal = Mortal(
            name: "Frodo",
            assignment: "Carry the ring",
            chatDescription: "Ring duty",
            projectURL: Self.testProjectURL()
        )
        let item = ServitorListItem.from(mortal: mortal)

        #expect(item.isJake == false)
        #expect(item.name == "Frodo")
        #expect(item.chatDescription == "Ring duty")
        #expect(item.id == mortal.id)
    }

    @Test("Item from Mortal without description has nil chatDescription")
    func itemFromMortalWithoutDescription() throws {
        let mortal = Mortal(
            name: "Sam",
            assignment: "Help Frodo",
            projectURL: Self.testProjectURL()
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

