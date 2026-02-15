import Foundation
import Testing
@testable import TavernCore

// MARK: - Test Agent Implementation

/// Simple agent implementation for testing
final class TestAgent: Agent, @unchecked Sendable {
    let id: UUID
    let name: String
    private(set) var state: AgentState = .idle
    var sessionMode: PermissionMode = .plan

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    func send(_ message: String) async throws -> String {
        state = .working
        defer { state = .idle }
        return "Response to: \(message)"
    }

    func sendStreaming(_ message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void) {
        let response = "Response to: \(message)"
        let stream = AsyncThrowingStream<StreamEvent, Error> { continuation in
            continuation.yield(.textDelta(response))
            continuation.yield(.completed(sessionId: nil, usage: nil))
            continuation.finish()
        }
        return (stream: stream, cancel: {})
    }

    func resetConversation() {
        state = .idle
    }
}

// MARK: - Tests

@Suite("AgentRegistry Tests")
struct AgentRegistryTests {

    @Test("Registry adds agent")
    func registryAddsAgent() throws {
        let registry = AgentRegistry()
        let agent = TestAgent(name: "TestAgent1")

        try registry.register(agent)

        #expect(registry.count == 1)
        #expect(registry.agent(id: agent.id) != nil)
    }

    @Test("Registry gets agent by ID")
    func registryGetsAgentById() throws {
        let registry = AgentRegistry()
        let agent = TestAgent(name: "TestAgent2")

        try registry.register(agent)

        let retrieved = registry.agent(id: agent.id)
        #expect(retrieved != nil)
        #expect(retrieved?.id == agent.id)
        #expect(retrieved?.name == agent.name)
    }

    @Test("Registry gets agent by name")
    func registryGetsAgentByName() throws {
        let registry = AgentRegistry()
        let agent = TestAgent(name: "UniqueTestAgent")

        try registry.register(agent)

        let retrieved = registry.agent(named: "UniqueTestAgent")
        #expect(retrieved != nil)
        #expect(retrieved?.id == agent.id)
    }

    @Test("Registry lists all agents")
    func registryListsAgents() throws {
        let registry = AgentRegistry()
        let agent1 = TestAgent(name: "Agent1")
        let agent2 = TestAgent(name: "Agent2")
        let agent3 = TestAgent(name: "Agent3")

        try registry.register(agent1)
        try registry.register(agent2)
        try registry.register(agent3)

        let all = registry.allAgents()
        #expect(all.count == 3)

        let names = Set(all.map { $0.name })
        #expect(names.contains("Agent1"))
        #expect(names.contains("Agent2"))
        #expect(names.contains("Agent3"))
    }

    @Test("Registry removes agent")
    func registryRemovesAgent() throws {
        let registry = AgentRegistry()
        let agent = TestAgent(name: "ToBeRemoved")

        try registry.register(agent)
        #expect(registry.count == 1)

        try registry.remove(id: agent.id)
        #expect(registry.count == 0)
        #expect(registry.agent(id: agent.id) == nil)
    }

    @Test("Registry enforces unique names")
    func registryEnforcesUniqueNames() throws {
        let registry = AgentRegistry()
        let agent1 = TestAgent(name: "DuplicateName")
        let agent2 = TestAgent(name: "DuplicateName")

        try registry.register(agent1)

        do {
            try registry.register(agent2)
            Issue.record("Expected error for duplicate name")
        } catch let error as AgentRegistryError {
            if case .nameAlreadyExists(let name) = error {
                #expect(name == "DuplicateName")
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }

    @Test("Registry throws when removing non-existent agent")
    func registryThrowsOnRemoveNonExistent() {
        let registry = AgentRegistry()
        let fakeId = UUID()

        do {
            try registry.remove(id: fakeId)
            Issue.record("Expected error for non-existent agent")
        } catch let error as AgentRegistryError {
            if case .agentNotFound(let id) = error {
                #expect(id == fakeId)
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Registry isNameTaken returns correct value")
    func registryIsNameTaken() throws {
        let registry = AgentRegistry()
        let agent = TestAgent(name: "TakenName")

        #expect(registry.isNameTaken("TakenName") == false)

        try registry.register(agent)

        #expect(registry.isNameTaken("TakenName") == true)
        #expect(registry.isNameTaken("OtherName") == false)
    }

    @Test("Registry removeAll clears all agents")
    func registryRemoveAll() throws {
        let registry = AgentRegistry()
        try registry.register(TestAgent(name: "A1"))
        try registry.register(TestAgent(name: "A2"))
        try registry.register(TestAgent(name: "A3"))

        #expect(registry.count == 3)

        registry.removeAll()

        #expect(registry.count == 0)
        #expect(registry.allAgents().isEmpty)
    }

    @Test("Registry allows reusing name after removal")
    func registryAllowsNameReuseAfterRemoval() throws {
        let registry = AgentRegistry()
        let agent1 = TestAgent(name: "ReusableName")

        try registry.register(agent1)
        try registry.remove(id: agent1.id)

        // Should be able to register new agent with same name
        let agent2 = TestAgent(name: "ReusableName")
        try registry.register(agent2)

        #expect(registry.count == 1)
        #expect(registry.agent(named: "ReusableName")?.id == agent2.id)
    }
}
