import Foundation
import Testing
import ClodKit
@testable import TavernCore

// MARK: - Provenance: REQ-ARCH-009

@Suite("TavernDefaults & Model Config Tests", .timeLimit(.minutes(1)))
struct TavernDefaultsTests {

    // MARK: - TavernDefaults (UserDefaults-backed)

    @Test("TavernDefaults reads and writes model ID")
    func testModelIdRoundTrip() {
        let ud = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let defaults = TavernDefaults(defaults: ud)

        #expect(defaults.defaultModelId == nil)

        defaults.setDefaultModelId("claude-sonnet-4-20250514")
        #expect(defaults.defaultModelId == "claude-sonnet-4-20250514")

        defaults.setDefaultModelId(nil)
        #expect(defaults.defaultModelId == nil)
    }

    @Test("TavernDefaults reads and writes thinking config")
    func testThinkingConfigRoundTrip() {
        let ud = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let defaults = TavernDefaults(defaults: ud)

        #expect(defaults.defaultThinkingConfig == nil)

        defaults.setDefaultThinkingConfig(.adaptive)
        #expect(defaults.defaultThinkingConfig == .adaptive)

        defaults.setDefaultThinkingConfig(.enabled(budgetTokens: 8000))
        #expect(defaults.defaultThinkingConfig == .enabled(budgetTokens: 8000))

        defaults.setDefaultThinkingConfig(.disabled)
        #expect(defaults.defaultThinkingConfig == .disabled)

        defaults.setDefaultThinkingConfig(nil)
        #expect(defaults.defaultThinkingConfig == nil)
    }

    @Test("TavernDefaults reads and writes effort level")
    func testEffortLevelRoundTrip() {
        let ud = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let defaults = TavernDefaults(defaults: ud)

        #expect(defaults.defaultEffortLevel == nil)

        defaults.setDefaultEffortLevel("high")
        #expect(defaults.defaultEffortLevel == "high")

        defaults.setDefaultEffortLevel(nil)
        #expect(defaults.defaultEffortLevel == nil)
    }

    // MARK: - MockTavernDefaults

    @Test("MockTavernDefaults stores and returns values")
    func testMockDefaults() {
        let mock = MockTavernDefaults(
            modelId: "claude-opus-4-20250514",
            thinkingConfig: .enabled(budgetTokens: 4000),
            effortLevel: "max"
        )

        #expect(mock.defaultModelId == "claude-opus-4-20250514")
        #expect(mock.defaultThinkingConfig == .enabled(budgetTokens: 4000))
        #expect(mock.defaultEffortLevel == "max")

        mock.setDefaultModelId("claude-sonnet-4-20250514")
        #expect(mock.defaultModelId == "claude-sonnet-4-20250514")
    }

    // MARK: - ThinkingConfig.budgetTokens

    @Test("ThinkingConfig.budgetTokens extracts budget from enabled case")
    func testBudgetTokensEnabled() {
        #expect(ThinkingConfig.enabled(budgetTokens: 5000).budgetTokens == 5000)
        #expect(ThinkingConfig.enabled(budgetTokens: nil).budgetTokens == nil)
    }

    @Test("ThinkingConfig.budgetTokens returns nil for adaptive and disabled")
    func testBudgetTokensNonEnabled() {
        #expect(ThinkingConfig.adaptive.budgetTokens == nil)
        #expect(ThinkingConfig.disabled.budgetTokens == nil)
    }

    // MARK: - ServitorRecord model fields

    @Test("ServitorRecord round-trips model config fields")
    func testServitorRecordModelFields() {
        let record = ServitorRecord(
            name: "TestBot",
            modelId: "claude-opus-4-20250514",
            thinkingBudget: 10000,
            effortLevel: "high"
        )

        #expect(record.modelId == "claude-opus-4-20250514")
        #expect(record.thinkingBudget == 10000)
        #expect(record.effortLevel == "high")
    }

    @Test("ServitorRecord defaults model fields to nil")
    func testServitorRecordModelFieldsDefault() {
        let record = ServitorRecord(name: "Plain")

        #expect(record.modelId == nil)
        #expect(record.thinkingBudget == nil)
        #expect(record.effortLevel == nil)
    }

    @Test("ServitorRecord model fields persist through YAML save/load")
    func testServitorRecordModelFieldsPersistence() throws {
        let directory = try TestFixtures.createTestDirectory()

        let record = ServitorRecord(
            name: "ModelBot",
            modelId: "claude-sonnet-4-20250514",
            thinkingBudget: 8192,
            effortLevel: "medium"
        )

        try directory.saveServitor(record)
        let loaded = try #require(try directory.loadServitor(name: "ModelBot"))

        #expect(loaded.modelId == "claude-sonnet-4-20250514")
        #expect(loaded.thinkingBudget == 8192)
        #expect(loaded.effortLevel == "medium")
    }

    @Test("ServitorRecord nil model fields persist as absent through YAML")
    func testServitorRecordNilModelFieldsPersistence() throws {
        let directory = try TestFixtures.createTestDirectory()

        let record = ServitorRecord(name: "PlainBot")

        try directory.saveServitor(record)
        let loaded = try #require(try directory.loadServitor(name: "PlainBot"))

        #expect(loaded.modelId == nil)
        #expect(loaded.thinkingBudget == nil)
        #expect(loaded.effortLevel == nil)
    }

