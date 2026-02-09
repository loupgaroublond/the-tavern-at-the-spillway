import Foundation
import Testing
@testable import TavernCore

@Suite("PermissionRule Tests")
struct PermissionRuleTests {

    @Test("Rule matches exact tool name")
    func ruleMatchesExact() {
        let rule = PermissionRule(toolPattern: "bash", decision: .allow)
        #expect(rule.matches(toolName: "bash"))
    }

    @Test("Rule match is case-insensitive")
    func ruleMatchesCaseInsensitive() {
        let rule = PermissionRule(toolPattern: "Bash", decision: .allow)
        #expect(rule.matches(toolName: "bash"))
        #expect(rule.matches(toolName: "BASH"))
        #expect(rule.matches(toolName: "Bash"))
    }

    @Test("Rule does not match different tool name")
    func ruleDoesNotMatchDifferent() {
        let rule = PermissionRule(toolPattern: "bash", decision: .allow)
        #expect(!rule.matches(toolName: "edit"))
        #expect(!rule.matches(toolName: "read"))
    }

    @Test("Wildcard rule matches prefix")
    func wildcardMatchesPrefix() {
        let rule = PermissionRule(toolPattern: "bash*", decision: .allow)
        #expect(rule.matches(toolName: "bash"))
        #expect(rule.matches(toolName: "bash_run"))
        #expect(rule.matches(toolName: "bashExec"))
    }

    @Test("Wildcard rule does not match non-prefix")
    func wildcardDoesNotMatchNonPrefix() {
        let rule = PermissionRule(toolPattern: "bash*", decision: .deny)
        #expect(!rule.matches(toolName: "mybash"))
        #expect(!rule.matches(toolName: "edit"))
    }

    @Test("Rule initializes with correct defaults")
    func ruleDefaults() {
        let rule = PermissionRule(toolPattern: "test", decision: .deny)
        #expect(rule.toolPattern == "test")
        #expect(rule.decision == .deny)
        #expect(rule.note == nil)
    }

    @Test("Rule with note preserves note")
    func ruleWithNote() {
        let rule = PermissionRule(toolPattern: "read", decision: .allow, note: "Safe read-only tool")
        #expect(rule.note == "Safe read-only tool")
    }

    @Test("Rules are equatable by value")
    func rulesEquatable() {
        let id = UUID()
        let date = Date()
        let rule1 = PermissionRule(id: id, toolPattern: "bash", decision: .allow, createdAt: date)
        let rule2 = PermissionRule(id: id, toolPattern: "bash", decision: .allow, createdAt: date)
        #expect(rule1 == rule2)
    }

    @Test("Rules with different IDs are not equal")
    func rulesDifferentIds() {
        let rule1 = PermissionRule(toolPattern: "bash", decision: .allow)
        let rule2 = PermissionRule(toolPattern: "bash", decision: .allow)
        #expect(rule1 != rule2)
    }

    @Test("PermissionDecision raw values are correct")
    func decisionRawValues() {
        #expect(PermissionDecision.allow.rawValue == "allow")
        #expect(PermissionDecision.deny.rawValue == "deny")
    }
}
