import XCTest
import SwiftUI
import ViewInspector
@testable import ChatTile
@testable import ResourcePanelTile

/// Grade 1-2 tests verifying that CoreUI view instrumentation is wired correctly.
///
/// These tests verify:
/// 1. Views with instrumentation render without crashing (the `let _ = Self.logger.debug(...)`
///    pattern evaluates during body computation without side effects that break rendering)
/// 2. ViewInspector can introspect instrumented views (proving the logging code doesn't
///    interfere with the view hierarchy)
///
/// Note: View-specific wiring tests for tiles live in their respective tile test targets.
/// These tests cover shared CoreUI presentation components.
@MainActor
final class ViewInstrumentationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - Presentation Components

    /// LineNumberedText renders with body evaluation logging
    func testLineNumberedTextRendersWithInstrumentation() throws {
        let view = LineNumberedText(content: "Line 1\nLine 2\nLine 3")
        let sut = try view.inspect()
        XCTAssertNotNil(sut)
    }

    /// CollapsibleBlockView renders with body logging, lifecycle, and onChange
    func testCollapsibleBlockViewRendersWithInstrumentation() throws {
        let view = CollapsibleBlockView(blockType: .thinking, content: "test thinking content")
        let sut = try view.inspect()
        XCTAssertNotNil(sut)
    }

    /// CodeBlockView renders with body logging and hover state tracking
    func testCodeBlockViewRendersWithInstrumentation() throws {
        let view = CodeBlockView(content: "let x = 42")
        let sut = try view.inspect()
        XCTAssertNotNil(sut)
    }

    /// DiffView renders with body logging and conditional branch logging
    func testDiffViewRendersWithDiffContent() throws {
        let diffContent = """
        --- a/file.swift
        +++ b/file.swift
        @@ -1,3 +1,3 @@
        -let old = true
        +let new = true
        """
        let view = DiffView(content: diffContent)
        let sut = try view.inspect()
        XCTAssertNotNil(sut)
    }

    /// DiffView renders non-diff content through the code block fallback branch
    func testDiffViewRendersWithNonDiffContent() throws {
        let view = DiffView(content: "just plain text, no diff markers")
        let sut = try view.inspect()
        XCTAssertNotNil(sut)
    }
}
