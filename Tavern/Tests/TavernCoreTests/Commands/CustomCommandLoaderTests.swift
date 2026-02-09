import Foundation
import Testing
@testable import TavernCore

@Suite("CustomCommandLoader Tests")
struct CustomCommandLoaderTests {

    // MARK: - Helper

    /// Create a temporary directory structure for testing
    private func createTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tavern-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Write a file at a path, creating intermediate directories
    private func writeFile(_ content: String, at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Clean up a temporary directory
    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Command Name Derivation

    @Test("Simple filename becomes command name")
    func simpleFilename() {
        let base = URL(fileURLWithPath: "/commands")
        let file = URL(fileURLWithPath: "/commands/review.md")
        let name = CustomCommandLoader.deriveCommandName(fileURL: file, baseURL: base)
        #expect(name == "review")
    }

    @Test("Subdirectory creates colon-separated namespace")
    func subdirectoryNamespace() {
        let base = URL(fileURLWithPath: "/commands")
        let file = URL(fileURLWithPath: "/commands/git/amend.md")
        let name = CustomCommandLoader.deriveCommandName(fileURL: file, baseURL: base)
        #expect(name == "git:amend")
    }

    @Test("Nested subdirectories create multi-level namespace")
    func nestedNamespace() {
        let base = URL(fileURLWithPath: "/commands")
        let file = URL(fileURLWithPath: "/commands/project/deploy/staging.md")
        let name = CustomCommandLoader.deriveCommandName(fileURL: file, baseURL: base)
        #expect(name == "project:deploy:staging")
    }

    @Test("Command name is lowercased")
    func commandNameLowercased() {
        let base = URL(fileURLWithPath: "/commands")
        let file = URL(fileURLWithPath: "/commands/MyCommand.md")
        let name = CustomCommandLoader.deriveCommandName(fileURL: file, baseURL: base)
        #expect(name == "mycommand")
    }

    // MARK: - Description Derivation

    @Test("Markdown heading becomes description")
    func headingDescription() {
        let desc = CustomCommandLoader.deriveDescription(
            from: "# Code Review Helper\nReview the code...",
            commandName: "review"
        )
        #expect(desc == "Code Review Helper")
    }

    @Test("Short first line becomes description")
    func shortFirstLine() {
        let desc = CustomCommandLoader.deriveDescription(
            from: "Deploy to production\n$ARGUMENTS",
            commandName: "deploy"
        )
        #expect(desc == "Deploy to production")
    }

    @Test("Template-like first line falls back to default")
    func templateFirstLine() {
        let desc = CustomCommandLoader.deriveDescription(
            from: "$ARGUMENTS should be reviewed carefully",
            commandName: "review"
        )
        #expect(desc == "Custom command: /review")
    }

    @Test("Empty content falls back to default")
    func emptyContent() {
        let desc = CustomCommandLoader.deriveDescription(
            from: "",
            commandName: "test"
        )
        #expect(desc == "Custom command: /test")
    }

    // MARK: - Directory Discovery

    @Test("Discovers .md files in commands directory")
    func discoversFiles() throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }

        let commandsDir = tempDir.appendingPathComponent(".claude/commands").path
        try writeFile("Review code: $ARGUMENTS", at: "\(commandsDir)/review.md")
        try writeFile("# Deploy\nDeploy to $1", at: "\(commandsDir)/deploy.md")

        let commands = CustomCommandLoader.loadCommands(
            projectPath: tempDir.path,
            userHome: "/nonexistent"
        )

