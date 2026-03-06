import Foundation
import TavernKit
import os.log

// MARK: - Provenance: REQ-ARCH-003

public final class UnixDirectoryDriver: ProjectProvider {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "project")

    public init() {}

    public func openProject(at url: URL) async throws -> any ProjectHandle {
        Self.logger.info("[UnixDirectoryDriver] opening project at: \(url.path)")
        return ProjectDirectory(rootURL: url)
    }
}
