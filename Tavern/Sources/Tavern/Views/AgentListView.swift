import SwiftUI
import TavernCore

/// A list view showing all agents in the Tavern
struct AgentListView: View {
    @ObservedObject var viewModel: AgentListViewModel

    var body: some View {
        List(selection: $viewModel.selectedAgentId) {
            ForEach(viewModel.items) { item in
                AgentListRow(item: item, isSelected: viewModel.isSelected(id: item.id))
                    .tag(item.id)
            }
        }
        .listStyle(.sidebar)
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

#Preview {
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

    return AgentListView(viewModel: viewModel)
        .frame(width: 300, height: 400)
}