        #expect(commands.count == 2)
        let names = commands.map(\.name).sorted()
        #expect(names == ["deploy", "review"])
    }

    @Test("Discovers subdirectory namespaced commands")
    func discoversSubdirectoryCommands() throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }

        let commandsDir = tempDir.appendingPathComponent(".claude/commands").path
        try writeFile("Amend commit", at: "\(commandsDir)/git/amend.md")
        try writeFile("Push to remote", at: "\(commandsDir)/git/push.md")
        try writeFile("Top level", at: "\(commandsDir)/status.md")

        let commands = CustomCommandLoader.loadCommands(
            projectPath: tempDir.path,
            userHome: "/nonexistent"
        )

        #expect(commands.count == 3)
        let names = commands.map(\.name).sorted()
        #expect(names == ["git:amend", "git:push", "status"])
    }

    @Test("Non-.md files are ignored")
    func ignoresNonMdFiles() throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }

        let commandsDir = tempDir.appendingPathComponent(".claude/commands").path
        try writeFile("Valid command", at: "\(commandsDir)/valid.md")
        try writeFile("Not a command", at: "\(commandsDir)/readme.txt")
        try writeFile("Also not", at: "\(commandsDir)/script.sh")

        let commands = CustomCommandLoader.loadCommands(
            projectPath: tempDir.path,
            userHome: "/nonexistent"
        )

        #expect(commands.count == 1)
        #expect(commands[0].name == "valid")
    }

    @Test("Missing directory returns empty array gracefully")
    func missingDirectoryGraceful() {
        let commands = CustomCommandLoader.loadCommands(
            projectPath: "/nonexistent/path",
            userHome: "/also/nonexistent"
        )
        #expect(commands.isEmpty)
    }

    // MARK: - Project vs User Precedence

    @Test("Project commands override user commands with same name")
    func projectOverridesUser() throws {
        let projectDir = try createTempDir()
        let userDir = try createTempDir()
        defer { cleanup(projectDir); cleanup(userDir) }

        let projectCmdsDir = projectDir.appendingPathComponent(".claude/commands").path
        let userCmdsDir = userDir.appendingPathComponent(".claude/commands").path

        try writeFile("Project version", at: "\(projectCmdsDir)/review.md")
        try writeFile("User version", at: "\(userCmdsDir)/review.md")
        try writeFile("User only", at: "\(userCmdsDir)/deploy.md")

        let commands = CustomCommandLoader.loadCommands(
            projectPath: projectDir.path,
            userHome: userDir.path
        )

        #expect(commands.count == 2)

        let review = commands.first { $0.name == "review" }
        #expect(review?.source == .project)
        #expect(review?.template == "Project version")

        let deploy = commands.first { $0.name == "deploy" }
        #expect(deploy?.source == .user)
    }

    @Test("All commands from both sources are returned when no conflicts")
    func bothSourcesCombined() throws {
        let projectDir = try createTempDir()
        let userDir = try createTempDir()
        defer { cleanup(projectDir); cleanup(userDir) }

        let projectCmdsDir = projectDir.appendingPathComponent(".claude/commands").path
        let userCmdsDir = userDir.appendingPathComponent(".claude/commands").path

        try writeFile("Project cmd A", at: "\(projectCmdsDir)/alpha.md")
        try writeFile("User cmd B", at: "\(userCmdsDir)/beta.md")

        let commands = CustomCommandLoader.loadCommands(
            projectPath: projectDir.path,
            userHome: userDir.path
        )

        #expect(commands.count == 2)
        let names = Set(commands.map(\.name))
        #expect(names == ["alpha", "beta"])
    }

    // MARK: - Source Assignment

    @Test("Project commands have source .project")
    func projectSource() throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }

        let commandsDir = tempDir.appendingPathComponent(".claude/commands").path
        try writeFile("template", at: "\(commandsDir)/test.md")

        let commands = CustomCommandLoader.loadCommands(
            projectPath: tempDir.path,
            userHome: "/nonexistent"
        )

        #expect(commands.count == 1)
        #expect(commands[0].source == .project)
    }

    @Test("User commands have source .user")
    func userSource() throws {
        let tempDir = try createTempDir()
        defer { cleanup(tempDir) }

        let commandsDir = tempDir.appendingPathComponent(".claude/commands").path
        try writeFile("template", at: "\(commandsDir)/test.md")

        let commands = CustomCommandLoader.loadCommands(
            projectPath: "/nonexistent",
            userHome: tempDir.path
        )

        #expect(commands.count == 1)
        #expect(commands[0].source == .user)
    }
}
