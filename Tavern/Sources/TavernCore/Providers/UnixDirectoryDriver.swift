import Foundation
import TavernKit
import os.log

// MARK: - Provenance: REQ-ARCH-003

@MainActor
public final class UnixDirectoryDriver: ProjectProvider {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "project")

    public init() {}

    public func openProject(at url: URL) async throws -> any ProjectHandle {
        Self.logger.info("[UnixDirectoryDriver] opening project at: \(url.path)")
        return DirectoryProjectHandle(rootURL: url)
    }
}

@MainActor
final class DirectoryProjectHandle: ProjectHandle {
    let id: UUID
    let rootURL: URL
    let name: String
    let isReady: Bool = true

    init(rootURL: URL) {
        self.id = UUID()
        self.rootURL = rootURL
        self.name = rootURL.lastPathComponent
    }
}
