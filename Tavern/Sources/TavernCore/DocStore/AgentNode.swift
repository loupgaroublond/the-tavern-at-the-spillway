import Foundation

/// Serialized representation of an agent for doc store persistence
/// This is the data that gets written to/read from files
public struct AgentNode: Codable, Equatable, Sendable {

    /// Unique identifier for the agent
    public let id: UUID

    /// Display name
    public let name: String

    /// The servitor's assignment description, nil for user-spawned servitors
    public let assignment: String?

    /// Current state
    public let state: String

    /// Serialized commitments
    public let commitments: [CommitmentNode]

    /// When this agent was created
    public let createdAt: Date

    /// When this was last updated
    public let updatedAt: Date

    // MARK: - Initialization

    public init(
        id: UUID,
        name: String,
        assignment: String?,
        state: String,
        commitments: [CommitmentNode] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.assignment = assignment
        self.state = state
        self.commitments = commitments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Create from a Servitor
    public init(from servitor: Servitor) {
        self.id = servitor.id
        self.name = servitor.name
        self.assignment = servitor.assignment
        self.state = servitor.state.rawValue
        self.commitments = servitor.commitments.commitments.map { CommitmentNode(from: $0) }
        self.createdAt = Date() // Servitor doesn't track creation time
        self.updatedAt = Date()
    }

    // MARK: - Document Conversion

    /// Convert to a Document for storage
    public func toDocument() -> Document {
        let iso = ISO8601DateFormatter()

        let frontmatter: [String: String] = [
            "id": id.uuidString,
            "state": state,
            "createdAt": iso.string(from: createdAt),
            "updatedAt": iso.string(from: updatedAt)
        ]

        // Build content with assignment and commitments
        var content = ""
        if let assignment = assignment {
            content = "## Assignment\n\n\(assignment)\n"
        }

        if !commitments.isEmpty {
            content += "\n## Commitments\n\n"
            for commitment in commitments {
                let statusEmoji: String
                switch commitment.status {
                case "pending": statusEmoji = "⏳"
                case "verifying": statusEmoji = "🔄"
                case "passed": statusEmoji = "✅"
                case "failed": statusEmoji = "❌"
                default: statusEmoji = "❓"
                }
                content += "- \(statusEmoji) **\(commitment.description)**\n"
                content += "  - Assertion: `\(commitment.assertion)`\n"
                if let message = commitment.failureMessage {
                    content += "  - Failed: \(message)\n"
                }
            }
        }

        return Document(
            id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
            title: name,
            frontmatter: frontmatter,
            content: content
        )
    }

    /// Parse from a Document
    public static func from(document: Document) throws -> AgentNode {
        let iso = ISO8601DateFormatter()

        guard let idString = document.frontmatter["id"],
              let id = UUID(uuidString: idString) else {
            throw AgentNodeError.missingField("id")
        }

        guard let name = document.title else {
            throw AgentNodeError.missingField("title")
        }

        guard let state = document.frontmatter["state"] else {
            throw AgentNodeError.missingField("state")
        }

        // Parse dates
        let createdAt = document.frontmatter["createdAt"]
            .flatMap { iso.date(from: $0) } ?? Date()
        let updatedAt = document.frontmatter["updatedAt"]
            .flatMap { iso.date(from: $0) } ?? Date()

        // Extract assignment from content (everything under "## Assignment")
        let assignmentText = extractSection(from: document.content, header: "## Assignment")
        let assignment: String? = assignmentText.isEmpty ? nil : assignmentText

        // Parse commitments from content
        let commitments = parseCommitments(from: document.content)

        return AgentNode(
            id: id,
            name: name,
            assignment: assignment,
            state: state,
            commitments: commitments,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Private Helpers

    private static func extractSection(from content: String, header: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var inSection = false
        var sectionLines: [String] = []

        for line in lines {
            if line.hasPrefix("## ") {
                if line == header {
                    inSection = true
                    continue
                } else if inSection {
                    break
                }
            }

            if inSection {
                sectionLines.append(line)
            }
        }

        return sectionLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseCommitments(from content: String) -> [CommitmentNode] {
        // Simple parser for commitment list format
        var commitments: [CommitmentNode] = []
        let lines = content.components(separatedBy: "\n")
        var currentDescription: String?
        var currentAssertion: String?
        var currentStatus = "pending"
        var currentFailure: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Status line: "- ⏳ **Description**"
            if trimmed.hasPrefix("- ") && trimmed.contains("**") {
                // Save previous if exists
                if let desc = currentDescription, let assertion = currentAssertion {
                    commitments.append(CommitmentNode(
                        id: UUID(),
                        description: desc,
                        assertion: assertion,
                        status: currentStatus,
                        failureMessage: currentFailure
                    ))
                }

                // Parse new commitment
                if trimmed.contains("⏳") { currentStatus = "pending" }
                else if trimmed.contains("🔄") { currentStatus = "verifying" }
                else if trimmed.contains("✅") { currentStatus = "passed" }
                else if trimmed.contains("❌") { currentStatus = "failed" }
                else { currentStatus = "pending" }

                // Extract description between ** markers
                if let start = trimmed.range(of: "**"),
                   let end = trimmed.range(of: "**", range: start.upperBound..<trimmed.endIndex) {
                    currentDescription = String(trimmed[start.upperBound..<end.lowerBound])
                }
                currentAssertion = nil
                currentFailure = nil
            }
            // Assertion line: "  - Assertion: `cmd`"
            else if trimmed.hasPrefix("- Assertion:") {
                if let start = trimmed.firstIndex(of: "`"),
                   let end = trimmed.lastIndex(of: "`"),
                   start < end {
                    currentAssertion = String(trimmed[trimmed.index(after: start)..<end])
                }
            }
            // Failure line: "  - Failed: message"
            else if trimmed.hasPrefix("- Failed:") {
                currentFailure = String(trimmed.dropFirst("- Failed:".count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        // Don't forget the last one
        if let desc = currentDescription, let assertion = currentAssertion {
            commitments.append(CommitmentNode(
                id: UUID(),
                description: desc,
                assertion: assertion,
                status: currentStatus,
                failureMessage: currentFailure
            ))
        }

        return commitments
    }
}

/// Serialized representation of a commitment
public struct CommitmentNode: Codable, Equatable, Sendable {

    public let id: UUID
    public let description: String
    public let assertion: String
    public let status: String
    public let failureMessage: String?

    public init(
        id: UUID = UUID(),
        description: String,
        assertion: String,
        status: String = "pending",
        failureMessage: String? = nil
    ) {
        self.id = id
        self.description = description
        self.assertion = assertion
        self.status = status
        self.failureMessage = failureMessage
    }

    /// Create from a Commitment
    public init(from commitment: Commitment) {
        self.id = commitment.id
        self.description = commitment.description
        self.assertion = commitment.assertion
        self.status = commitment.status.rawValue
        self.failureMessage = commitment.failureMessage
    }

    /// Convert back to a Commitment
    public func toCommitment() -> Commitment {
        var commitment = Commitment(
            id: id,
            description: description,
            assertion: assertion
        )

        switch status {
        case "verifying": commitment.markVerifying()
        case "passed": commitment.markPassed()
        case "failed": commitment.markFailed(message: failureMessage ?? "Unknown failure")
        default: break // Keep as pending
        }

        return commitment
    }
}

/// Errors during agent node operations
public enum AgentNodeError: Error, Equatable {
    case missingField(String)
    case invalidData(String)
}
