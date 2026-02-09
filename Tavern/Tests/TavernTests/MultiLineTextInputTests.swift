import XCTest
import AppKit
@testable import Tavern

/// Grade 1-2 unit tests for MultiLineTextInput and its components.
///
/// Since MultiLineTextInput is an NSViewRepresentable, ViewInspector cannot fully
/// introspect it. Instead, we test the underlying AppKit components directly:
/// - InputTextView: placeholder rendering, intrinsic content size
/// - Coordinator: text syncing, command routing (Enter/Shift+Enter)
/// - Height calculation: single-line, multi-line, max height clamping
@MainActor
final class MultiLineTextInputTests: XCTestCase {

    // MARK: - Helper

    /// Create a MultiLineTextInput with test defaults and return its Coordinator + views
    private func makeCoordinatorWithViews(
        text: String = "",
        maxHeight: CGFloat = 200
    ) -> (MultiLineTextInput.Coordinator, InputTextView, NSScrollView) {
        var capturedText = text
        let input = MultiLineTextInput(
            text: .init(get: { capturedText }, set: { capturedText = $0 }),
            placeholder: "Type here...",
            isEnabled: true,
            maxHeight: maxHeight,
            onSend: {},
            onTextChange: { _ in },
            onKeyEvent: nil
        )
        let coordinator = input.makeCoordinator()

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        textView.isRichText = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        scrollView.documentView = textView

        coordinator.textView = textView
        coordinator.scrollView = scrollView

        return (coordinator, textView, scrollView)
    }

    // MARK: - InputTextView: Placeholder

    /// Placeholder string is stored and accessible
    func testPlaceholderStringIsStored() {
        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        textView.placeholderString = "Type a message..."
        XCTAssertEqual(textView.placeholderString, "Type a message...")
    }

    /// Placeholder should be visible when text is empty (verified by the draw logic condition)
    func testPlaceholderVisibleWhenEmpty() {
        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        textView.placeholderString = "Enter text"
        textView.string = ""

        // The placeholder draw condition is: string.isEmpty && !placeholderString.isEmpty
        XCTAssertTrue(textView.string.isEmpty, "Text should be empty")
        XCTAssertFalse(textView.placeholderString.isEmpty, "Placeholder should be set")
    }

    /// Placeholder should be hidden when text is present
    func testPlaceholderHiddenWhenTextPresent() {
        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        textView.placeholderString = "Enter text"
        textView.string = "Hello"

        // When text is present, the draw condition fails
        XCTAssertFalse(textView.string.isEmpty, "Text should not be empty")
    }

    // MARK: - InputTextView: Intrinsic Content Size

    /// Intrinsic content size has minimum height of 28
    func testIntrinsicContentSizeMinimumHeight() {
        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.string = ""

        let size = textView.intrinsicContentSize
        XCTAssertGreaterThanOrEqual(size.height, 28, "Minimum height should be 28")
    }

    /// Intrinsic content size grows with multi-line text
    func testIntrinsicContentSizeGrowsWithText() {
        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.textContainer?.widthTracksTextView = true

        textView.string = ""
        let emptyHeight = textView.intrinsicContentSize.height

        textView.string = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
        let multiLineHeight = textView.intrinsicContentSize.height

        XCTAssertGreaterThan(multiLineHeight, emptyHeight,
            "Multi-line text should produce taller intrinsic height than empty text")
    }

    /// Width is noIntrinsicMetric (text view doesn't constrain its own width)
    func testIntrinsicContentSizeWidthIsUnconstrained() {
        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 0, height: 4)

