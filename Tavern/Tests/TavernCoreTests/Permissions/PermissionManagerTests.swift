import Foundation
import Testing
@testable import TavernCore

@Suite("PermissionManager Tests")
struct PermissionManagerTests {

    /// Create an isolated manager for each test
    private static func makeManager(mode: PermissionMode = .normal) -> PermissionManager {
        let suiteName = "com.tavern.test.permissions.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = PermissionStore(defaults: defaults)
        store.mode = mode
        return PermissionManager(store: store)
    }

    // MARK: - Bypass Mode

    @Test("Bypass mode auto-approves all tools")
    func bypassModeApprovesAll() {
        let manager = Self.makeManager(mode: .bypassPermissions)

        #expect(manager.evaluateTool("bash") == .allow)
        #expect(manager.evaluateTool("edit") == .allow)
        #expect(manager.evaluateTool("delete_everything") == .allow)
    }

    // MARK: - Plan Mode

    @Test("Plan mode auto-denies all tools")
    func planModeDeniesAll() {
        let manager = Self.makeManager(mode: .plan)

        #expect(manager.evaluateTool("bash") == .deny)
        #expect(manager.evaluateTool("edit") == .deny)
        #expect(manager.evaluateTool("read") == .deny)
    }

    // MARK: - Accept Edits Mode

    @Test("AcceptEdits mode auto-approves edit tools")
    func acceptEditsApprovesEditTools() {
        let manager = Self.makeManager(mode: .acceptEdits)

        #expect(manager.evaluateTool("edit") == .allow)
        #expect(manager.evaluateTool("write") == .allow)
        #expect(manager.evaluateTool("notebookedit") == .allow)
    }

    @Test("AcceptEdits mode is case-insensitive for edit tools")
    func acceptEditsCaseInsensitive() {
        let manager = Self.makeManager(mode: .acceptEdits)

        #expect(manager.evaluateTool("Edit") == .allow)
        #expect(manager.evaluateTool("WRITE") == .allow)
    }

    @Test("AcceptEdits mode prompts for non-edit tools without rules")
    func acceptEditsPromptsForNonEdit() {
        let manager = Self.makeManager(mode: .acceptEdits)

        #expect(manager.evaluateTool("bash") == nil)
        #expect(manager.evaluateTool("read") == nil)
    }

    @Test("AcceptEdits mode respects rules for non-edit tools")
    func acceptEditsRespectsRulesForNonEdit() {
        let manager = Self.makeManager(mode: .acceptEdits)
        manager.addAllowRule(toolPattern: "read")

        #expect(manager.evaluateTool("read") == .allow)
    }

    // MARK: - Don't Ask Mode

    @Test("DontAsk mode allows matching allow rules")
    func dontAskAllowsMatchingRules() {
        let manager = Self.makeManager(mode: .dontAsk)
        manager.addAllowRule(toolPattern: "bash")

        #expect(manager.evaluateTool("bash") == .allow)
    }

    @Test("DontAsk mode auto-denies unmatched tools")
    func dontAskDeniesUnmatched() {
        let manager = Self.makeManager(mode: .dontAsk)
        manager.addAllowRule(toolPattern: "bash")

        #expect(manager.evaluateTool("edit") == .deny)
        #expect(manager.evaluateTool("delete") == .deny)
    }

    @Test("DontAsk mode respects deny rules")
    func dontAskRespectsDenyRules() {
        let manager = Self.makeManager(mode: .dontAsk)
        manager.addDenyRule(toolPattern: "bash")

        #expect(manager.evaluateTool("bash") == .deny)
    }

    @Test("DontAsk mode with no rules denies everything")
    func dontAskNoRulesDeniesAll() {
        let manager = Self.makeManager(mode: .dontAsk)

        #expect(manager.evaluateTool("bash") == .deny)
        #expect(manager.evaluateTool("edit") == .deny)
    }

    // MARK: - Normal Mode

    @Test("Normal mode returns nil for unmatched tools (prompt user)")
    func normalModePromptsUser() {
        let manager = Self.makeManager(mode: .normal)

        #expect(manager.evaluateTool("bash") == nil)
        #expect(manager.evaluateTool("unknown") == nil)
    }

    @Test("Normal mode respects allow rules")
    func normalModeRespectsAllowRules() {
        let manager = Self.makeManager(mode: .normal)
        manager.addAllowRule(toolPattern: "bash")

        #expect(manager.evaluateTool("bash") == .allow)
    }

