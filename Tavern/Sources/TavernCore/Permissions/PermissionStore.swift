import Foundation
import os.log

/// Persists permission rules and the active permission mode using UserDefaults.
///
/// Thread-safe via serial DispatchQueue, matching the project's concurrency pattern
/// (see SessionStore, AgentRegistry, NameGenerator).
public final class PermissionStore: @unchecked Sendable {

    // MARK: - Storage Keys

    private static let modeKey = "com.tavern.permissions.mode"
    private static let rulesKey = "com.tavern.permissions.rules"

    // MARK: - Properties

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.tavern.PermissionStore")

    private var _mode: PermissionMode
    private var _rules: [PermissionRule]

    // MARK: - Initialization

    /// Create a PermissionStore backed by the given UserDefaults
    /// - Parameter defaults: The UserDefaults instance to use (injectable for testing)
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load persisted mode
        if let modeString = defaults.string(forKey: Self.modeKey),
           let mode = PermissionMode(rawValue: modeString) {
            self._mode = mode
        } else {
            self._mode = .normal
        }

        // Load persisted rules
        if let data = defaults.data(forKey: Self.rulesKey),
           let rules = try? JSONDecoder().decode([PermissionRule].self, from: data) {
            self._rules = rules
        } else {
            self._rules = []
        }

        TavernLogger.permissions.info("PermissionStore loaded: mode=\(self._mode.rawValue), rules=\(self._rules.count)")
    }

    // MARK: - Mode

    /// The active permission mode
    public var mode: PermissionMode {
        get { queue.sync { _mode } }
        set {
            queue.sync { _mode = newValue }
            defaults.set(newValue.rawValue, forKey: Self.modeKey)
            TavernLogger.permissions.info("Permission mode changed to: \(newValue.rawValue)")
        }
    }

    // MARK: - Rules

    /// All permission rules
    public var rules: [PermissionRule] {
        queue.sync { _rules }
    }

    /// Add a new permission rule
    /// - Parameter rule: The rule to add
    public func addRule(_ rule: PermissionRule) {
        queue.sync { _rules.append(rule) }
        persistRules()
        TavernLogger.permissions.info("Added rule: \(rule.toolPattern) -> \(rule.decision.rawValue)")
    }

    /// Remove a permission rule by ID
    /// - Parameter id: The rule's unique identifier
    public func removeRule(id: UUID) {
        let removed = queue.sync { () -> Bool in
            let before = _rules.count
            _rules.removeAll { $0.id == id }
            return _rules.count < before
        }
        if removed {
            persistRules()
            TavernLogger.permissions.info("Removed rule: \(id)")
        }
    }

    /// Remove all permission rules
    public func removeAllRules() {
        queue.sync { _rules.removeAll() }
        persistRules()
        TavernLogger.permissions.info("All permission rules removed")
    }

    /// Find the first rule that matches a tool name
    /// - Parameter toolName: The tool name to match against
    /// - Returns: The matching rule, or nil if no rule matches
    public func findMatchingRule(for toolName: String) -> PermissionRule? {
        queue.sync {
            _rules.first { $0.matches(toolName: toolName) }
        }
    }

    // MARK: - Private

    private func persistRules() {
        let rules = queue.sync { _rules }
        do {
            let data = try JSONEncoder().encode(rules)
            defaults.set(data, forKey: Self.rulesKey)
        } catch {
            TavernLogger.permissions.error("Failed to persist permission rules: \(error.localizedDescription)")
        }
    }
}
