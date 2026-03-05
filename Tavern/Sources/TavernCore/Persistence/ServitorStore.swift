import Foundation
import os.log
import TavernKit

// MARK: - Provenance: REQ-DOC-004, REQ-DOC-008

/// Errors from ServitorStore file system operations
public enum ServitorStoreError: Error {
    case directoryCreationFailed(URL, Error)
    case writeFailed(URL, Error)
    case readFailed(URL, Error)
    case parseFailed(URL, String)
}

/// File-system-backed persistence for servitor state.
///
/// Each servitor gets a directory under `.tavern/servitors/<name>/` containing:
/// - `servitor.md` — YAML frontmatter with the servitor's current state
/// - `sessions.jsonl` — append-only log of session lifecycle events
///
/// Thread-safe via a serial DispatchQueue, matching the pattern used by
/// other queue-protected types in the project (Jake, Mortal, ServitorRegistry, etc.).
public final class ServitorStore: @unchecked Sendable {

    private let rootURL: URL
    private let queue = DispatchQueue(label: "com.tavern.ServitorStore")
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "store")
    private let fileManager = FileManager.default

    // nonisolated(unsafe) silences the concurrency-safety diagnostic for these
    // static formatters. All access is serialized through `queue`, so shared
    // mutable state is protected by an external synchronization mechanism.
    nonisolated(unsafe) private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

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

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    // MARK: - Base Path

    private var servitorsBaseURL: URL {
        rootURL
            .appendingPathComponent(".tavern", isDirectory: true)
            .appendingPathComponent("servitors", isDirectory: true)
    }

    // MARK: - Directory Management

    /// URL for a servitor's directory (lowercase name)
    public func servitorURL(name: String) -> URL {
        servitorsBaseURL.appendingPathComponent(name.lowercased(), isDirectory: true)
    }

    /// Ensure the servitor's directory exists, creating it if needed
    private func ensureDirectory(name: String) throws {
        let dirURL = servitorURL(name: name)
        do {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        } catch {
            Self.logger.debugError("Failed to create directory at \(dirURL.path): \(error.localizedDescription)")
            throw ServitorStoreError.directoryCreationFailed(dirURL, error)
        }
    }

    // MARK: - Servitor State (servitor.md)

    /// Save a servitor record as YAML frontmatter in servitor.md
    public func save(_ record: ServitorRecord) throws {
        try queue.sync {
            try ensureDirectory(name: record.name)
            let fileURL = servitorURL(name: record.name).appendingPathComponent("servitor.md")
            let content = serializeToFrontmatter(record)
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                Self.logger.debugLog("Saved servitor record for \(record.name) at \(fileURL.path)")
            } catch {
                Self.logger.debugError("Failed to write servitor.md for \(record.name): \(error.localizedDescription)")
                throw ServitorStoreError.writeFailed(fileURL, error)
            }
        }
    }

    /// Load a servitor record from its servitor.md file
    /// - Returns: The record if the file exists and can be parsed, nil if the file doesn't exist
    public func load(name: String) throws -> ServitorRecord? {
        try queue.sync {
            let fileURL = servitorURL(name: name).appendingPathComponent("servitor.md")
            guard fileManager.fileExists(atPath: fileURL.path) else {
                Self.logger.debugLog("No servitor.md found for \(name)")
                return nil
            }
            let content: String
            do {
                content = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                Self.logger.debugError("Failed to read servitor.md for \(name): \(error.localizedDescription)")
                throw ServitorStoreError.readFailed(fileURL, error)
            }
            guard let record = parseFromFrontmatter(content, fileURL: fileURL) else {
                throw ServitorStoreError.parseFailed(fileURL, "Failed to parse YAML frontmatter")
            }
            Self.logger.debugLog("Loaded servitor record for \(name)")
            return record
        }
    }

    /// List all persisted servitor records by scanning the servitors directory
    public func listAll() throws -> [ServitorRecord] {
        try queue.sync {
            let baseURL = servitorsBaseURL
            guard fileManager.fileExists(atPath: baseURL.path) else {
                Self.logger.debugLog("No servitors directory found at \(baseURL.path)")
                return []
            }

            let contents: [String]
            do {
                contents = try fileManager.contentsOfDirectory(atPath: baseURL.path)
            } catch {
                Self.logger.debugError("Failed to list servitors directory: \(error.localizedDescription)")
                throw ServitorStoreError.readFailed(baseURL, error)
            }

            var records: [ServitorRecord] = []
            for dirName in contents {
                let fileURL = baseURL
                    .appendingPathComponent(dirName, isDirectory: true)
                    .appendingPathComponent("servitor.md")
                guard fileManager.fileExists(atPath: fileURL.path) else { continue }
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    if let record = parseFromFrontmatter(content, fileURL: fileURL) {
                        records.append(record)
                    }
                } catch {
                    Self.logger.debugError("Failed to read \(fileURL.path): \(error.localizedDescription)")
                    // Continue loading other servitors rather than failing entirely
                }
            }

            Self.logger.debugLog("Listed \(records.count) servitor records")
            return records
        }
    }

    /// Remove a servitor's entire directory
    public func remove(name: String) throws {
        try queue.sync {
            let dirURL = servitorURL(name: name)
            guard fileManager.fileExists(atPath: dirURL.path) else {
                Self.logger.debugLog("No directory to remove for servitor \(name)")
                return
            }
            do {
                try fileManager.removeItem(at: dirURL)
                Self.logger.debugInfo("Removed servitor directory for \(name)")
            } catch {
                Self.logger.debugError("Failed to remove servitor directory for \(name): \(error.localizedDescription)")
                throw ServitorStoreError.writeFailed(dirURL, error)
            }
        }
    }

    // MARK: - Session Log (sessions.jsonl)

    /// Append a session event to the servitor's sessions.jsonl
    public func appendSessionEvent(_ event: SessionEvent, name: String) throws {
        try queue.sync {
            try ensureDirectory(name: name)
            let fileURL = servitorURL(name: name).appendingPathComponent("sessions.jsonl")

            let data: Data
            do {
                data = try Self.jsonEncoder.encode(event)
            } catch {
                Self.logger.debugError("Failed to encode session event for \(name): \(error.localizedDescription)")
                throw ServitorStoreError.writeFailed(fileURL, error)
            }

            guard var line = String(data: data, encoding: .utf8) else {
                Self.logger.debugError("Failed to convert session event data to UTF-8 string for \(name)")
                throw ServitorStoreError.writeFailed(fileURL, NSError(domain: "ServitorStore", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "UTF-8 encoding failed"
                ]))
            }
            line.append("\n")

            if fileManager.fileExists(atPath: fileURL.path) {
                // Append to existing file
                do {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    defer { try? handle.close() }
                    handle.seekToEndOfFile()
                    guard let lineData = line.data(using: .utf8) else {
                        throw NSError(domain: "ServitorStore", code: 2, userInfo: [
                            NSLocalizedDescriptionKey: "Failed to encode line as UTF-8"
                        ])
                    }
                    handle.write(lineData)
                } catch {
                    Self.logger.debugError("Failed to append session event for \(name): \(error.localizedDescription)")
                    throw ServitorStoreError.writeFailed(fileURL, error)
                }
            } else {
                // Create new file
                do {
                    try line.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    Self.logger.debugError("Failed to create sessions.jsonl for \(name): \(error.localizedDescription)")
                    throw ServitorStoreError.writeFailed(fileURL, error)
                }
            }

            Self.logger.debugLog("Appended \(event.event.rawValue) event for servitor \(name)")
        }
    }

    /// Load all session events from a servitor's sessions.jsonl
    public func loadSessionEvents(name: String) throws -> [SessionEvent] {
        try queue.sync {
            let fileURL = servitorURL(name: name).appendingPathComponent("sessions.jsonl")
            guard fileManager.fileExists(atPath: fileURL.path) else {
                Self.logger.debugLog("No sessions.jsonl found for servitor \(name)")
                return []
            }

            let content: String
            do {
                content = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                Self.logger.debugError("Failed to read sessions.jsonl for \(name): \(error.localizedDescription)")
                throw ServitorStoreError.readFailed(fileURL, error)
            }

            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var events: [SessionEvent] = []

            for (index, line) in lines.enumerated() {
                guard let lineData = line.data(using: .utf8) else {
                    Self.logger.debugError("Failed to convert line \(index) to data in sessions.jsonl for \(name)")
                    continue
                }
                do {
                    let event = try Self.jsonDecoder.decode(SessionEvent.self, from: lineData)
                    events.append(event)
                } catch {
                    Self.logger.debugError("Failed to parse line \(index) in sessions.jsonl for \(name): \(error.localizedDescription)")
                    // Continue parsing remaining lines
                }
            }

            Self.logger.debugLog("Loaded \(events.count) session events for servitor \(name)")
            return events
        }
    }

    // MARK: - YAML Frontmatter Serialization

    /// Serialize a ServitorRecord to YAML frontmatter format
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

        lines.append("created_at: \(Self.iso8601.string(from: record.createdAt))")
        lines.append("updated_at: \(Self.iso8601.string(from: record.updatedAt))")

        lines.append("---")
        lines.append("") // trailing newline

        return lines.joined(separator: "\n")
    }

    /// Parse a ServitorRecord from YAML frontmatter content
    private func parseFromFrontmatter(_ content: String, fileURL: URL) -> ServitorRecord? {
        // Extract frontmatter between --- delimiters
        let lines = content.components(separatedBy: .newlines)
        guard let firstDelim = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            Self.logger.debugError("No opening --- delimiter in \(fileURL.path)")
            return nil
        }

        let afterFirst = lines.index(after: firstDelim)
        guard afterFirst < lines.endIndex else {
            Self.logger.debugError("No content after opening --- in \(fileURL.path)")
            return nil
        }

        guard let secondDelim = lines[afterFirst...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            Self.logger.debugError("No closing --- delimiter in \(fileURL.path)")
            return nil
        }

        // Parse key-value pairs from frontmatter lines
        var fields: [String: String] = [:]
        for line in lines[afterFirst..<secondDelim] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Split on first colon
            guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            fields[key] = yamlUnescape(value)
        }

        // Required fields
        guard let name = fields["name"],
              let idString = fields["id"],
              let id = UUID(uuidString: idString),
              let createdAtString = fields["created_at"],
              let createdAt = Self.iso8601.date(from: createdAtString),
              let updatedAtString = fields["updated_at"],
              let updatedAt = Self.iso8601.date(from: updatedAtString) else {
            Self.logger.debugError("Missing required fields in \(fileURL.path)")
            return nil
        }

        // Session mode (default to .plan if missing or unrecognized)
        let sessionMode: PermissionMode
        if let modeString = fields["session_mode"],
           let mode = PermissionMode(rawValue: modeString) {
            sessionMode = mode
        } else {
            sessionMode = .plan
        }

        return ServitorRecord(
            name: name,
            id: id,
            assignment: fields["assignment"],
            sessionId: fields["session_id"],
            sessionMode: sessionMode,
            description: fields["description"],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - YAML Escaping Helpers

    /// Characters that require quoting in YAML values
    private static let yamlSpecialCharacters = CharacterSet(charactersIn: ":{}[]|>&*!#%@`'\",?")

    /// Escape a string for safe YAML serialization.
    /// Wraps the value in double quotes if it contains special characters,
    /// escaping internal double quotes and backslashes.
    private func yamlEscape(_ value: String) -> String {
        let needsQuoting = value.isEmpty
            || value.unicodeScalars.contains(where: { Self.yamlSpecialCharacters.contains($0) })
            || value.hasPrefix(" ")
            || value.hasSuffix(" ")
            || value.contains("\n")

        guard needsQuoting else { return value }

        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    /// Unescape a YAML value, removing surrounding quotes and processing escape sequences
    private func yamlUnescape(_ value: String) -> String {
        var s = value

        // Remove surrounding double quotes
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            s = String(s.dropFirst().dropLast())
            s = s.replacingOccurrences(of: "\\n", with: "\n")
            s = s.replacingOccurrences(of: "\\\"", with: "\"")
            s = s.replacingOccurrences(of: "\\\\", with: "\\")
        }

        // Remove surrounding single quotes (no escape processing)
        if s.hasPrefix("'") && s.hasSuffix("'") && s.count >= 2 {
            s = String(s.dropFirst().dropLast())
        }

        return s
    }
}
