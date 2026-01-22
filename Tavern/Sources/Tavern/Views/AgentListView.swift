import SwiftUI
import TavernCore

/// A list view showing all agents in the Tavern
struct AgentListView: View {
    @ObservedObject var viewModel: AgentListViewModel
    var onSpawnAgent: ((String, String?) -> Void)?

    @State private var showingSpawnSheet = false

    var body: some View {
        List(selection: $viewModel.selectedAgentId) {
            ForEach(viewModel.items) { item in
                AgentListRow(item: item, isSelected: viewModel.isSelected(id: item.id))
                    .tag(item.id)
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingSpawnSheet = true }) {
                    Image(systemName: "plus")
                }
                .help("Spawn a new agent")
                .disabled(onSpawnAgent == nil)
            }
        }
        .sheet(isPresented: $showingSpawnSheet) {
            SpawnAgentSheet(
                onSpawn: { assignment, customName in
                    onSpawnAgent?(assignment, customName)
                },
                onCancel: {
                    showingSpawnSheet = false
                }
            )
        }
    }
}

// MARK: - Spawn Agent Sheet

struct SpawnAgentSheet: View {
    @State private var assignment: String = ""
    @State private var customName: String = ""
    @State private var useCustomName: Bool = false

    var onSpawn: (String, String?) -> Void
    var onCancel: () -> Void

    private var canSpawn: Bool {
        !assignment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Spawn a New Agent")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 16) {
                // Assignment field (required)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assignment")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("What should this agent work on?", text: $assignment, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .lineLimit(3...6)
                }

                // Custom name (optional)
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $useCustomName) {
                        Text("Custom name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if useCustomName {
                        TextField("Agent name", text: $customName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                    }
                }

                Spacer()
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Spawn") {
                    let name = useCustomName && !customName.isEmpty ? customName : nil
                    onSpawn(assignment.trimmingCharacters(in: .whitespacesAndNewlines), name)
                    onCancel() // Close sheet after spawning
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSpawn)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
}

// MARK: - Agent Row

private struct AgentListRow: View {
    let item: AgentListItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // State indicator
            StateIndicator(state: item.state, isJake: item.isJake)

            // Agent info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name)
                        .font(.headline)
                        .fontWeight(item.isJake ? .bold : .medium)

                    if item.isJake {
                        Text("(The Proprietor)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if let assignment = item.assignmentSummary {
                    Text(assignment)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Attention badge
            if item.needsAttention {
                AttentionBadge()
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - State Indicator

private struct StateIndicator: View {
    let state: AgentState
    let isJake: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }

    private var color: Color {
        if isJake {
            return .orange
        }

        switch state {
        case .idle: return .gray
        case .working: return .blue
        case .waiting: return .yellow
        case .verifying: return .purple
        case .done: return .green
        }
    }
}

// MARK: - Attention Badge

private struct AttentionBadge: View {
    var body: some View {
        Circle()
            .fill(Color.yellow)
            .frame(width: 8, height: 8)
            .overlay {
                Circle()
                    .stroke(Color.orange, lineWidth: 1)
            }
    }
}

// MARK: - Preview

#Preview("Agent List") {
    // Create mock data for preview
    let mock = MockClaudeCode()
    let jake = Jake(claude: mock)
    let registry = AgentRegistry()
    let nameGen = NameGenerator(theme: .lotr)
    let spawner = AgentSpawner(
        registry: registry,
        nameGenerator: nameGen,
        claudeFactory: { MockClaudeCode() }
    )

    // Spawn a couple of agents
    _ = try? spawner.spawn(assignment: "Parse the JSON configuration files")
    _ = try? spawner.spawn(assignment: "Run the test suite and report failures")

    let viewModel = AgentListViewModel(jake: jake, spawner: spawner)

    // Cache the assignments so they show in preview
    for agent in spawner.activeAgents {
        viewModel.cacheAssignment(agentId: agent.id, assignment: "Sample assignment")
    }
    viewModel.refreshItems()

    return AgentListView(viewModel: viewModel) { assignment, name in
        print("Spawn agent: \(assignment), name: \(name ?? "auto")")
    }
    .frame(width: 300, height: 400)
}

#Preview("Spawn Sheet") {
    SpawnAgentSheet(
        onSpawn: { assignment, name in
            print("Spawn: \(assignment), name: \(name ?? "auto")")
        },
        onCancel: {
            print("Cancel")
        }
    )
}
