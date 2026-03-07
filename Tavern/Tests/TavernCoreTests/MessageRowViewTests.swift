// MARK: - Provenance: REQ-UX-005, REQ-UX-006, REQ-VIW-001, REQ-VIW-003

import SwiftUI
import Testing
import ViewInspector
@testable import ChatTile
@testable import TavernKit

// MARK: - Message Row View Tests

@MainActor
@Suite("MessageRowView — content block rendering & stream separation",
       .tags(.reqUX005, .reqUX006, .reqVIW001, .reqVIW003),
       .timeLimit(.minutes(2)))
struct MessageRowViewTests {

    // MARK: - Text Messages (REQ-UX-006: text block rendering)

    @Test("Text message renders content string")
    func textMessageRendersContent() throws {
        let message = ChatMessage.text(role: .user, content: "Hello Jake!")
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        // The text message row should contain the message content
        let texts = sut.findAll(ViewType.Text.self)
        let contentStrings = texts.compactMap { try? $0.string() }
        #expect(contentStrings.contains("Hello Jake!"))
    }

    @Test("User text message shows 'You' header label")
    func userTextMessageShowsYouHeader() throws {
        let message = ChatMessage.text(role: .user, content: "Hi there")
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let contentStrings = texts.compactMap { try? $0.string() }
        #expect(contentStrings.contains("You"))
    }

    @Test("Agent text message shows agent name header label")
    func agentTextMessageShowsAgentName() throws {
        let message = ChatMessage.text(role: .agent, content: "Well HOWDY!")
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let contentStrings = texts.compactMap { try? $0.string() }
        #expect(contentStrings.contains("Jake"))
    }

    // MARK: - Stream Separation (REQ-UX-005)

