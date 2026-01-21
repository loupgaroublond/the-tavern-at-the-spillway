import Foundation

/// Errors that can occur during doc store operations
public enum DocStoreError: Error, Equatable {
    case documentNotFound(String)
    case documentAlreadyExists(String)
    case invalidDirectory
    case fileSystemError(String)
}

/// A file-based document store
/// Stores markdown documents with YAML frontmatter in a directory
public final class DocStore: @unchecked Sendable {

    // MARK: - Properties

    /// The root directory for documents
    public let rootDirectory: URL

    /// File extension for documents
    public let fileExtension: String

    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.tavern.DocStore")

    // MARK: - Initialization

    /// Create a doc store at the specified directory
    /// - Parameters:
    ///   - rootDirectory: Directory to store documents in
    ///   - fileExtension: Extension for document files (default: "md")
    ///   - createIfNeeded: Whether to create the directory if it doesn't exist
    /// - Throws: If directory creation fails
    public init(
        rootDirectory: URL,
        fileExtension: String = "md",
        createIfNeeded: Bool = true
    ) throws {
        self.rootDirectory = rootDirectory
        self.fileExtension = fileExtension
        self.fileManager = FileManager.default

        if createIfNeeded {
            try fileManager.createDirectory(
                at: rootDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Verify directory exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw DocStoreError.invalidDirectory
        }
    }

    // MARK: - CRUD Operations

    /// Create a new document
    /// - Parameter document: The document to create
    /// - Throws: If document already exists or write fails
    public func create(_ document: Document) throws {
        try queue.sync {
            let fileURL = self.fileURL(for: document.id)

            if fileManager.fileExists(atPath: fileURL.path) {
                throw DocStoreError.documentAlreadyExists(document.id)
            }

            let content = document.render()
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                throw DocStoreError.fileSystemError(error.localizedDescription)
            }
        }
    }

    /// Read a document by ID
    /// - Parameter id: The document identifier
    /// - Returns: The document
    /// - Throws: If document doesn't exist or read fails
    public func read(id: String) throws -> Document {
        try queue.sync {
            let fileURL = self.fileURL(for: id)

            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw DocStoreError.documentNotFound(id)
            }

            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                return Document.parse(id: id, from: content)
            } catch {
                throw DocStoreError.fileSystemError(error.localizedDescription)
            }
        }
    }

    /// Update an existing document
    /// - Parameter document: The updated document
    /// - Throws: If document doesn't exist or write fails
    public func update(_ document: Document) throws {
        try queue.sync {
            let fileURL = self.fileURL(for: document.id)

            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw DocStoreError.documentNotFound(document.id)
            }

            var updatedDoc = document
            updatedDoc.updatedAt = Date()

            let content = updatedDoc.render()
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                throw DocStoreError.fileSystemError(error.localizedDescription)
            }
        }
    }

    /// Delete a document
    /// - Parameter id: The document identifier
    /// - Throws: If document doesn't exist or delete fails
    public func delete(id: String) throws {
        try queue.sync {
            let fileURL = self.fileURL(for: id)

            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw DocStoreError.documentNotFound(id)
            }

            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                throw DocStoreError.fileSystemError(error.localizedDescription)
            }
        }
    }

    /// Check if a document exists
    /// - Parameter id: The document identifier
    /// - Returns: true if the document exists
    public func exists(id: String) -> Bool {
        queue.sync {
            let fileURL = self.fileURL(for: id)
            return fileManager.fileExists(atPath: fileURL.path)
        }
    }

    /// List all document IDs in the store
    /// - Returns: Array of document IDs
    /// - Throws: If directory listing fails
    public func listAll() throws -> [String] {
        try queue.sync {
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: rootDirectory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                return contents
                    .filter { $0.pathExtension == fileExtension }
                    .map { $0.deletingPathExtension().lastPathComponent }
                    .sorted()
            } catch {
                throw DocStoreError.fileSystemError(error.localizedDescription)
            }
        }
    }

    /// Read all documents in the store
    /// - Returns: Array of all documents
    /// - Throws: If reading fails
    public func readAll() throws -> [Document] {
        let ids = try listAll()
        return ids.compactMap { id in
            try? read(id: id)
        }
    }

    // MARK: - Convenience Methods

    /// Create or update a document
    /// - Parameter document: The document to save
    /// - Throws: If save fails
    public func save(_ document: Document) throws {
        if exists(id: document.id) {
            try update(document)
        } else {
            try create(document)
        }
    }

    // MARK: - Private Helpers

    private func fileURL(for id: String) -> URL {
        rootDirectory.appendingPathComponent("\(id).\(fileExtension)")
    }
}
