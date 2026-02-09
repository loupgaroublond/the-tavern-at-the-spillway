import Foundation
import Combine
import os.log

/// View model for slash command autocomplete behavior
///
/// Observes the chat input text and produces a filtered list of matching commands
/// when the user types a "/" prefix. The autocomplete popup appears when there
/// are matches and disappears when the input is not a command prefix.
@MainActor
public final class SlashCommandAutocomplete: ObservableObject {

    /// Filtered commands matching the current input
    @Published public private(set) var suggestions: [any SlashCommand] = []

    /// Whether the autocomplete popup should be visible
    @Published public private(set) var isVisible: Bool = false

    /// Index of the currently highlighted suggestion (for keyboard navigation)
    @Published public var selectedIndex: Int = 0

    private let dispatcher: SlashCommandDispatcher
    private var cancellables = Set<AnyCancellable>()

    /// Create an autocomplete model bound to a dispatcher
    /// - Parameter dispatcher: The command dispatcher to query for matches
    public init(dispatcher: SlashCommandDispatcher) {
        self.dispatcher = dispatcher
    }

    /// Update suggestions based on current input text
    /// - Parameter input: The current input field text
    public func update(for input: String) {
        guard let partial = SlashCommandParser.partialCommand(from: input) else {
            hide()
            return
        }

        let matches = dispatcher.matchingCommands(prefix: partial)
        suggestions = matches
        selectedIndex = 0
        isVisible = !matches.isEmpty

        TavernLogger.commands.debug("Autocomplete: prefix=\"\(partial)\" matches=\(matches.count)")
    }

    /// Hide the autocomplete popup
    public func hide() {
        isVisible = false
        suggestions = []
        selectedIndex = 0
    }

    /// Move selection up in the list
    public func moveUp() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
    }

    /// Move selection down in the list
    public func moveDown() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
    }

    /// Get the currently selected command name (for tab/enter completion)
    /// - Returns: The full command text with slash prefix, or nil if nothing selected
    public func selectedCompletion() -> String? {
        guard isVisible, suggestions.indices.contains(selectedIndex) else { return nil }
        return "/\(suggestions[selectedIndex].name) "
    }
}
