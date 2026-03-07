import Foundation
import ClodKit

// MARK: - Provenance: REQ-ARCH-009

// MARK: - ThinkingConfig Convenience

extension ThinkingConfig {
    /// Extract the token budget, if this config specifies one.
    /// Returns nil for `.adaptive` and `.disabled`.
    public var budgetTokens: Int? {
        switch self {
        case .enabled(let tokens): return tokens
        case .adaptive, .disabled: return nil
        }
    }
}

/// Protocol for accessing user-level defaults (Layer 1).
/// Per-servitor overrides live in ServitorRecord (Layer 2).
/// The concrete implementation reads from UserDefaults; the mock is for testing.
public protocol TavernDefaultsProvider: Sendable {
    var defaultModelId: String? { get }
    var defaultThinkingConfig: ThinkingConfig? { get }
    var defaultEffortLevel: String? { get }

    func setDefaultModelId(_ modelId: String?)
    func setDefaultThinkingConfig(_ config: ThinkingConfig?)
    func setDefaultEffortLevel(_ level: String?)
}

/// User-level defaults backed by macOS UserDefaults.
/// Thread-safe because UserDefaults is thread-safe.
public final class TavernDefaults: TavernDefaultsProvider, Sendable {

    private static let logger = TavernLogger.agents

    // MARK: - Keys

    private enum Keys {
        static let modelId = "com.tavern.defaults.modelId"
        static let thinkingConfig = "com.tavern.defaults.thinkingConfig"
        static let effortLevel = "com.tavern.defaults.effortLevel"
    }

    // MARK: - Storage

    // UserDefaults is thread-safe but not formally Sendable in Swift 6.
    // nonisolated(unsafe) is safe here because UserDefaults synchronizes internally.
    private nonisolated(unsafe) let defaults: UserDefaults

    // MARK: - Initialization

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Model

    public var defaultModelId: String? {
        defaults.string(forKey: Keys.modelId)
    }

    public func setDefaultModelId(_ modelId: String?) {
        if let modelId {
            defaults.set(modelId, forKey: Keys.modelId)
            Self.logger.info("[TavernDefaults] defaultModelId set to '\(modelId)'")
        } else {
            defaults.removeObject(forKey: Keys.modelId)
            Self.logger.info("[TavernDefaults] defaultModelId cleared")
        }
    }

    // MARK: - Thinking Config

    public var defaultThinkingConfig: ThinkingConfig? {
        guard let data = defaults.data(forKey: Keys.thinkingConfig) else { return nil }
        do {
            return try JSONDecoder().decode(ThinkingConfig.self, from: data)
        } catch {
            Self.logger.debugError("[TavernDefaults] Failed to decode thinkingConfig: \(error.localizedDescription)")
            return nil
        }
    }

    public func setDefaultThinkingConfig(_ config: ThinkingConfig?) {
        if let config {
            do {
                let data = try JSONEncoder().encode(config)
                defaults.set(data, forKey: Keys.thinkingConfig)
                Self.logger.info("[TavernDefaults] defaultThinkingConfig set")
            } catch {
                Self.logger.debugError("[TavernDefaults] Failed to encode thinkingConfig: \(error.localizedDescription)")
            }
        } else {
            defaults.removeObject(forKey: Keys.thinkingConfig)
            Self.logger.info("[TavernDefaults] defaultThinkingConfig cleared")
        }
    }

    // MARK: - Effort Level

    public var defaultEffortLevel: String? {
        defaults.string(forKey: Keys.effortLevel)
    }

    public func setDefaultEffortLevel(_ level: String?) {
        if let level {
            defaults.set(level, forKey: Keys.effortLevel)
            Self.logger.info("[TavernDefaults] defaultEffortLevel set to '\(level)'")
        } else {
            defaults.removeObject(forKey: Keys.effortLevel)
            Self.logger.info("[TavernDefaults] defaultEffortLevel cleared")
        }
    }
}

// MARK: - Mock for Testing

/// In-memory mock of TavernDefaultsProvider for tests.
/// Uses NSLock for genuine Sendable conformance (no @unchecked).
public final class MockTavernDefaults: TavernDefaultsProvider, Sendable {

    private let lock = NSLock()
    private nonisolated(unsafe) var _modelId: String?
    private nonisolated(unsafe) var _thinkingConfig: ThinkingConfig?
    private nonisolated(unsafe) var _effortLevel: String?

    public init(
        modelId: String? = nil,
        thinkingConfig: ThinkingConfig? = nil,
        effortLevel: String? = nil
    ) {
        self._modelId = modelId
        self._thinkingConfig = thinkingConfig
        self._effortLevel = effortLevel
    }

    public var defaultModelId: String? { lock.withLock { _modelId } }
    public var defaultThinkingConfig: ThinkingConfig? { lock.withLock { _thinkingConfig } }
    public var defaultEffortLevel: String? { lock.withLock { _effortLevel } }

    public func setDefaultModelId(_ modelId: String?) { lock.withLock { _modelId = modelId } }
    public func setDefaultThinkingConfig(_ config: ThinkingConfig?) { lock.withLock { _thinkingConfig = config } }
    public func setDefaultEffortLevel(_ level: String?) { lock.withLock { _effortLevel = level } }
}
