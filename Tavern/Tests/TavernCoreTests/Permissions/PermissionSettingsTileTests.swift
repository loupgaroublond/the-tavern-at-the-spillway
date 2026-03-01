import Foundation
import Testing
import TavernKit
@testable import PermissionSettingsTile

@Suite("PermissionSettingsTile Tests", .timeLimit(.minutes(1)))
@MainActor
struct PermissionSettingsTileTests {

    // MARK: - Helpers

    private static func makeTile(mode: PermissionMode = .normal) -> PermissionSettingsTile {
        let provider = MockPermissionProvider(mode: mode)
        let responder = PermissionSettingsResponder(onDismiss: {})
        return PermissionSettingsTile(permissionProvider: provider, responder: responder)
    }

    @Test("Tile initializes with correct mode")
    func initMode() {
        let tile = Self.makeTile(mode: .plan)
        #expect(tile.currentMode == .plan)
    }

    @Test("Tile initializes with empty rules")
    func initEmptyRules() {
        let tile = Self.makeTile()
        #expect(tile.rules.isEmpty)
    }

    @Test("Mode change syncs to provider")
    func modeChangeSyncsToProvider() {
        let provider = MockPermissionProvider(mode: .normal)
        let responder = PermissionSettingsResponder(onDismiss: {})
        let tile = PermissionSettingsTile(permissionProvider: provider, responder: responder)

        tile.currentMode = .bypassPermissions
        tile.syncModeToProvider()

        #expect(provider.mode == .bypassPermissions)
    }

    @Test("addRule creates rule and clears input")
    func addRule() {
        let tile = Self.makeTile()
        tile.newRulePattern = "bash"
        tile.newRuleDecision = .allow

        tile.addRule()

        #expect(tile.rules.count == 1)
        #expect(tile.rules[0].toolPattern == "bash")
        #expect(tile.rules[0].decision == .allow)
        #expect(tile.newRulePattern.isEmpty)
    }

    @Test("addRule with deny decision")
    func addDenyRule() {
        let tile = Self.makeTile()
        tile.newRulePattern = "rm"
        tile.newRuleDecision = .deny

        tile.addRule()

        #expect(tile.rules.count == 1)
        #expect(tile.rules[0].decision == .deny)
    }

    @Test("addRule ignores empty pattern")
    func addRuleIgnoresEmpty() {
        let tile = Self.makeTile()
        tile.newRulePattern = ""

        tile.addRule()

        #expect(tile.rules.isEmpty)
    }

    @Test("addRule trims whitespace")
    func addRuleTrimsWhitespace() {
        let tile = Self.makeTile()
        tile.newRulePattern = "  bash  "
        tile.newRuleDecision = .allow

        tile.addRule()

        #expect(tile.rules.count == 1)
        #expect(tile.rules[0].toolPattern == "bash")
    }

    @Test("removeRule removes by ID")
    func removeRule() {
        let tile = Self.makeTile()
        tile.newRulePattern = "bash"
        tile.addRule()
        tile.newRulePattern = "edit"
        tile.addRule()
        #expect(tile.rules.count == 2)

        let firstId = tile.rules[0].id
        tile.removeRule(id: firstId)

        #expect(tile.rules.count == 1)
        #expect(tile.rules[0].toolPattern == "edit")
    }

    @Test("removeAllRules clears everything")
    func removeAllRules() {
        let tile = Self.makeTile()
        tile.newRulePattern = "bash"
        tile.addRule()
        tile.newRulePattern = "edit"
        tile.addRule()

        tile.removeAllRules()

        #expect(tile.rules.isEmpty)
    }
}

// MARK: - Mock

@MainActor
private final class MockPermissionProvider: PermissionProvider {
    var mode: PermissionMode
    private var _rules: [PermissionRuleInfo] = []

    init(mode: PermissionMode = .normal) {
        self.mode = mode
    }

    func rules() -> [PermissionRuleInfo] { _rules }

    func addRule(pattern: String, decision: PermissionDecisionInfo) {
        _rules.append(PermissionRuleInfo(id: UUID(), toolPattern: pattern, decision: decision))
    }

    func removeRule(id: UUID) {
        _rules.removeAll { $0.id == id }
    }

    func removeAllRules() {
        _rules.removeAll()
    }
}