    // MARK: - buildOptions wiring

    @Test("buildOptions includes model ID when set")
    func testBuildOptionsIncludesModel() async throws {
        let messenger = MockMessenger(responses: ["hello"])
        let config = ClodSession.Config(
            systemPrompt: "test",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            servitorName: "test",
            modelId: "claude-opus-4-20250514"
        )
        let session = ClodSession(config: config, messenger: messenger)

        _ = try await session.send("hi")

        let captured = try #require(messenger.queryOptions.last)
        #expect(captured.model == "claude-opus-4-20250514")
    }

    @Test("buildOptions includes thinking budget when set")
    func testThinkingBudgetForwarded() async throws {
        let messenger = MockMessenger(responses: ["hello"])
        let config = ClodSession.Config(
            systemPrompt: "test",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            servitorName: "test",
            thinkingBudget: 16000
        )
        let session = ClodSession(config: config, messenger: messenger)

        _ = try await session.send("hi")

        let captured = try #require(messenger.queryOptions.last)
        #expect(captured.maxThinkingTokens == 16000)
    }

    @Test("buildOptions includes effort level when set")
    func testEffortLevelForwarded() async throws {
        let messenger = MockMessenger(responses: ["hello"])
        let config = ClodSession.Config(
            systemPrompt: "test",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            servitorName: "test",
            effortLevel: "high"
        )
        let session = ClodSession(config: config, messenger: messenger)

        _ = try await session.send("hi")

        let captured = try #require(messenger.queryOptions.last)
        #expect(captured.effort == "high")
    }

    @Test("buildOptions leaves model fields nil when not configured")
    func testBuildOptionsOmitsNilFields() async throws {
        let messenger = MockMessenger(responses: ["hello"])
        let config = ClodSession.Config(
            systemPrompt: "test",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            servitorName: "test"
        )
        let session = ClodSession(config: config, messenger: messenger)

        _ = try await session.send("hi")

        let captured = try #require(messenger.queryOptions.last)
        #expect(captured.model == nil)
        #expect(captured.maxThinkingTokens == nil)
        #expect(captured.effort == nil)
    }

    // MARK: - MortalSpawner stamps defaults

    @Test("Defaults are stamped at creation time")
    func testDefaultsStampedAtCreation() async throws {
        let registry = ServitorRegistry()
        let nameGen = NameGenerator(theme: .lotr)
        let projectURL = URL(fileURLWithPath: "/tmp/test-project")
        let mockDefaults = MockTavernDefaults(
            modelId: "claude-opus-4-20250514",
            thinkingConfig: .enabled(budgetTokens: 12000),
            effortLevel: "max"
        )

        let messenger = MockMessenger(responses: ["ack"])
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGen,
            projectURL: projectURL,
            messengerFactory: { _ in messenger },
            defaults: mockDefaults
        )

        let mortal = try spawner.summon()

        // Send a message to trigger buildOptions — captured by MockMessenger
        _ = try await mortal.send("test")

        let captured = try #require(messenger.queryOptions.last)
        #expect(captured.model == "claude-opus-4-20250514")
        #expect(captured.maxThinkingTokens == 12000)
        #expect(captured.effort == "max")
    }

    @Test("Changing default after spawn does not affect existing mortal")
    func testChangingDefaultDoesNotAffectExisting() async throws {
        let registry = ServitorRegistry()
        let nameGen = NameGenerator(theme: .lotr)
        let projectURL = URL(fileURLWithPath: "/tmp/test-project")
        let mockDefaults = MockTavernDefaults(
            modelId: "claude-opus-4-20250514",
            effortLevel: "high"
        )

        let messenger = MockMessenger(responses: ["ack"])
        let spawner = MortalSpawner(
            registry: registry,
            nameGenerator: nameGen,
            projectURL: projectURL,
            messengerFactory: { _ in messenger },
            defaults: mockDefaults
        )

        // Spawn mortal with current defaults
        let mortal = try spawner.summon()

        // Change defaults AFTER spawn
        mockDefaults.setDefaultModelId("claude-sonnet-4-20250514")
        mockDefaults.setDefaultEffortLevel("low")

        // Send message through mortal — should use OLD defaults (stamped at creation)
        _ = try await mortal.send("test")

        let captured = try #require(messenger.queryOptions.last)
        #expect(captured.model == "claude-opus-4-20250514")
        #expect(captured.effort == "high")
    }

    @Test("Reset to defaults clears MockTavernDefaults")
    func testResetToDefaults() {
        let mock = MockTavernDefaults(
            modelId: "claude-opus-4-20250514",
            thinkingConfig: .adaptive,
            effortLevel: "max"
        )

        // Reset all
        mock.setDefaultModelId(nil)
        mock.setDefaultThinkingConfig(nil)
        mock.setDefaultEffortLevel(nil)

        #expect(mock.defaultModelId == nil)
        #expect(mock.defaultThinkingConfig == nil)
        #expect(mock.defaultEffortLevel == nil)
    }
}
