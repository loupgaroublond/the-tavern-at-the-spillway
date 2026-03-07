import Foundation
import os.log
import TavernKit

// MARK: - Provenance: REQ-ARCH-003, REQ-DOC-001, REQ-DOC-002

/// Errors from servitor file system operations
public enum ServitorStoreError: Error {
    case directoryCreationFailed(URL, Error)
    case writeFailed(URL, Error)
    case readFailed(URL, Error)
    case parseFailed(URL, String)
}

/// Consolidated per-project resource access. Implements both ProjectHandle and
/// ResourceProvider, centralizing all file-system access into one genuinely
/// Sendable object with no mutable state.
///
/// Vended by UnixDirectoryDriver. One ProjectDirectory per open project.
public final class ProjectDirectory: ProjectHandle, ResourceProvider, Sendable {

    // MARK: - ProjectHandle

    public let id: UUID
    public let rootURL: URL
    public var name: String { rootURL.lastPathComponent }
    public let isReady: Bool = true

    // MARK: - Internal

    private let scanner: FileTreeScanner
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "directory")

    private let maxFileSize: UInt64 = 1_000_000

    private static let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tiff", "ico", "icns", "icon",
        "pdf", "zip", "tar", "gz", "bz2", "xz", "rar", "7z",
        "exe", "dll", "dylib", "so", "a", "o",
        "mp3", "mp4", "m4a", "wav", "avi", "mov", "mkv",
        "sqlite", "db", "realm",
        "xcassets", "car", "nib", "storyboardc",
        "pbxproj"
    ]

    // MARK: - JSON Coding

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    nonisolated(unsafe) private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Initialization

    public init(rootURL: URL, id: UUID = UUID()) {
        self.rootURL = rootURL
        self.id = id
        self.scanner = FileTreeScanner()
    }

    // MARK: - ResourceProvider

    public func scanDirectory(at url: URL) throws -> [FileTreeNode] {
        try scanner.scanDirectory(at: url, relativeTo: rootURL)
    }

    public func scanChildren(of node: FileTreeNode) throws -> [FileTreeNode] {
        try scanner.scanDirectory(at: node.url, relativeTo: rootURL)
    }

    public func readFile(at url: URL) throws -> String {
        guard !isBinaryFile(at: url) else {
            throw TavernError.internalError("Binary file: \(url.path)")
        }
        guard !isFileTooLarge(at: url) else {
            throw TavernError.internalError("File too large (>1MB): \(url.path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func isFileTooLarge(at url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? UInt64 else {
            return false
        }
        return size > maxFileSize
    }

    public func isBinaryFile(at url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return Self.binaryExtensions.contains(ext)
    }

    // MARK: - Servitor Persistence

    private var servitorsBaseURL: URL {
        rootURL
            .appendingPathComponent(".tavern", isDirectory: true)
            .appendingPathComponent("servitors", isDirectory: true)
    }

    /// URL for a servitor's directory (lowercase name)
    public func servitorURL(name: String) -> URL {
        servitorsBaseURL.appendingPathComponent(name.lowercased(), isDirectory: true)
    }

    private func ensureDirectory(name: String) throws {
        let dirURL = servitorURL(name: name)
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("[ProjectDirectory] failed to create directory at \(dirURL.path): \(error.localizedDescription)")
            throw ServitorStoreError.directoryCreationFailed(dirURL, error)
        }
    }

    /// Save a servitor record as YAML frontmatter in servitor.md
    public func saveServitor(_ record: ServitorRecord) throws {
        try ensureDirectory(name: record.name)
        let fileURL = servitorURL(name: record.name).appendingPathComponent("servitor.md")
        let content = serializeToFrontmatter(record)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ServitorStoreError.writeFailed(fileURL, error)
        }
    }

    /// Load a servitor record from its servitor.md file
    public func loadServitor(name: String) throws -> ServitorRecord? {
        let fileURL = servitorURL(name: name).appendingPathComponent("servitor.md")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw ServitorStoreError.readFailed(fileURL, error)
        }
        guard let record = parseFromFrontmatter(content, fileURL: fileURL) else {
            throw ServitorStoreError.parseFailed(fileURL, "Failed to parse YAML frontmatter")
        }
        return record
    }

    /// List all persisted servitor records by scanning the servitors directory
    public func listAllServitors() throws -> [ServitorRecord] {
        let baseURL = servitorsBaseURL
        guard FileManager.default.fileExists(atPath: baseURL.path) else { return [] }

        let contents: [String]
        do {
            contents = try FileManager.default.contentsOfDirectory(atPath: baseURL.path)
        } catch {
            throw ServitorStoreError.readFailed(baseURL, error)
        }

        var records: [ServitorRecord] = []
        for dirName in contents {
            let fileURL = baseURL
                .appendingPathComponent(dirName, isDirectory: true)
                .appendingPathComponent("servitor.md")
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                if let record = parseFromFrontmatter(content, fileURL: fileURL) {
                    records.append(record)
                }
            } catch {
                Self.logger.error("[ProjectDirectory] failed to read \(fileURL.path): \(error.localizedDescription)")
            }
        }
        return records
    }

    /// Remove a servitor's entire directory
    public func removeServitor(name: String) throws {
        let dirURL = servitorURL(name: name)
        guard FileManager.default.fileExists(atPath: dirURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: dirURL)
        } catch {
            throw ServitorStoreError.writeFailed(dirURL, error)
        }
    }

    // MARK: - Session Event Log

    /// Append a session event to the servitor's sessions.jsonl
    public func appendSessionEvent(_ event: SessionEvent, name: String) throws {
        try ensureDirectory(name: name)
        let fileURL = servitorURL(name: name).appendingPathComponent("sessions.jsonl")

        let data: Data
        do {
            data = try Self.jsonEncoder.encode(event)
        } catch {
            throw ServitorStoreError.writeFailed(fileURL, error)
        }

        guard var line = String(data: data, encoding: .utf8) else {
            throw ServitorStoreError.writeFailed(fileURL, NSError(domain: "ProjectDirectory", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "UTF-8 encoding failed"
            ]))
        }
        line.append("\n")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            guard let lineData = line.data(using: .utf8) else {
                throw ServitorStoreError.writeFailed(fileURL, NSError(domain: "ProjectDirectory", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to encode line as UTF-8"
                ]))
            }
            handle.write(lineData)
        } else {
            try line.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    /// Load all session events from a servitor's sessions.jsonl
    public func loadSessionEvents(name: String) throws -> [SessionEvent] {
        let fileURL = servitorURL(name: name).appendingPathComponent("sessions.jsonl")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw ServitorStoreError.readFailed(fileURL, error)
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var events: [SessionEvent] = []
        for line in lines {
            guard let lineData = line.data(using: .utf8) else { continue }
            do {
                let event = try Self.jsonDecoder.decode(SessionEvent.self, from: lineData)
                events.append(event)
            } catch {
                Self.logger.error("[ProjectDirectory] failed to parse session event line: \(error.localizedDescription)")
            }
        }
        return events
    }

    // MARK: - YAML Frontmatter Serialization

    private func serializeToFrontmatter(_ record: ServitorRecord) -> String {
        var lines: [String] = ["---"]
        lines.append("name: \(yamlEscape(record.name))")
        lines.append("id: \(record.id.uuidString)")
        if let assignment = record.assignment {
            lines.append("assignment: \(yamlEscape(assignment))")
        }
        if let sessionId = record.sessionId {
            lines.append("session_id: \(yamlEscape(sessionId))")
        }
        lines.append("session_mode: \(record.sessionMode.rawValue)")
        if let description = record.description {
            lines.append("description: \(yamlEscape(description))")
        }
        if let modelId = record.modelId {
            lines.append("model_id: \(yamlEscape(modelId))")
        }
        if let thinkingBudget = record.thinkingBudget {
            lines.append("thinking_budget: \(thinkingBudget)")
        }
        if let effortLevel = record.effortLevel {
            lines.append("effort_level: \(yamlEscape(effortLevel))")
        }
        lines.append("created_at: \(Self.iso8601.string(from: record.createdAt))")
        lines.append("updated_at: \(Self.iso8601.string(from: record.updatedAt))")
        lines.append("---")
        // Serialize MCP servers as a JSON code block in the body
        if !record.mcpServers.isEmpty {
            lines.append("## MCP Servers")
            lines.append("")
            lines.append("```json mcp-servers")
            if let jsonData = try? Self.jsonEncoder.encode(record.mcpServers),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                // Pretty-print for human readability
                if let jsonObj = try? JSONSerialization.jsonObject(with: jsonData),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted, .sortedKeys]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    lines.append(prettyString)
                } else {
                    lines.append(jsonString)
                }
            }
            lines.append("```")
            lines.append("")
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func parseFromFrontmatter(_ content: String, fileURL: URL) -> ServitorRecord? {
        let lines = content.components(separatedBy: .newlines)
        guard let firstDelim = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else { return nil }
        let afterFirst = lines.index(after: firstDelim)
        guard afterFirst < lines.endIndex else { return nil }
        guard let secondDelim = lines[afterFirst...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else { return nil }

        var fields: [String: String] = [:]
        for line in lines[afterFirst..<secondDelim] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            fields[key] = yamlUnescape(value)
        }

        guard let name = fields["name"],
              let idString = fields["id"],
              let id = UUID(uuidString: idString),
              let createdAtString = fields["created_at"],
              let createdAt = Self.iso8601.date(from: createdAtString),
              let updatedAtString = fields["updated_at"],
              let updatedAt = Self.iso8601.date(from: updatedAtString) else { return nil }

        let sessionMode: PermissionMode
        if let modeString = fields["session_mode"], let mode = PermissionMode(rawValue: modeString) {
            sessionMode = mode
        } else {
            sessionMode = .plan
        }

        let thinkingBudget: Int? = fields["thinking_budget"].flatMap { Int($0) }

        // Parse MCP servers from JSON code block in body (after frontmatter)
        let mcpServers = parseMCPServersFromBody(lines: lines, afterFrontmatter: secondDelim + 1)

        return ServitorRecord(
            name: name, id: id, assignment: fields["assignment"],
            sessionId: fields["session_id"], sessionMode: sessionMode,
            description: fields["description"], createdAt: createdAt, updatedAt: updatedAt,
            modelId: fields["model_id"], thinkingBudget: thinkingBudget,
            effortLevel: fields["effort_level"],
            mcpServers: mcpServers
        )
    }

    /// Parse MCP server configs from a ```json mcp-servers code block in the body.
    private func parseMCPServersFromBody(lines: [String], afterFrontmatter: Int) -> [String: MCPServerEntry] {
        guard afterFrontmatter < lines.count else { return [:] }

        let bodyLines = Array(lines[afterFrontmatter...])

        // Find ```json mcp-servers opening fence
        guard let openIndex = bodyLines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("```json mcp-servers")
        }) else { return [:] }

        // Find closing ``` fence
        let searchStart = bodyLines.index(after: openIndex)
        guard searchStart < bodyLines.endIndex else { return [:] }
        guard let closeIndex = bodyLines[searchStart...].firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "```"
        }) else { return [:] }

        let jsonLines = bodyLines[searchStart..<closeIndex]
        let jsonString = jsonLines.joined(separator: "\n")

        guard let jsonData = jsonString.data(using: .utf8) else { return [:] }
        do {
            return try Self.jsonDecoder.decode([String: MCPServerEntry].self, from: jsonData)
        } catch {
            Self.logger.error("[ProjectDirectory] failed to parse MCP servers JSON: \(error.localizedDescription)")
            return [:]
        }
    }

    // MARK: - YAML Escaping

    private static let yamlSpecialCharacters = CharacterSet(charactersIn: ":{}[]|>&*!#%@`'\",?")

    private func yamlEscape(_ value: String) -> String {
        let needsQuoting = value.isEmpty
            || value.unicodeScalars.contains(where: { Self.yamlSpecialCharacters.contains($0) })
            || value.hasPrefix(" ") || value.hasSuffix(" ") || value.contains("\n")
        guard needsQuoting else { return value }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private func yamlUnescape(_ value: String) -> String {
        var s = value
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            s = String(s.dropFirst().dropLast())
            s = s.replacingOccurrences(of: "\\n", with: "\n")
            s = s.replacingOccurrences(of: "\\\"", with: "\"")
            s = s.replacingOccurrences(of: "\\\\", with: "\\")
        }
        if s.hasPrefix("'") && s.hasSuffix("'") && s.count >= 2 {
            s = String(s.dropFirst().dropLast())
        }
        return s
    }
}
