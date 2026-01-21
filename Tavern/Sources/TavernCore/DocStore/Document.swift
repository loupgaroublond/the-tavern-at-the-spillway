import Foundation

/// A document in the doc store
/// Documents are markdown files with optional YAML frontmatter
public struct Document: Identifiable, Equatable, Sendable {

    /// Unique identifier (filename without extension)
    public let id: String

    /// Document title (from frontmatter or first heading)
    public var title: String?

    /// Frontmatter metadata as key-value pairs
    public var frontmatter: [String: String]

    /// Main content (markdown body after frontmatter)
    public var content: String

    /// When this document was created
    public let createdAt: Date

    /// When this document was last modified
    public var updatedAt: Date

    // MARK: - Initialization

    /// Create a new document
    /// - Parameters:
    ///   - id: Unique identifier (will be filename)
    ///   - title: Optional title
    ///   - frontmatter: Metadata key-value pairs
    ///   - content: Markdown body content
    public init(
        id: String,
        title: String? = nil,
        frontmatter: [String: String] = [:],
        content: String = ""
    ) {
        self.id = id
        self.title = title
        self.frontmatter = frontmatter
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Create a document with explicit timestamps (for restoration)
    internal init(
        id: String,
        title: String?,
        frontmatter: [String: String],
        content: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.frontmatter = frontmatter
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Serialization

    /// Render the document as a markdown string with frontmatter
    public func render() -> String {
        var output = ""

        // Build frontmatter
        var fm = frontmatter
        if let title = title {
            fm["title"] = title
        }

        if !fm.isEmpty {
            output += "---\n"
            for (key, value) in fm.sorted(by: { $0.key < $1.key }) {
                // Escape values that might cause YAML issues
                let escapedValue = value.contains(":") || value.contains("#")
                    ? "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
                    : value
                output += "\(key): \(escapedValue)\n"
            }
            output += "---\n\n"
        }

        output += content

        return output
    }

    /// Parse a document from markdown string with frontmatter
    /// - Parameters:
    ///   - id: The document identifier
    ///   - text: The raw markdown text
    /// - Returns: Parsed document
    public static func parse(id: String, from text: String) -> Document {
        var frontmatter: [String: String] = [:]
        var content = text
        var title: String?

        // Check for frontmatter
        if text.hasPrefix("---") {
            let lines = text.components(separatedBy: "\n")
            var inFrontmatter = false
            var frontmatterEnd = 0

            for (index, line) in lines.enumerated() {
                if index == 0 && line == "---" {
                    inFrontmatter = true
                    continue
                }

                if inFrontmatter {
                    if line == "---" {
                        frontmatterEnd = index
                        break
                    }

                    // Parse key: value
                    if let colonIndex = line.firstIndex(of: ":") {
                        let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        var value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                        // Remove quotes if present
                        if value.hasPrefix("\"") && value.hasSuffix("\"") {
                            value = String(value.dropFirst().dropLast())
                            value = value.replacingOccurrences(of: "\\\"", with: "\"")
                        }

                        frontmatter[key] = value
                    }
                }
            }

            // Extract content after frontmatter
            if frontmatterEnd > 0 {
                let contentLines = Array(lines[(frontmatterEnd + 1)...])
                content = contentLines.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Extract title from frontmatter
        if let fmTitle = frontmatter["title"] {
            title = fmTitle
            frontmatter.removeValue(forKey: "title")
        }

        return Document(
            id: id,
            title: title,
            frontmatter: frontmatter,
            content: content
        )
    }
}
