import SwiftUI
import TavernCore

@main
struct TavernApp: App {
    @StateObject private var coordinator = TavernApp.createCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Conversation") {
                    coordinator.activeChatViewModel.clearConversation()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    /// Create the coordinator with appropriate dependencies
    private static func createCoordinator() -> TavernCoordinator {
        let claude: ClaudeCode
        do {
            // Enable debug logging to diagnose SDK issues
            var config = ClaudeCodeConfiguration.default
            config.enableDebugLogging = true
            claude = try ClaudeCodeClient(configuration: config)
        } catch {
            // If ClaudeCode fails to initialize, use a mock that returns error messages
            // This allows the app to launch and show the user what went wrong
            print("Failed to initialize ClaudeCodeClient: \(error)")
            let mock = MockClaudeCode()
            mock.errorToThrow = error
            claude = mock
        }

        let jake = Jake(claude: claude)
        let registry = AgentRegistry()
        let nameGenerator = NameGenerator(theme: .lotr)
        let spawner = AgentSpawner(
            registry: registry,
            nameGenerator: nameGenerator,
            claudeFactory: {
                // Each spawned agent gets its own mock for now
                // TODO: Share the real Claude client in production
                MockClaudeCode()
            }
        )

        return TavernCoordinator(jake: jake, spawner: spawner)
    }
}

struct ContentView: View {
    @ObservedObject var coordinator: TavernCoordinator

    var body: some View {
        NavigationSplitView {
            // Sidebar with agent list
            VStack(spacing: 0) {
                TavernHeader()
                Divider()
                AgentListView(viewModel: coordinator.agentListViewModel)
            }
            .frame(minWidth: 200)
        } detail: {
            // Detail view with selected agent's chat
            ChatView(viewModel: coordinator.activeChatViewModel)
        }
        .frame(minWidth: 800, minHeight: 500)
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
    let registry = AgentRegistry()
    let nameGenerator = NameGenerator(theme: .lotr)
    let spawner = AgentSpawner(
        registry: registry,
        nameGenerator: nameGenerator,
        claudeFactory: { MockClaudeCode() }
    )

    let coordinator = TavernCoordinator(jake: jake, spawner: spawner)

    return ContentView(coordinator: coordinator)
}
