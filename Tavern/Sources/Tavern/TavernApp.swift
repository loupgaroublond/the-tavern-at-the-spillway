import SwiftUI
import TavernCore

@main
struct TavernApp: App {
    @StateObject private var viewModel = TavernApp.createViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Conversation") {
                    viewModel.clearConversation()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    /// Create the view model with appropriate ClaudeCode instance
    private static func createViewModel() -> ChatViewModel {
        let claude: ClaudeCode
        do {
            claude = try ClaudeCodeClient()
        } catch {
            // If ClaudeCode fails to initialize, use a mock that returns error messages
            // This allows the app to launch and show the user what went wrong
            print("Failed to initialize ClaudeCodeClient: \(error)")
            let mock = MockClaudeCode()
            mock.errorToThrow = error
            claude = mock
        }
        let jake = Jake(claude: claude)
        return ChatViewModel(jake: jake)
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            TavernHeader()

            Divider()

            // Chat area
            ChatView(viewModel: viewModel)
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

// MARK: - Tavern Header

private struct TavernHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("The Tavern at the Spillway")
                    .font(.headline)
                Text("Jake, The Proprietor")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()

            // Status indicator placeholder
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text("Open")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    let mock = MockClaudeCode()
    mock.queueJSONResponse(result: "Well well WELL, look who just walked in!", sessionId: "preview")

    let jake = Jake(claude: mock)
    let viewModel = ChatViewModel(jake: jake)

    return ContentView(viewModel: viewModel)
}