        let size = textView.intrinsicContentSize
        XCTAssertEqual(size.width, NSView.noIntrinsicMetric,
            "Width should be noIntrinsicMetric")
    }

    // MARK: - Coordinator: Text Sync

    /// textDidChange syncs NSTextView text back to the binding
    func testTextDidChangeSyncsBinding() {
        var boundText = ""
        let input = MultiLineTextInput(
            text: .init(get: { boundText }, set: { boundText = $0 }),
            placeholder: "Type...",
            isEnabled: true,
            maxHeight: 200,
            onSend: {},
            onTextChange: { _ in },
            onKeyEvent: nil
        )
        let coordinator = input.makeCoordinator()

        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        textView.string = "Hello world"
        coordinator.textView = textView

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        scrollView.documentView = textView
        coordinator.scrollView = scrollView

        // Simulate text change notification
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification))

        XCTAssertEqual(boundText, "Hello world", "Binding should be updated with text view content")
    }

    /// textDidChange calls onTextChange callback
    func testTextDidChangeCallsCallback() {
        var callbackText: String?
        let input = MultiLineTextInput(
            text: .constant(""),
            placeholder: "Type...",
            isEnabled: true,
            maxHeight: 200,
            onSend: {},
            onTextChange: { callbackText = $0 },
            onKeyEvent: nil
        )
        let coordinator = input.makeCoordinator()

        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        textView.string = "Updated text"
        coordinator.textView = textView

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        scrollView.documentView = textView
        coordinator.scrollView = scrollView

        coordinator.textDidChange(Notification(name: NSText.didChangeNotification))

        XCTAssertEqual(callbackText, "Updated text", "onTextChange should receive the new text")
    }

    // MARK: - Coordinator: Command Handling

    // Note: Enter key (insertNewline:) tests cannot run in the SPM test runner
    // because the doCommandBy handler accesses NSApp.currentEvent, which requires
    // a running NSApplication. These paths are covered by Grade 4 XCUITests instead.

    /// Non-Enter commands are not handled by the coordinator
    func testNonEnterCommandsAreNotHandled() {
        let input = MultiLineTextInput(
            text: .constant("text"),
            placeholder: "Type...",
            isEnabled: true,
            maxHeight: 200,
            onSend: {},
            onTextChange: { _ in },
            onKeyEvent: nil
        )
        let coordinator = input.makeCoordinator()

        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        coordinator.textView = textView

        // deleteBackward: should not be handled
        let handled = coordinator.textView(
            textView,
            doCommandBy: #selector(NSResponder.deleteBackward(_:))
        )

        XCTAssertFalse(handled, "Non-Enter commands should not be handled by coordinator")
    }

    /// moveUp: is not handled by the coordinator
    func testMoveUpNotHandled() {
        let input = MultiLineTextInput(
            text: .constant("text"),
            placeholder: "Type...",
            isEnabled: true,
            maxHeight: 200,
            onSend: {},
            onTextChange: { _ in },
            onKeyEvent: nil
        )
        let coordinator = input.makeCoordinator()

        let textView = InputTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        coordinator.textView = textView

        let handled = coordinator.textView(
            textView,
            doCommandBy: #selector(NSResponder.moveUp(_:))
        )

        XCTAssertFalse(handled, "moveUp should not be handled by coordinator")
    }

    // MARK: - Height Calculation

    /// Height calculation enforces minimum of 28 (single line)
    func testHeightCalculationEnforcesMinimum() {
        let (coordinator, _, scrollView) = makeCoordinatorWithViews(text: "", maxHeight: 200)

        // Set scroll view to very small height
        scrollView.frame.size.height = 10

        coordinator.updateHeight()

        // Height should be at least 28 (single line minimum)
        XCTAssertGreaterThanOrEqual(scrollView.frame.height, 28,
            "Height should be at least the single line minimum of 28")
    }

    /// Height calculation clamps to maxHeight
    func testHeightCalculationClampsToMaxHeight() {
        let maxHeight: CGFloat = 100
        let (coordinator, textView, scrollView) = makeCoordinatorWithViews(
            text: "",
            maxHeight: maxHeight
        )

        // Add lots of text to force height growth
        textView.string = (1...50).map { "Line \($0)" }.joined(separator: "\n")

        coordinator.updateHeight()

        XCTAssertLessThanOrEqual(scrollView.frame.height, maxHeight,
            "Height should not exceed maxHeight of \(maxHeight)")
    }
}
