import Foundation
import TavernKit

/// Stub resource provider for tile tests. Configurable responses, no disk I/O.
final class StubResourceProvider: @unchecked Sendable, ResourceProvider {
    var scanResult: [FileTreeNode] = []
    var childrenResult: [FileTreeNode] = []
    var fileContent: String = ""
    var isBinary: Bool = false
    var isTooLarge: Bool = false
    var scanError: Error?
    var readError: Error?

    func scanDirectory(at url: URL) throws -> [FileTreeNode] {
        if let error = scanError { throw error }
        return scanResult
    }

    func scanChildren(of node: FileTreeNode) throws -> [FileTreeNode] {
        return childrenResult
    }

    func readFile(at url: URL) throws -> String {
        if let error = readError { throw error }
        return fileContent
    }

    func isFileTooLarge(at url: URL) -> Bool { isTooLarge }
    func isBinaryFile(at url: URL) -> Bool { isBinary }
}
