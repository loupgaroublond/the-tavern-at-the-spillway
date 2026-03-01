import Foundation

@MainActor
public protocol ResourceProvider: Sendable {
    func scanDirectory(at url: URL) throws -> [FileTreeNode]
    func scanChildren(of node: FileTreeNode) throws -> [FileTreeNode]
    func readFile(at url: URL) throws -> String
    func isFileTooLarge(at url: URL) -> Bool
    func isBinaryFile(at url: URL) -> Bool
}
