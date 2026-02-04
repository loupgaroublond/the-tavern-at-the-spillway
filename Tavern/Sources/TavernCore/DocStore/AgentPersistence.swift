import Foundation

/// Manages persisting agents to the doc store
public final class AgentPersistence: @unchecked Sendable {

    // MARK: - Dependencies

    private let docStore: DocStore
    private let queue = DispatchQueue(label: "com.tavern.AgentPersistence")

    // MARK: - Initialization

    /// Create an agent persistence manager
    /// - Parameter docStore: The doc store to persist to
    public init(docStore: DocStore) {
        self.docStore = docStore
    }

    // MARK: - Save Operations

    /// Save a servitor to the doc store
    /// - Parameter servitor: The servitor to save
    /// - Throws: If saving fails
    public func save(_ servitor: Servitor) throws {
        let node = AgentNode(from: servitor)
        let document = node.toDocument()
        try docStore.save(document)
    }

    /// Save multiple servitors
    /// - Parameter servitors: The servitors to save
    /// - Throws: If any save fails
    public func saveAll(_ servitors: [Servitor]) throws {
        for servitor in servitors {
            try save(servitor)
        }
    }

    // MARK: - Load Operations

    /// Load an agent node from the doc store
    /// - Parameter name: The agent's name (used as document ID)
    /// - Returns: The agent node
    /// - Throws: If loading fails
    public func load(name: String) throws -> AgentNode {
        let documentId = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let document = try docStore.read(id: documentId)
        return try AgentNode.from(document: document)
    }

    /// Load all agent nodes from the doc store
    /// - Returns: Array of agent nodes
    /// - Throws: If loading fails
    public func loadAll() throws -> [AgentNode] {
        let documents = try docStore.readAll()
        return documents.compactMap { doc in
            try? AgentNode.from(document: doc)
        }
    }

    /// Restore a Servitor from the doc store
    /// - Parameters:
    ///   - name: The servitor's name
    ///   - projectURL: Project directory URL for the restored servitor
    ///   - verifier: Optional verifier (defaults to shell-based)
    /// - Returns: The restored servitor
    /// - Throws: If restoration fails
    public func restore(
        name: String,
        projectURL: URL,
        verifier: CommitmentVerifier = CommitmentVerifier()
    ) throws -> Servitor {
        let node = try load(name: name)

        // Create commitment list from stored commitments
        let commitmentList = CommitmentList()
        for commitmentNode in node.commitments {
            let commitment = commitmentNode.toCommitment()
            commitmentList.add(commitment)
        }

        // Create the servitor
        let servitor = Servitor(
            id: node.id,
            name: node.name,
            assignment: node.assignment,
            projectURL: projectURL,
            commitments: commitmentList,
            verifier: verifier
        )

        // Restore state (if not idle - idle is default)
        switch node.state {
        case "working": break // Can't restore working state
        case "waiting": servitor.markWaiting()
        case "verifying": break // Can't restore verifying state
        case "done": servitor.markDone()
        default: break
        }

        return servitor
    }

    // MARK: - Delete Operations

    /// Delete an agent's persisted data
    /// - Parameter name: The agent's name
    /// - Throws: If deletion fails
    public func delete(name: String) throws {
        let documentId = name.lowercased().replacingOccurrences(of: " ", with: "-")
        try docStore.delete(id: documentId)
    }

    /// Check if an agent exists in the doc store
    /// - Parameter name: The agent's name
    /// - Returns: true if persisted data exists
    public func exists(name: String) -> Bool {
        let documentId = name.lowercased().replacingOccurrences(of: " ", with: "-")
        return docStore.exists(id: documentId)
    }

    /// List all persisted agent names
    /// - Returns: Array of agent names
    /// - Throws: If listing fails
    public func listAll() throws -> [String] {
        let documents = try docStore.readAll()
        return documents.compactMap { $0.title }
    }
}
