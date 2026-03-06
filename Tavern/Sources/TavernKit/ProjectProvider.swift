import Foundation

public protocol ProjectProvider: Sendable {
    func openProject(at url: URL) async throws -> any ProjectHandle
}

public protocol ProjectHandle: AnyObject, Identifiable, Sendable {
    var id: UUID { get }
    var rootURL: URL { get }
    var name: String { get }
    var isReady: Bool { get }
}
