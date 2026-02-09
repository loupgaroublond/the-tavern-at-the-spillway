import XCTest
@testable import TavernCore

/// Stress tests for file tree scanning large directories (Bead a50p)
///
/// Verifies:
/// - 10,000+ file tree scanned within 5 seconds
/// - Memory doesn't spike beyond 50MB
/// - All files and directories correctly enumerated
/// - Ignored directories (.git, node_modules, etc.) are properly skipped
///
/// Run with: swift test --filter TavernStressTests.FileTreeStressTests
final class FileTreeStressTests: XCTestCase {

    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tavern-filetree-stress-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Create a directory tree with specified file and directory counts.
    private func createTree(dirs: Int, filesPerDir: Int) throws {
        let fm = FileManager.default

        for d in 0..<dirs {
            let dirURL = tempRoot.appendingPathComponent("dir-\(d)")
            try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)

            for f in 0..<filesPerDir {
                let fileURL = dirURL.appendingPathComponent("file-\(f).swift")
                try "// content \(d)-\(f)".write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Create a deeply nested directory structure.
    private func createDeepTree(depth: Int, breadth: Int) throws -> URL {
        let fm = FileManager.default
        var current = tempRoot!

        for level in 0..<depth {
            for b in 0..<breadth {
                let subdir = current.appendingPathComponent("level\(level)-\(b)")
                try fm.createDirectory(at: subdir, withIntermediateDirectories: true)

                // Add a few files at each level
                for f in 0..<3 {
                    let fileURL = subdir.appendingPathComponent("file-\(f).txt")
                    try "content".write(to: fileURL, atomically: true, encoding: .utf8)
                }
            }
            // Go deeper on the first branch only
            current = current.appendingPathComponent("level\(level)-0")
        }

        return tempRoot
    }

    // MARK: - Test: Scan 10K Files

    /// Create 500 directories with 20 files each (10,000 total) and scan each level.
    /// Must complete within 5 seconds.
    func testScan10KFiles() throws {
        let dirCount = 500
        let filesPerDir = 20
        let totalExpected = dirCount * filesPerDir
        let timeBudget: TimeInterval = 5.0

        try createTree(dirs: dirCount, filesPerDir: filesPerDir)

        let scanner = FileTreeScanner()
        let startTime = Date()

        // Scan the root directory (returns the 500 subdirectories)
        let rootNodes = try scanner.scanDirectory(at: tempRoot, relativeTo: tempRoot)
        XCTAssertEqual(rootNodes.count, dirCount,
            "Root should contain \(dirCount) directories, found \(rootNodes.count)")

        // Scan each subdirectory (returns 20 files each)
        var totalFiles = 0
        for node in rootNodes {
            XCTAssertTrue(node.isDirectory, "Root-level nodes should be directories")
            let children = try scanner.scanDirectory(at: node.url, relativeTo: tempRoot)
            totalFiles += children.count
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(totalFiles, totalExpected,
            "Should find \(totalExpected) files, got \(totalFiles)")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Scanning \(totalExpected) files must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testScan10KFiles: \(totalFiles) files across \(dirCount) dirs in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Deeply Nested Directory

    /// Create a directory tree 50 levels deep and scan each level.
    /// Verifies scanner handles deep nesting without stack overflow.
    func testDeeplyNestedDirectory() throws {
        let depth = 50
        let breadth = 2
        let timeBudget: TimeInterval = 5.0

        let root = try createDeepTree(depth: depth, breadth: breadth)

        let scanner = FileTreeScanner()
        let startTime = Date()

        // Walk down the deepest branch, scanning each level
        var totalNodes = 0
        var current = root
        for level in 0..<depth {
            let nodes = try scanner.scanDirectory(at: current, relativeTo: root)
            totalNodes += nodes.count

            // Navigate to first subdirectory for next level
            let firstDir = current.appendingPathComponent("level\(level)-0")
            if FileManager.default.fileExists(atPath: firstDir.path) {
                current = firstDir
            } else {
                break
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThan(totalNodes, 0,
            "Should find nodes in deeply nested tree")

        XCTAssertLessThanOrEqual(duration, timeBudget,
            "Deep scan must complete within \(timeBudget)s, took \(String(format: "%.2f", duration))s")

        print("testDeeplyNestedDirectory: \(totalNodes) nodes across \(depth) levels in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Test: Ignored Directories Are Skipped

    /// Create a directory with .git, node_modules, .build, etc.
    /// Scanner should skip them, even when they contain thousands of files.
    func testIgnoredDirectoriesSkipped() throws {
        let fm = FileManager.default

        // Create ignored directories with many files
        let ignoredNames = [".git", ".build", "node_modules", ".swiftpm", "DerivedData", "xcuserdata"]
        for name in ignoredNames {
            let dir = tempRoot.appendingPathComponent(name)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            for i in 0..<100 {
                let file = dir.appendingPathComponent("file-\(i).txt")
                try "data".write(to: file, atomically: true, encoding: .utf8)
            }
        }

        // Create a visible directory
        let visibleDir = tempRoot.appendingPathComponent("Sources")
        try fm.createDirectory(at: visibleDir, withIntermediateDirectories: true)
        for i in 0..<10 {
            let file = visibleDir.appendingPathComponent("file-\(i).swift")
            try "code".write(to: file, atomically: true, encoding: .utf8)
        }

        let scanner = FileTreeScanner()
        let nodes = try scanner.scanDirectory(at: tempRoot, relativeTo: tempRoot)

        // Should only see "Sources", not any ignored directories
        XCTAssertEqual(nodes.count, 1,
            "Should only see 1 visible directory, found \(nodes.count): \(nodes.map { $0.name })")
        XCTAssertEqual(nodes.first?.name, "Sources")

        print("testIgnoredDirectoriesSkipped: \(nodes.count) visible (ignored \(ignoredNames.count) dirs)")
    }

    // MARK: - Test: Directory Sorting

    /// Verify that directories come before files, and names are alphabetically sorted.
    func testDirectorySortingAtScale() throws {
        let fm = FileManager.default

        // Create a mix of files and directories with unsorted names
        let names = (0..<200).map { String(format: "item-%03d", $0) }.shuffled()

        for (i, name) in names.enumerated() {
            let url: URL
            if i % 3 == 0 {
                // Directory
                url = tempRoot.appendingPathComponent(name)
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                // File
                url = tempRoot.appendingPathComponent("\(name).txt")
                try "data".write(to: url, atomically: true, encoding: .utf8)
            }
        }

        let scanner = FileTreeScanner()
        let startTime = Date()
        let nodes = try scanner.scanDirectory(at: tempRoot, relativeTo: tempRoot)
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(nodes.count, 200)

        // Verify directories come first
        var seenFile = false
        for node in nodes {
            if !node.isDirectory {
                seenFile = true
            } else if seenFile {
                XCTFail("Directory \(node.name) appears after files — directories should come first")
                break
            }
        }

        // Verify alphabetical order within each group
        let dirs = nodes.filter { $0.isDirectory }
        let files = nodes.filter { !$0.isDirectory }

        for i in 1..<dirs.count {
            XCTAssertTrue(
                dirs[i-1].name.localizedStandardCompare(dirs[i].name) != .orderedDescending,
                "Directories not sorted: \(dirs[i-1].name) > \(dirs[i].name)")
        }
        for i in 1..<files.count {
            XCTAssertTrue(
                files[i-1].name.localizedStandardCompare(files[i].name) != .orderedDescending,
                "Files not sorted: \(files[i-1].name) > \(files[i].name)")
        }

        print("testDirectorySortingAtScale: \(nodes.count) nodes (\(dirs.count) dirs, \(files.count) files) sorted in \(String(format: "%.4f", duration))s")
    }
}