    @Test("User and agent messages use different avatar colors for stream separation")
    func userAndAgentAvatarColorsDiffer() throws {
        let userMsg = ChatMessage.text(role: .user, content: "question")
        let agentMsg = ChatMessage.text(role: .agent, content: "answer")

        let userView = MessageRowView(message: userMsg, agentName: "Jake")
        let agentView = MessageRowView(message: agentMsg, agentName: "Jake")

        // Both should render without error (visual distinction verified by structure)
        let userSut = try userView.inspect()
        let agentSut = try agentView.inspect()

        // User avatar uses person.fill icon, agent uses star.fill
        let userImages = userSut.findAll(ViewType.Image.self)
        let agentImages = agentSut.findAll(ViewType.Image.self)

        let userSystemNames = userImages.compactMap { try? $0.actualImage().name() }
        let agentSystemNames = agentImages.compactMap { try? $0.actualImage().name() }

        #expect(userSystemNames.contains("person.fill"),
                "User messages should show person.fill avatar icon")
        #expect(agentSystemNames.contains("star.fill"),
                "Agent messages should show star.fill avatar icon")
    }

    @Test("User header says 'You', agent header says agent name — stream labels differ")
    func streamLabelsDistinguishUserFromAgent() throws {
        let userMsg = ChatMessage.text(role: .user, content: "input")
        let agentMsg = ChatMessage.text(role: .agent, content: "output")

        let userView = MessageRowView(message: userMsg, agentName: "Marcos Antonio")
        let agentView = MessageRowView(message: agentMsg, agentName: "Marcos Antonio")

        let userTexts = try userView.inspect().findAll(ViewType.Text.self)
            .compactMap { try? $0.string() }
        let agentTexts = try agentView.inspect().findAll(ViewType.Text.self)
            .compactMap { try? $0.string() }

        #expect(userTexts.contains("You"))
        #expect(!userTexts.contains("Marcos Antonio"),
                "User message header must not show agent name")
        #expect(agentTexts.contains("Marcos Antonio"))
        #expect(!agentTexts.contains("You"),
                "Agent message header must not show 'You'")
    }

    // MARK: - Content Block Types (REQ-UX-006)

    @Test("Tool use message renders as collapsible block with tool name")
    func toolUseRendersCollapsibleBlock() throws {
        let message = ChatMessage.toolUse(name: "bash", input: "ls -la")
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        // Should contain the tool name in a Text element
        let texts = sut.findAll(ViewType.Text.self)
        let contentStrings = texts.compactMap { try? $0.string() }
        #expect(contentStrings.contains(where: { $0.contains("bash") }),
                "Tool use block should display the tool name 'bash'")
    }

    @Test("Tool result message renders as collapsible block")
    func toolResultRendersCollapsibleBlock() throws {
        let message = ChatMessage.toolResult(content: "file1.txt\nfile2.txt")
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let contentStrings = texts.compactMap { try? $0.string() }
        // The collapsible label for tool results is "Result"
        #expect(contentStrings.contains(where: { $0.contains("Result") }),
                "Tool result block should display 'Result' label")
    }

    @Test("Tool error message renders as collapsible block with error label")
    func toolErrorRendersCollapsibleBlock() throws {
        let message = ChatMessage.toolResult(content: "Permission denied", isError: true)
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let contentStrings = texts.compactMap { try? $0.string() }
        #expect(contentStrings.contains(where: { $0.contains("Error") }),
                "Tool error block should display 'Error' label")
    }

    @Test("Thinking message renders as collapsible block with thinking label")
    func thinkingRendersCollapsibleBlock() throws {
        let message = ChatMessage.thinking(content: "Let me think about this...")
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let contentStrings = texts.compactMap { try? $0.string() }
        #expect(contentStrings.contains(where: { $0.contains("Thinking") }),
                "Thinking block should display 'Thinking' label")
    }

    @Test("Session break message renders divider with session expired text")
    func sessionBreakRendersExpiredText() throws {
        let message = ChatMessage.sessionBreak(staleSessionId: "old-session-123")
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let contentStrings = texts.compactMap { try? $0.string() }
        #expect(contentStrings.contains(where: { $0.contains("Session expired") }),
                "Session break should display 'Session expired' message")

        // Should also contain Divider elements
        let dividers = sut.findAll(ViewType.Divider.self)
        #expect(dividers.count >= 2, "Session break should have at least 2 dividers")
    }

    @Test("Web search message renders with web search label")
    func webSearchRendersLabel() throws {
        let message = ChatMessage(
            role: .agent, content: "Searching for: Swift concurrency",
            messageType: .webSearch
        )
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let contentStrings = texts.compactMap { try? $0.string() }
        #expect(contentStrings.contains(where: { $0.contains("Web Search") }),
                "Web search block should display 'Web Search' label")
    }

    // MARK: - Composable View Surface (REQ-VIW-001)

    @Test("All message types render without crashing — composable surface integrity")
    func allMessageTypesRenderWithoutCrashing() throws {
        let messages: [ChatMessage] = [
            .text(role: .user, content: "User text"),
            .text(role: .agent, content: "Agent text"),
            .toolUse(name: "Read", input: "/path/to/file"),
            .toolResult(content: "file contents here"),
            .toolResult(content: "something broke", isError: true),
            .thinking(content: "Pondering the universe"),
            .sessionBreak(staleSessionId: "sess-expired"),
            ChatMessage(role: .agent, content: "Searching...", messageType: .webSearch),
        ]

        for message in messages {
            let view = MessageRowView(message: message, agentName: "Jake")
            let sut = try view.inspect()
            #expect(sut.findAll(ViewType.Text.self).count > 0,
                    "Message type '\(message.messageType.rawValue)' should render at least one Text")
        }
    }

    @Test("MessageRowView accepts different agent names — reusable across servitors")
    func reusableAcrossServitors() throws {
        let message = ChatMessage.text(role: .agent, content: "Response")

        for name in ["Jake", "Marcos Antonio", "Hyun-ji", "Biscuit"] {
            let sut = try MessageRowView(message: message, agentName: name).inspect()
            let texts = sut.findAll(ViewType.Text.self).compactMap { try? $0.string() }
            #expect(texts.contains(name),
                    "Agent name '\(name)' should appear in the rendered header")
        }
    }

    // MARK: - Granular View Primitives (REQ-VIW-003)

    @Test("Text message row contains avatar Circle, header label, content Text, and timestamp")
    func textMessageStructuralElements() throws {
        let message = ChatMessage.text(role: .user, content: "Test content")
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        // Avatar: Circle shape
        let circles = sut.findAll(ViewType.Shape.self)
        #expect(circles.count >= 1, "Text message should contain at least one Circle (avatar)")

        // Content text
        let texts = sut.findAll(ViewType.Text.self)
        let strings = texts.compactMap { try? $0.string() }
        #expect(strings.contains("Test content"), "Content text should be rendered")
        #expect(strings.contains("You"), "Header label should be rendered")

        // Timestamp (any Text with time-like format — at minimum there should be
        // more texts than just content + header)
        #expect(texts.count >= 3,
                "Should have at least content, header, and timestamp Text elements")
    }

    @Test("Collapsible blocks contain DisclosureGroup for expand/collapse")
    func collapsibleBlocksContainDisclosureGroup() throws {
        let toolUse = ChatMessage.toolUse(name: "Write", input: "content")
        let view = MessageRowView(message: toolUse, agentName: "Jake")
        let sut = try view.inspect()

        let disclosureGroups = sut.findAll(ViewType.DisclosureGroup.self)
        #expect(disclosureGroups.count >= 1,
                "Tool use block should contain a DisclosureGroup")
    }

    @Test("Tool result with diff content renders DiffCollapsibleBlock")
    func toolResultWithDiffContentRendersDiffBlock() throws {
        let diffContent = """
        --- a/file.swift
        +++ b/file.swift
        @@ -1,3 +1,3 @@
        -let old = true
        +let new = true
        """
        let message = ChatMessage.toolResult(content: diffContent)
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        // Diff blocks show "File Edit" label
        let texts = sut.findAll(ViewType.Text.self)
        let strings = texts.compactMap { try? $0.string() }
        #expect(strings.contains("File Edit"),
                "Diff tool result should render as DiffCollapsibleBlock with 'File Edit' label")
    }

    @Test("Non-diff tool result renders standard CollapsibleBlockView")
    func nonDiffToolResultRendersStandardBlock() throws {
        let message = ChatMessage.toolResult(content: "plain output text")
        let view = MessageRowView(message: message, agentName: "Jake")
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let strings = texts.compactMap { try? $0.string() }
        #expect(strings.contains(where: { $0.contains("Result") }),
                "Non-diff tool result should use standard 'Result' label")
        #expect(!strings.contains("File Edit"),
                "Non-diff tool result must not show 'File Edit' label")
    }
}

