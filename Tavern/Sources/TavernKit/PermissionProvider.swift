import Foundation

public protocol PermissionProvider: Sendable {
    var mode: PermissionMode { get set }
    func rules() -> [PermissionRuleInfo]
    func addRule(pattern: String, decision: PermissionDecisionInfo)
    func removeRule(id: UUID)
    func removeAllRules()
}

public struct PermissionRuleInfo: Identifiable, Sendable {
    public let id: UUID
    public let toolPattern: String
    public let decision: PermissionDecisionInfo
    public let note: String?

    public init(id: UUID, toolPattern: String, decision: PermissionDecisionInfo, note: String? = nil) {
        self.id = id
        self.toolPattern = toolPattern
        self.decision = decision
        self.note = note
    }
}

public enum PermissionDecisionInfo: String, Sendable, CaseIterable {
    case allow
    case deny
}
