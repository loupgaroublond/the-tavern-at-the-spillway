import SwiftUI
import AppKit
import os.log

/// An NSTextView-backed multi-line text input for chat.
///
/// - Enter sends the message (calls `onSend`)
/// - Shift+Enter inserts a newline
/// - Auto-grows vertically up to `maxHeight`
/// - Reports text changes via `onTextChange` for autocomplete integration
struct MultiLineTextInput: NSViewRepresentable {

    @Binding var text: String
    let placeholder: String
    let isEnabled: Bool
    let maxHeight: CGFloat
    let onSend: () -> Void
    let onTextChange: (String) -> Void
    /// Callback for key events that the input doesn't handle (arrow keys, tab, escape)
    let onKeyEvent: ((NSEvent) -> Bool)?

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "chat")

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        Self.logger.debug("[MultiLineTextInput] makeNSView - placeholder: \(placeholder), isEnabled: \(isEnabled), maxHeight: \(maxHeight)")
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = InputTextView()
        textView.delegate = context.coordinator
        textView.inputDelegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .textColor
        textView.drawsBackground = false
        textView.isEditable = isEnabled
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.setAccessibilityIdentifier("chatInputField")
        textView.setAccessibilityEnabled(true)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? InputTextView else { return }

        // Keep coordinator's bindings and closures current across body re-evaluations.
        // Without this, switching agents leaves the coordinator holding stale references
        // to the previous viewModel's $inputText and onSend closure.
        context.coordinator.parent = self

        // Sync text from SwiftUI -> NSTextView (only if different to avoid cursor jump)
        if textView.string != text {
            Self.logger.debug("[MultiLineTextInput] updateNSView - syncing text, length: \(text.count)")
            textView.string = text
            context.coordinator.updateHeight()
        }

        textView.isEditable = isEnabled

        // Update placeholder visibility
        textView.placeholderString = placeholder
        textView.needsDisplay = true
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        nonisolated static let logger = Logger(subsystem: "com.tavern.spillway", category: "chat")

        var parent: MultiLineTextInput
        weak var textView: InputTextView?
        weak var scrollView: NSScrollView?

        init(parent: MultiLineTextInput) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            let newText = textView.string
            Self.logger.debug("[MultiLineTextInput] textDidChange - length: \(newText.count)")
            parent.text = newText
            parent.onTextChange(newText)
            updateHeight()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            Self.logger.debug("[MultiLineTextInput] doCommandBy: \(commandSelector)")
            // Enter key (insertNewline:) — send message
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Check for Shift modifier — Shift+Enter inserts newline
                if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                    Self.logger.debug("[MultiLineTextInput] Shift+Enter - inserting newline")
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                // Plain Enter — send
                if !parent.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Self.logger.debug("[MultiLineTextInput] Enter - sending message")
                    parent.onSend()
                }
                return true
            }
            return false
        }

        /// Recalculate scroll view height based on text content
        @MainActor func updateHeight() {
            guard let textView = textView, let scrollView = scrollView else { return }
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            layoutManager.ensureLayout(for: textContainer)
            let contentHeight = layoutManager.usedRect(for: textContainer).height
                + textView.textContainerInset.height * 2
            let singleLineHeight: CGFloat = 28
            let maxH = parent.maxHeight
            let desiredHeight = max(singleLineHeight, min(contentHeight, maxH))

            let currentHeight = scrollView.frame.height
            if abs(currentHeight - desiredHeight) > 1 {
                Self.logger.debug("[MultiLineTextInput] updateHeight - \(currentHeight) -> \(desiredHeight) (content: \(contentHeight), max: \(maxH))")
                scrollView.frame.size.height = desiredHeight
                scrollView.invalidateIntrinsicContentSize()
            }
        }
    }
}

// MARK: - InputTextView

/// Custom NSTextView subclass that:
/// - Draws placeholder text when empty
/// - Forwards unhandled key events (arrows, tab, escape) to the parent via closure
final class InputTextView: NSTextView {

    var placeholderString: String = ""
    var inputDelegate: MultiLineTextInput.Coordinator?

    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager, let textContainer = textContainer else {
            return super.intrinsicContentSize
        }
        layoutManager.ensureLayout(for: textContainer)
        let height = layoutManager.usedRect(for: textContainer).height + textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: max(28, height))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw placeholder when empty
        if string.isEmpty && !placeholderString.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ]
            let inset = textContainerInset
            let padding = textContainer?.lineFragmentPadding ?? 0
            let rect = NSRect(
                x: inset.width + padding,
                y: inset.height,
                width: bounds.width - inset.width * 2 - padding * 2,
                height: bounds.height - inset.height * 2
            )
            placeholderString.draw(in: rect, withAttributes: attributes)
        }
    }

    override func keyDown(with event: NSEvent) {
        // Let the parent coordinator's onKeyEvent handle special keys
        if let delegate = inputDelegate?.parent.onKeyEvent, delegate(event) {
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Sizing

/// A wrapper that provides intrinsic height tracking for the multi-line input
struct MultiLineTextInputSized: View {
    @Binding var text: String
    let placeholder: String
    let isEnabled: Bool
    let maxHeight: CGFloat
    let onSend: () -> Void
    let onTextChange: (String) -> Void
    let onKeyEvent: ((NSEvent) -> Bool)?

    @State private var contentHeight: CGFloat = 28

    var body: some View {
        MultiLineTextInput(
            text: $text,
            placeholder: placeholder,
            isEnabled: isEnabled,
            maxHeight: maxHeight,
            onSend: onSend,
            onTextChange: onTextChange,
            onKeyEvent: onKeyEvent
        )
        .frame(height: min(max(28, contentHeight), maxHeight))
    }
}
