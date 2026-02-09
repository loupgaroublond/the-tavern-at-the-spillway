import Foundation
import Testing
@testable import TavernCore

@Suite("PermissionStore Tests")
struct PermissionStoreTests {

    /// Create an isolated UserDefaults for each test to prevent cross-contamination
    private static func testDefaults() -> UserDefaults {
        let suiteName = "com.tavern.test.permissions.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test("Store initializes with default mode")
    func storeDefaultMode() {
        let store = PermissionStore(defaults: Self.testDefaults())
        #expect(store.mode == .normal)
    }

    @Test("Store initializes with empty rules")
    func storeDefaultRules() {
        let store = PermissionStore(defaults: Self.testDefaults())
        #expect(store.rules.isEmpty)
    }

    @Test("Store persists mode change")
    func storePersistsMode() {
        let defaults = Self.testDefaults()
        let store = PermissionStore(defaults: defaults)

        store.mode = .bypassPermissions

        // Create a new store from the same defaults — should load persisted mode
        let store2 = PermissionStore(defaults: defaults)
        #expect(store2.mode == .bypassPermissions)
    }

    @Test("Store persists rules")
    func storePersistsRules() {
        let defaults = Self.testDefaults()
        let store = PermissionStore(defaults: defaults)

        let rule = PermissionRule(toolPattern: "bash", decision: .allow)
        store.addRule(rule)

        // Create a new store from the same defaults
        let store2 = PermissionStore(defaults: defaults)
        #expect(store2.rules.count == 1)
        #expect(store2.rules[0].toolPattern == "bash")
        #expect(store2.rules[0].decision == .allow)
    }

    @Test("Store adds multiple rules")
    func storeAddsMultipleRules() {
        let store = PermissionStore(defaults: Self.testDefaults())

        store.addRule(PermissionRule(toolPattern: "bash", decision: .allow))
        store.addRule(PermissionRule(toolPattern: "edit", decision: .allow))
        store.addRule(PermissionRule(toolPattern: "rm", decision: .deny))

        #expect(store.rules.count == 3)
    }

    @Test("Store removes rule by ID")
    func storeRemovesRule() {
        let store = PermissionStore(defaults: Self.testDefaults())

        let rule = PermissionRule(toolPattern: "bash", decision: .allow)
        store.addRule(rule)
        #expect(store.rules.count == 1)

        store.removeRule(id: rule.id)
        #expect(store.rules.isEmpty)
    }

    @Test("Store removeRule is idempotent for missing ID")
    func storeRemoveRuleMissingId() {
        let store = PermissionStore(defaults: Self.testDefaults())
        store.addRule(PermissionRule(toolPattern: "bash", decision: .allow))

        // Remove a non-existent ID — should be a no-op
        store.removeRule(id: UUID())
        #expect(store.rules.count == 1)
    }

    @Test("Store removes all rules")
    func storeRemovesAllRules() {
        let store = PermissionStore(defaults: Self.testDefaults())

        store.addRule(PermissionRule(toolPattern: "bash", decision: .allow))
        store.addRule(PermissionRule(toolPattern: "edit", decision: .deny))
        #expect(store.rules.count == 2)

        store.removeAllRules()
        #expect(store.rules.isEmpty)
    }

    @Test("Store finds matching rule for exact name")
    func storeFindMatchingRuleExact() {
        let store = PermissionStore(defaults: Self.testDefaults())

        let rule = PermissionRule(toolPattern: "bash", decision: .allow)
        store.addRule(rule)

        let match = store.findMatchingRule(for: "bash")
        #expect(match != nil)
        #expect(match?.id == rule.id)
    }

    @Test("Store finds matching rule for wildcard")
    func storeFindMatchingRuleWildcard() {
        let store = PermissionStore(defaults: Self.testDefaults())

        let rule = PermissionRule(toolPattern: "file*", decision: .deny)
        store.addRule(rule)

        #expect(store.findMatchingRule(for: "fileRead") != nil)
        #expect(store.findMatchingRule(for: "fileWrite") != nil)
        #expect(store.findMatchingRule(for: "bash") == nil)
    }

    @Test("Store returns first matching rule")
    func storeReturnsFirstMatch() {
        let store = PermissionStore(defaults: Self.testDefaults())

        let allowRule = PermissionRule(toolPattern: "bash", decision: .allow)
        let denyRule = PermissionRule(toolPattern: "bash", decision: .deny)
        store.addRule(allowRule)
        store.addRule(denyRule)

        let match = store.findMatchingRule(for: "bash")
        #expect(match?.id == allowRule.id)
        #expect(match?.decision == .allow)
    }

    @Test("Store removeAllRules persists")
    func storeRemoveAllRulesPersists() {
        let defaults = Self.testDefaults()
        let store = PermissionStore(defaults: defaults)

        store.addRule(PermissionRule(toolPattern: "bash", decision: .allow))
        store.removeAllRules()

        let store2 = PermissionStore(defaults: defaults)
        #expect(store2.rules.isEmpty)
    }
}