// MARK: - CollapsibleBlockView Primitive Tests

@MainActor
@Suite("CollapsibleBlockView — granular block primitives",
       .tags(.reqUX006, .reqVIW003),
       .timeLimit(.minutes(2)))
struct CollapsibleBlockViewTests {

    @Test("Each block type has correct label text")
    func blockTypeLabels() {
        let cases: [(CollapsibleBlockView.BlockType, String)] = [
            (.toolUse(name: "bash"), "Tool: bash"),
            (.toolUse(name: nil), "Tool Use"),
            (.toolResult, "Result"),
            (.toolError, "Error"),
            (.thinking, "Thinking"),
            (.webSearch, "Web Search"),
        ]

        for (blockType, expected) in cases {
            #expect(blockType.label == expected,
                    "BlockType label mismatch for \(expected)")
        }
    }

    @Test("Each block type has correct icon name")
    func blockTypeIcons() {
        #expect(CollapsibleBlockView.BlockType.toolUse(name: nil).icon == "hammer.fill")
        #expect(CollapsibleBlockView.BlockType.toolResult.icon == "checkmark.circle.fill")
        #expect(CollapsibleBlockView.BlockType.toolError.icon == "exclamationmark.triangle.fill")
        #expect(CollapsibleBlockView.BlockType.thinking.icon == "brain")
        #expect(CollapsibleBlockView.BlockType.webSearch.icon == "globe")
    }

    @Test("Tool error defaults to expanded, others default to collapsed")
    func defaultExpandedState() {
        #expect(CollapsibleBlockView.BlockType.toolUse(name: nil).defaultExpanded == false)
        #expect(CollapsibleBlockView.BlockType.toolResult.defaultExpanded == false)
        #expect(CollapsibleBlockView.BlockType.toolError.defaultExpanded == true)
        #expect(CollapsibleBlockView.BlockType.thinking.defaultExpanded == false)
        #expect(CollapsibleBlockView.BlockType.webSearch.defaultExpanded == true)
    }

    @Test("CollapsibleBlockView renders label text from block type")
    func rendersLabelText() throws {
        let view = CollapsibleBlockView(
            blockType: .toolUse(name: "Read"),
            content: "file.txt"
        )
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let strings = texts.compactMap { try? $0.string() }
        #expect(strings.contains(where: { $0.contains("Read") }),
                "Should display tool name 'Read' in label")
    }

    @Test("CollapsibleBlockView renders icon matching block type")
    func rendersMatchingIcon() throws {
        let view = CollapsibleBlockView(
            blockType: .thinking,
            content: "deep thoughts"
        )
        let sut = try view.inspect()

        let images = sut.findAll(ViewType.Image.self)
        let names = images.compactMap { try? $0.actualImage().name() }
        #expect(names.contains("brain"),
                "Thinking block should render brain icon")
    }

    @Test("Streaming block shows ProgressView spinner")
    func streamingShowsProgressView() throws {
        let view = CollapsibleBlockView(
            blockType: .toolUse(name: "bash"),
            content: "running...",
            isStreaming: true
        )
        let sut = try view.inspect()

        let progressViews = sut.findAll(ViewType.ProgressView.self)
        #expect(progressViews.count >= 1,
                "Streaming collapsible block should show a ProgressView")
    }

    @Test("Non-streaming block does not show ProgressView")
    func nonStreamingHidesProgressView() throws {
        let view = CollapsibleBlockView(
            blockType: .toolUse(name: "bash"),
            content: "done",
            isStreaming: false
        )
        let sut = try view.inspect()

        let progressViews = sut.findAll(ViewType.ProgressView.self)
        #expect(progressViews.count == 0,
                "Non-streaming block should not show ProgressView")
    }
}

