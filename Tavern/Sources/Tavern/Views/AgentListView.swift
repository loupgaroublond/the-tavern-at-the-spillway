import SwiftUI
import TavernCore

/// A list view showing all agents in the Tavern
struct AgentListView: View {
    @ObservedObject var viewModel: AgentListViewModel
    var onSpawnAgent: (() -> Void)?
    var onCloseAgent: ((UUID) -> Void)?
    var onUpdateDescription: ((UUID, String?) -> Void)?
    var onSelectAgent: ((UUID) -> Void)?

    @State private var editingDescriptionForAgentId: UUID?
    @State private var editedDescription: String = ""

    var body: some View {
        List(selection: $viewModel.selectedAgentId) {
            ForEach(viewModel.items) { item in
                AgentListRow(item: item, isSelected: viewModel.isSelected(id: item.id))
                    .tag(item.id)
                    .onTapGesture {
                        onSelectAgent?(item.id)
                    }
                    .contextMenu {
                        if !item.isJake {
                            Button("Edit Description...") {
                                editedDescription = item.chatDescription ?? ""
                                editingDescriptionForAgentId = item.id
                            }

                            Divider()

                            Button("Close", role: .destructive) {
                                onCloseAgent?(item.id)
                            }
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { onSpawnAgent?() }) {
                    Image(systemName: "plus")
                }
                .help("New chat")
                .disabled(onSpawnAgent == nil)
            }
        }
        .sheet(item: $editingDescriptionForAgentId) { agentId in
            EditDescriptionSheet(
                description: $editedDescription,
                onSave: {
                    let desc = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    onUpdateDescription?(agentId, desc.isEmpty ? nil : desc)
                    editingDescriptionForAgentId = nil
                },
                onCancel: {
                    editingDescriptionForAgentId = nil
                }
            )
        }
    }
}

// MARK: - Edit Description Sheet

struct EditDescriptionSheet: View {
    @Binding var description: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Description")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 8) {
                TextField("Chat description (optional)", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .lineLimit(2...4)

                Text("Shown below the agent name in the sidebar")
                    .font(.caption)
                    .foregroundColor(.secondary)

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

                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 350, height: 220)
    }
}

// MARK: - UUID Identifiable Extension

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
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

                // Show description or "New chat" placeholder for mortal agents
                if !item.isJake {
                    Text(item.chatDescription ?? "New chat")
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

    // Spawn a couple of agents (no assignment - user-spawned style)
    _ = try? spawner.spawn()
    _ = try? spawner.spawn()

    let viewModel = AgentListViewModel(jake: jake, spawner: spawner)
    viewModel.refreshItems()

    return AgentListView(
        viewModel: viewModel,
        onSpawnAgent: { print("Spawn agent") },
        onCloseAgent: { id in print("Close agent: \(id)") },
        onUpdateDescription: { id, desc in print("Update \(id): \(desc ?? "nil")") },
        onSelectAgent: { id in print("Select agent: \(id)") }
    )
    .frame(width: 300, height: 400)
}

#Preview("Edit Description Sheet") {
    EditDescriptionSheet(
        description: .constant("Working on authentication"),
        onSave: { print("Save") },
        onCancel: { print("Cancel") }
    )
}