    @Test("Normal mode respects deny rules")
    func normalModeRespectsDenyRules() {
        let manager = Self.makeManager(mode: .normal)
        manager.addDenyRule(toolPattern: "rm")

        #expect(manager.evaluateTool("rm") == .deny)
    }

    @Test("Normal mode respects wildcard rules")
    func normalModeRespectsWildcardRules() {
        let manager = Self.makeManager(mode: .normal)
        manager.addAllowRule(toolPattern: "file*")

        #expect(manager.evaluateTool("fileRead") == .allow)
        #expect(manager.evaluateTool("fileWrite") == .allow)
        #expect(manager.evaluateTool("bash") == nil)
    }

    // MARK: - Rule Management

    @Test("Add and remove rules")
    func addAndRemoveRules() {
        let manager = Self.makeManager()
        #expect(manager.rules.isEmpty)

        manager.addAllowRule(toolPattern: "bash")
        #expect(manager.rules.count == 1)

        manager.addDenyRule(toolPattern: "rm")
        #expect(manager.rules.count == 2)

        manager.removeRule(id: manager.rules[0].id)
        #expect(manager.rules.count == 1)
        #expect(manager.rules[0].toolPattern == "rm")
    }

    @Test("Remove all rules clears everything")
    func removeAllRules() {
        let manager = Self.makeManager()
        manager.addAllowRule(toolPattern: "bash")
        manager.addAllowRule(toolPattern: "edit")
        manager.addDenyRule(toolPattern: "rm")
        #expect(manager.rules.count == 3)

        manager.removeAllRules()
        #expect(manager.rules.isEmpty)
    }

    @Test("Mode getter and setter work")
    func modeGetterSetter() {
        let manager = Self.makeManager(mode: .normal)
        #expect(manager.mode == .normal)

        manager.mode = .plan
        #expect(manager.mode == .plan)

        manager.mode = .bypassPermissions
        #expect(manager.mode == .bypassPermissions)
    }

    // MARK: - Approval Response Processing

    @Test("processApprovalResponse creates rule when alwaysAllow is true")
    func processApprovalResponseCreatesRule() {
        let manager = Self.makeManager()
        let request = ToolApprovalRequest(toolName: "bash", toolDescription: "Run command")
        let response = ToolApprovalResponse(approved: true, alwaysAllow: true)

        manager.processApprovalResponse(for: request, response: response)

        #expect(manager.rules.count == 1)
        #expect(manager.rules[0].toolPattern == "bash")
        #expect(manager.rules[0].decision == .allow)
    }

    @Test("processApprovalResponse does not create rule when alwaysAllow is false")
    func processApprovalResponseNoRule() {
        let manager = Self.makeManager()
        let request = ToolApprovalRequest(toolName: "bash", toolDescription: "Run command")
        let response = ToolApprovalResponse(approved: true, alwaysAllow: false)

        manager.processApprovalResponse(for: request, response: response)

        #expect(manager.rules.isEmpty)
    }

    @Test("processApprovalResponse does not create rule when denied even with alwaysAllow")
    func processApprovalResponseDeniedNoRule() {
        let manager = Self.makeManager()
        let request = ToolApprovalRequest(toolName: "bash", toolDescription: "Run command")
        let response = ToolApprovalResponse(approved: false, alwaysAllow: true)

        manager.processApprovalResponse(for: request, response: response)

        #expect(manager.rules.isEmpty)
    }

    // MARK: - Mode Symmetry

    @Test("All modes produce a deterministic result for any tool")
    func allModesProduceDeterministicResult() {
        let testTools = ["bash", "edit", "write", "read", "delete", "notebookedit"]

        for mode in PermissionMode.allCases {
            let manager = Self.makeManager(mode: mode)

            for tool in testTools {
                let result = manager.evaluateTool(tool)

                switch mode {
                case .bypassPermissions:
                    #expect(result == .allow, "bypass mode must always allow")
                case .plan:
                    #expect(result == .deny, "plan mode must always deny")
                case .dontAsk:
                    #expect(result == .deny, "dontAsk with no rules must deny")
                case .normal:
                    #expect(result == nil, "normal with no rules must prompt")
                case .acceptEdits:
                    // Edit tools: allow; non-edit tools: prompt
                    let isEdit = ["edit", "write", "notebookedit"].contains(tool)
                    if isEdit {
                        #expect(result == .allow, "acceptEdits must allow edit tool '\(tool)'")
                    } else {
                        #expect(result == nil, "acceptEdits must prompt for non-edit tool '\(tool)'")
                    }
                }
            }
        }
    }
}
