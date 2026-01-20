import Foundation

/// Generates unique names for agents using a theme
/// Thread-safe via serial dispatch queue
public final class NameGenerator: @unchecked Sendable {

    // MARK: - Thread Safety

    private let queue = DispatchQueue(label: "com.tavern.NameGenerator")

    // MARK: - State

    private var _currentTheme: NamingTheme
    private var _usedNames: Set<String> = []
    private var _currentTierIndex: Int = 0
    private var _currentNameIndex: Int = 0

    /// The current naming theme
    public var currentTheme: NamingTheme {
        get { queue.sync { _currentTheme } }
        set { queue.sync { _currentTheme = newValue; resetIndices() } }
    }

    /// Names that have been used (globally unique)
    public var usedNames: Set<String> {
        queue.sync { _usedNames }
    }

    /// Number of names remaining in the current theme
    public var remainingNames: Int {
        queue.sync {
            _currentTheme.allNames.count - _usedNames.intersection(_currentTheme.allNames).count
        }
    }

    // MARK: - Initialization

    /// Create a name generator with a theme
    /// - Parameter theme: The naming theme to use (defaults to LOTR)
    public init(theme: NamingTheme = .lotr) {
        self._currentTheme = theme
    }

    // MARK: - Name Generation

    /// Generate the next available name from the theme
    /// - Returns: A unique name, or nil if all names in the theme are exhausted
    public func nextName() -> String? {
        queue.sync {
            // Try to find an unused name, iterating through tiers
            while _currentTierIndex < _currentTheme.tiers.count {
                let tier = _currentTheme.tiers[_currentTierIndex]

                while _currentNameIndex < tier.count {
                    let name = tier[_currentNameIndex]
                    _currentNameIndex += 1

                    if !_usedNames.contains(name) {
                        _usedNames.insert(name)
                        return name
                    }
                }

                // Move to next tier
                _currentTierIndex += 1
                _currentNameIndex = 0
            }

            // All names exhausted
            return nil
        }
    }

    /// Generate a name, or a fallback numbered name if theme is exhausted
    /// - Returns: A unique name (always succeeds)
    public func nextNameOrFallback() -> String {
        if let name = nextName() {
            return name
        }

        // Generate numbered fallback
        return queue.sync {
            var counter = 1
            var fallbackName: String
            repeat {
                fallbackName = "Agent-\(counter)"
                counter += 1
            } while _usedNames.contains(fallbackName)

            _usedNames.insert(fallbackName)
            return fallbackName
        }
    }

    /// Check if a name is available (not yet used)
    /// - Parameter name: The name to check
    /// - Returns: true if the name is available
    public func isNameAvailable(_ name: String) -> Bool {
        queue.sync { !_usedNames.contains(name) }
    }

    /// Reserve a specific name (mark it as used)
    /// - Parameter name: The name to reserve
    /// - Returns: true if the name was successfully reserved, false if already taken
    @discardableResult
    public func reserveName(_ name: String) -> Bool {
        queue.sync {
            if _usedNames.contains(name) {
                return false
            }
            _usedNames.insert(name)
            return true
        }
    }

    /// Release a name back to the pool
    /// - Parameter name: The name to release
    public func releaseName(_ name: String) {
        _ = queue.sync {
            _usedNames.remove(name)
        }
    }

    /// Reset all used names and indices
    public func reset() {
        queue.sync {
            _usedNames.removeAll()
            resetIndices()
        }
    }

    // MARK: - Private

    private func resetIndices() {
        _currentTierIndex = 0
        _currentNameIndex = 0
    }
}
