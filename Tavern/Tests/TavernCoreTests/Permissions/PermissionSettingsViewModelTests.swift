import Foundation
import Testing
@testable import TavernCore

@Suite("PermissionSettingsViewModel Tests")
@MainActor
struct PermissionSettingsViewModelTests {

    /// Create an isolated view model for each test
    private static func makeViewModel(mode: PermissionMode = .normal) -> PermissionSettingsViewModel {
        let suiteName = "com.tavern.test.permissions.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = PermissionStore(defaults: defaults)
        store.mode = mode
        let manager = PermissionManager(store: store)
        return PermissionSettingsViewModel(manager: manager)
    }

    @Test("ViewModel initializes with correct mode")
    func vmInitMode() {
        let vm = Self.makeViewModel(mode: .plan)
        #expect(vm.currentMode == .plan)
    }

    @Test("ViewModel initializes with empty rules")
    func vmInitEmptyRules() {
        let vm = Self.makeViewModel()
        #expect(vm.rules.isEmpty)
    }

    @Test("ViewModel mode change updates manager")
    func vmModeChangeUpdatesManager() {
        let vm = Self.makeViewModel(mode: .normal)
        vm.currentMode = .bypassPermissions

        // Refresh to get the manager's state
        vm.refresh()
        #expect(vm.currentMode == .bypassPermissions)
    }

    @Test("ViewModel addRule creates rule and clears input")
    func vmAddRule() {
        let vm = Self.makeViewModel()
        vm.newRulePattern = "bash"
        vm.newRuleDecision = .allow

        vm.addRule()

        #expect(vm.rules.count == 1)
        #expect(vm.rules[0].toolPattern == "bash")
        #expect(vm.rules[0].decision == .allow)
        #expect(vm.newRulePattern.isEmpty)
    }

    @Test("ViewModel addRule with deny decision")
    func vmAddDenyRule() {
        let vm = Self.makeViewModel()
        vm.newRulePattern = "rm"
        vm.newRuleDecision = .deny

        vm.addRule()

        #expect(vm.rules.count == 1)
        #expect(vm.rules[0].decision == .deny)
    }

    @Test("ViewModel addRule ignores empty pattern")
    func vmAddRuleIgnoresEmpty() {
        let vm = Self.makeViewModel()
        vm.newRulePattern = ""

        vm.addRule()

        #expect(vm.rules.isEmpty)
    }

    @Test("ViewModel addRule trims whitespace")
    func vmAddRuleTrimsWhitespace() {
        let vm = Self.makeViewModel()
        vm.newRulePattern = "  bash  "
        vm.newRuleDecision = .allow

        vm.addRule()

        #expect(vm.rules.count == 1)
        #expect(vm.rules[0].toolPattern == "bash")
    }

    @Test("ViewModel removeRule removes by ID")
    func vmRemoveRule() {
        let vm = Self.makeViewModel()
        vm.newRulePattern = "bash"
        vm.addRule()
        vm.newRulePattern = "edit"
        vm.addRule()
        #expect(vm.rules.count == 2)

        let firstId = vm.rules[0].id
        vm.removeRule(id: firstId)

        #expect(vm.rules.count == 1)
        #expect(vm.rules[0].toolPattern == "edit")
    }

    @Test("ViewModel removeAllRules clears everything")
    func vmRemoveAllRules() {
        let vm = Self.makeViewModel()
        vm.newRulePattern = "bash"
        vm.addRule()
        vm.newRulePattern = "edit"
        vm.addRule()

        vm.removeAllRules()

        #expect(vm.rules.isEmpty)
    }

    @Test("ViewModel refresh syncs with manager")
    func vmRefresh() {
        let suiteName = "com.tavern.test.permissions.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = PermissionStore(defaults: defaults)
        let manager = PermissionManager(store: store)
        let vm = PermissionSettingsViewModel(manager: manager)

        // Modify manager directly (simulating external change)
        manager.addAllowRule(toolPattern: "externally_added")
        manager.mode = .dontAsk

        // VM doesn't know yet
        #expect(vm.rules.isEmpty)

        // After refresh, VM picks up the changes
        vm.refresh()
        #expect(vm.rules.count == 1)
        #expect(vm.rules[0].toolPattern == "externally_added")
        #expect(vm.currentMode == .dontAsk)
    }

    @Test("ViewModel mode change is idempotent")
    func vmModeChangeIdempotent() {
        let vm = Self.makeViewModel(mode: .normal)

        // Setting to the same mode should not log/trigger a change
        vm.currentMode = .normal
        #expect(vm.currentMode == .normal)
    }
}
