import Foundation

// MARK: - Provenance: REQ-SPN-005

/// Error thrown when servitor registry operations fail
public enum ServitorRegistryError: Error, Equatable {
    case servitorNotFound(UUID)
    case nameAlreadyExists(String)
}

/// Registry that tracks all active servitors in the Tavern
/// Thread-safe via serial dispatch queue
public final class ServitorRegistry: @unchecked Sendable {

    // MARK: - Thread Safety

    private let queue = DispatchQueue(label: "com.tavern.ServitorRegistry")

    // MARK: - State

    private var _servitors: [UUID: any Servitor] = [:]
    private var _nameToId: [String: UUID] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Registration

    /// Register a servitor with the registry
    /// - Parameter servitor: The servitor to register
    /// - Throws: `ServitorRegistryError.nameAlreadyExists` if a servitor with this name exists
    public func register(_ servitor: some Servitor) throws {
        try queue.sync {
            // Check for name uniqueness
            if _nameToId[servitor.name] != nil {
                throw ServitorRegistryError.nameAlreadyExists(servitor.name)
            }

            _servitors[servitor.id] = servitor
            _nameToId[servitor.name] = servitor.id
        }
    }

    /// Remove a servitor from the registry
    /// - Parameter id: The ID of the servitor to remove
    /// - Throws: `ServitorRegistryError.servitorNotFound` if no servitor with this ID exists
    public func remove(id: UUID) throws {
        try queue.sync {
            guard let servitor = _servitors[id] else {
                throw ServitorRegistryError.servitorNotFound(id)
            }

            _nameToId.removeValue(forKey: servitor.name)
            _servitors.removeValue(forKey: id)
        }
    }

    // MARK: - Queries

    /// Get a servitor by ID
    /// - Parameter id: The servitor's unique ID
    /// - Returns: The servitor if found, nil otherwise
    public func servitor(id: UUID) -> (any Servitor)? {
        queue.sync { _servitors[id] }
    }

    /// Get a servitor by name
    /// - Parameter name: The servitor's display name
    /// - Returns: The servitor if found, nil otherwise
    public func servitor(named name: String) -> (any Servitor)? {
        queue.sync {
            guard let id = _nameToId[name] else { return nil }
            return _servitors[id]
        }
    }

    /// List all registered servitors
    /// - Returns: Array of all servitors in the registry
    public func allServitors() -> [any Servitor] {
        queue.sync { Array(_servitors.values) }
    }

    /// Number of registered servitors
    public var count: Int {
        queue.sync { _servitors.count }
    }

    /// Check if a name is already taken
    /// - Parameter name: The name to check
    /// - Returns: true if a servitor with this name exists
    public func isNameTaken(_ name: String) -> Bool {
        queue.sync { _nameToId[name] != nil }
    }

    /// Remove all servitors from the registry
    public func removeAll() {
        queue.sync {
            _servitors.removeAll()
            _nameToId.removeAll()
        }
    }
}