// MARK: - CodeBlockView Primitive Tests

@MainActor
@Suite("CodeBlockView — code content rendering primitives",
       .tags(.reqVIW003),
       .timeLimit(.minutes(2)))
struct CodeBlockViewTests {

    @Test("Monospaced code block renders content text")
    func monospacedRendersContent() throws {
        let view = CodeBlockView(content: "let x = 42", style: .monospaced)
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let strings = texts.compactMap { try? $0.string() }
        #expect(strings.contains("let x = 42"))
    }

    @Test("Plain style code block renders content text")
    func plainStyleRendersContent() throws {
        let view = CodeBlockView(content: "Thinking about this...", style: .plain)
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let strings = texts.compactMap { try? $0.string() }
        #expect(strings.contains("Thinking about this..."))
    }

    @Test("CodeBlockView renders without crashing for empty content")
    func emptyContentRenders() throws {
        let view = CodeBlockView(content: "", style: .monospaced)
        let sut = try view.inspect()
        #expect(sut.findAll(ViewType.Text.self).count >= 1)
    }
}

// MARK: - DiffView Primitive Tests

@MainActor
@Suite("DiffView — diff content rendering primitives",
       .tags(.reqUX006, .reqVIW003),
       .timeLimit(.minutes(2)))
struct DiffViewTests {

    @Test("Diff content renders with colored diff lines (not code block fallback)")
    func diffContentRendersDiffLines() throws {
        let diffContent = """
        --- a/hello.swift
        +++ b/hello.swift
        @@ -1,3 +1,3 @@
        -print("old")
        +print("new")
        """
        let view = DiffView(content: diffContent)
        let sut = try view.inspect()

        // Diff rendering produces individual line Text elements
        let texts = sut.findAll(ViewType.Text.self)
        let strings = texts.compactMap { try? $0.string() }

        #expect(strings.contains(where: { $0.contains("old") }),
                "Diff should render removed line content")
        #expect(strings.contains(where: { $0.contains("new") }),
                "Diff should render added line content")
    }

    @Test("Non-diff content falls back to CodeBlockView")
    func nonDiffFallsBackToCodeBlock() throws {
        let view = DiffView(content: "just plain text, no diff markers here")
        let sut = try view.inspect()

        let texts = sut.findAll(ViewType.Text.self)
        let strings = texts.compactMap { try? $0.string() }
        #expect(strings.contains("just plain text, no diff markers here"))
    }
}
