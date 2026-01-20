import Foundation
import Combine

/// View model for managing a chat conversation with an agent
@MainActor
public final class ChatViewModel: ObservableObject {

    // MARK: - Published State

    /// All messages in the conversation
    @Published public private(set) var messages: [ChatMessage] = []

    /// Whether the agent is currently processing
    @Published public private(set) var isCogitating: Bool = false

    /// Current input text (bound to text field)
    @Published public var inputText: String = ""

    /// The current cogitation verb (for UI display)
    @Published public private(set) var cogitationVerb: String = "Cogitating"

    /// Any error that occurred
    @Published public private(set) var error: Error?

    // MARK: - Dependencies

    private let jake: Jake

    // MARK: - Cogitation Verbs

    /// A selection of verbs for the "thinking" indicator
    /// These come from Jake's world - the spillway vocabulary
    private static let cogitationVerbs = [
        "Cogitating",
        "Ruminating",
        "Contemplating",
        "Deliberating",
        "Pondering",
        "Mulling",
        "Musing",
        "Chewing on it",
        "Working the angles",
        "Consulting the Jukebox",
        "Checking with the Slop Squad",
        "Running the numbers",
        "Crunching",
        "Processing",
        "Scheming",
        "Plotting",
        "Calculating",
        "Figuring",
        "Sussing it out",
        "Getting to the bottom of it"
    ]

    // MARK: - Initialization

    public init(jake: Jake) {
        self.jake = jake
    }

    // MARK: - Actions

    /// Send the current input text as a message
    public func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Clear input immediately
        inputText = ""
        error = nil

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        // Set cogitating state with random verb
        isCogitating = true
        cogitationVerb = Self.cogitationVerbs.randomElement() ?? "Cogitating"

        do {
            // Get response from Jake
            let response = try await jake.send(text)

            // Add agent message
            let agentMessage = ChatMessage(role: .agent, content: response)
            messages.append(agentMessage)

        } catch {
            self.error = error
            // Add error message to chat
            let errorMessage = ChatMessage(
                role: .agent,
                content: "Oops! Something went wrong at the spillway: \(error.localizedDescription)"
            )
            messages.append(errorMessage)
        }

        isCogitating = false
    }

    /// Clear the conversation and reset Jake's session
    public func clearConversation() {
        messages.removeAll()
        jake.resetConversation()
        error = nil
    }
}
