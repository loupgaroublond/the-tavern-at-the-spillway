// MARK: - Provenance: REQ-OBS-011

import Foundation
import Testing
import ClodKit
@testable import TavernCore

/// Tests for discovery sharing (REQ-OBS-011).
///
/// The spec defines three properties:
/// 1. Agent system prompts include discovery-sharing instructions
/// 2. Agents can deliver discovery messages to parent agents or Jake
/// 3. Discovery sharing does not interrupt the agent's main task
///
/// Property 1 is testable via prompt inspection.
/// Properties 2-3 are tested via mock interactions: a mortal includes
/// a DISCOVERY: prefix in its response while continuing its main task,
/// and the response flows through without interrupting state transitions.
///
/// **Gap:** There is no programmatic discovery routing mechanism yet.
/// Servitor-to-servitor communication is listed as "Not Implemented."
/// Discovery sharing currently relies on prompt engineering (the agent
/// is instructed to prefix discoveries with "DISCOVERY:" in its output).
/// A future implementation should add an MCP tool or callback for
/// structured discovery delivery from mortal to Jake.
@Suite("Discovery Sharing Tests", .tags(.reqOBS011), .timeLimit(.minutes(2)))
struct DiscoverySharingTests {

    // MARK: - Helpers

    private static func testProjectURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
    }

    // MARK: - Property 1: System prompts include discovery-sharing instructions

    @Test("Jake system prompt includes discovery sharing instructions")
    func jakeSystemPromptIncludesDiscoverySharing() {
        let prompt = Jake.systemPrompt

        #expect(prompt.contains("DISCOVERY"))
        #expect(prompt.contains("DISCOVERY:"))
        // Jake's prompt instructs him to route discoveries from Regulars
        #expect(prompt.localizedStandardContains("route"))
    }

    @Test("Mortal system prompt includes discovery sharing instructions (Jake-spawned)")
    func mortalJakeSpawnedPromptIncludesDiscoverySharing() async throws {
        let mock = MockMessenger(responses: ["Acknowledged"])
        let mortal = Mortal(
            name: "DiscoveryWorker",
            assignment: "Analyze the codebase",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        // Send a message so the system prompt is captured in query options
        let _ = try await mortal.send("Start work")

        #expect(mock.queryOptions.count == 1)
        let systemPrompt = try #require(mock.queryOptions[0].systemPrompt)
        #expect(systemPrompt.contains("DISCOVERY"))
        #expect(systemPrompt.contains("DISCOVERY:"))
        // Prompt instructs non-interruption: discoveries alongside regular output
        #expect(systemPrompt.localizedStandardContains("not stop"))
    }

    @Test("Mortal system prompt includes discovery sharing instructions (user-spawned)")
    func mortalUserSpawnedPromptIncludesDiscoverySharing() async throws {
        let mock = MockMessenger(responses: ["Ready"])
        let mortal = Mortal(
            name: "UserWorker",
            assignment: nil,
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let _ = try await mortal.send("What should I work on?")

        #expect(mock.queryOptions.count == 1)
        let systemPrompt = try #require(mock.queryOptions[0].systemPrompt)
        #expect(systemPrompt.contains("DISCOVERY"))
        #expect(systemPrompt.contains("DISCOVERY:"))
    }

    @Test("Both Mortal spawn modes have symmetric discovery instructions")
    func mortalSpawnModesSymmetricDiscoveryInstructions() async throws {
        let mockJakeSpawn = MockMessenger(responses: ["OK"])
        let jakeSpawned = Mortal(
            name: "JakeChild",
            assignment: "Do work",
            projectURL: Self.testProjectURL(),
            messenger: mockJakeSpawn
        )

        let mockUserSpawn = MockMessenger(responses: ["OK"])
        let userSpawned = Mortal(
            name: "UserChild",
            assignment: nil,
            projectURL: Self.testProjectURL(),
            messenger: mockUserSpawn
        )

        let _ = try await jakeSpawned.send("Go")
        let _ = try await userSpawned.send("Go")

        let jakePrompt = try #require(mockJakeSpawn.queryOptions[0].systemPrompt)
        let userPrompt = try #require(mockUserSpawn.queryOptions[0].systemPrompt)

        // Both prompts must contain the same discovery sharing block
        #expect(jakePrompt.contains("DISCOVERY SHARING:"))
        #expect(userPrompt.contains("DISCOVERY SHARING:"))
        #expect(jakePrompt.contains("DISCOVERY:"))
        #expect(userPrompt.contains("DISCOVERY:"))
    }

    // MARK: - Property 3: Discovery sharing does not interrupt main task

    @Test("Mortal response with discovery does not interrupt state transitions")
    func discoveryDoesNotInterruptStateTransitions() async throws {
        // A mortal that includes a DISCOVERY: line in a normal working response
        // should remain in idle state (not done, not waiting) — the discovery
        // prefix is informational, not a state signal.
        let mock = MockMessenger(responses: [
            "I found something interesting.\nDISCOVERY: The config file has a race condition.\nContinuing with the main task."
        ])
        let mortal = Mortal(
            name: "DiscoverWorker",
            assignment: "Review code",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let response = try await mortal.send("Start review")

        // Discovery is in the response but mortal continues working (idle, not done)
        #expect(response.contains("DISCOVERY:"))
        #expect(mortal.state == .idle)
    }

    @Test("Mortal can include discovery alongside DONE signal")
    func discoveryAlongsideDoneSignal() async throws {
        // A mortal that reports a discovery AND signals DONE in the same response.
        // The DONE signal should still trigger completion; the discovery is passthrough.
        let mock = MockMessenger(responses: [
            "DISCOVERY: Found a deprecated API usage in module X.\nAll tasks complete. DONE"
        ])
        let mortal = Mortal(
            name: "DiscoverAndDone",
            assignment: "Audit APIs",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let response = try await mortal.send("Run audit")

        #expect(response.contains("DISCOVERY:"))
        #expect(mortal.state == .done)
    }

    @Test("Mortal can include discovery alongside WAITING signal")
    func discoveryAlongsideWaitingSignal() async throws {
        // A mortal that reports a discovery AND signals it needs input.
        // The WAITING signal should still trigger the waiting state.
        let mock = MockMessenger(responses: [
            "DISCOVERY: The test suite has 3 flaky tests.\nI need your input on which module to focus on. WAITING"
        ])
        let mortal = Mortal(
            name: "DiscoverAndWait",
            assignment: "Fix tests",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let response = try await mortal.send("Investigate failures")

        #expect(response.contains("DISCOVERY:"))
        #expect(mortal.state == .waiting)
    }

    // MARK: - Property 2: Agents can deliver discovery messages

    @Test("Discovery messages flow through mortal response to caller")
    func discoveryMessagesFlowThrough() async throws {
        // The current mechanism: discoveries are embedded in the response text.
        // The caller (e.g., ChatViewModel or Jake) receives the full response
        // including DISCOVERY: lines, and can parse/route them.
        let discoveryText = "DISCOVERY: Package.swift has a duplicate dependency declaration."
        let mock = MockMessenger(responses: [
            "Working on the analysis.\n\(discoveryText)\nAnalysis complete."
        ])
        let mortal = Mortal(
            name: "FlowWorker",
            assignment: "Analyze dependencies",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let response = try await mortal.send("Check dependencies")

        // The discovery is present in the response for the caller to extract
        #expect(response.contains(discoveryText))
    }

    @Test("Multiple discoveries in single response all flow through")
    func multipleDiscoveriesFlowThrough() async throws {
        let mock = MockMessenger(responses: [
            """
            Starting code review.
            DISCOVERY: Function `parse()` has O(n^2) complexity.
            Continuing review...
            DISCOVERY: Module `Network` has no error handling for timeouts.
            Review complete.
            """
        ])
        let mortal = Mortal(
            name: "MultiDiscovery",
            assignment: "Code review",
            projectURL: Self.testProjectURL(),
            messenger: mock
        )

        let response = try await mortal.send("Review all modules")

        // Both discoveries are present
        let discoveryLines = response.components(separatedBy: "\n")
            .filter { $0.hasPrefix("DISCOVERY:") }
        #expect(discoveryLines.count == 2)
        #expect(mortal.state == .idle)
    }
}
