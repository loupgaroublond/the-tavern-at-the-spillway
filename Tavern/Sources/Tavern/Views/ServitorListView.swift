import SwiftUI
import TavernCore
import os.log

// MARK: - Provenance: REQ-OPM-004, REQ-UX-002, REQ-UX-003, REQ-V1-003, REQ-VIW-004

/// A list view showing all agents in the Tavern
struct ServitorListView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "agents")

    @ObservedObject var viewModel: ServitorListViewModel
    var onSpawnServitor: (() -> Void)?
    var onCloseServitor: ((UUID) -> Void)?
    var onUpdateDescription: ((UUID, String?) -> Void)?
    var onSelectServitor: ((UUID) -> Void)?

    @State private var editingDescriptionForServitorId: UUID?
    @State private var editedDescription: String = ""

    var body: some View {
        let _ = Self.logger.debug("[ServitorListView] body - items: \(viewModel.items.count), selected: \(viewModel.selectedServitorId?.uuidString ?? "nil")")

        List(selection: $viewModel.selectedServitorId) {
            ForEach(viewModel.items) { item in
                ServitorListRow(
                    item: item,
                    isSelected: viewModel.isSelected(id: item.id),
                    onClose: item.isJake ? nil : { onCloseServitor?(item.id) }
                )
                    .tag(item.id)
                    .onTapGesture {
                        onSelectServitor?(item.id)
                    }
                    .contextMenu {
                        if !item.isJake {
                            Button("Edit Description...") {
                                editedDescription = item.chatDescription ?? ""
                                editingDescriptionForServitorId = item.id
                            }

                            Divider()

                            Button("Close", role: .destructive) {
                                onCloseServitor?(item.id)
                            }
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("servitorList")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { onSpawnServitor?() }) {
                    Image(systemName: "plus")
                }
                .help("New chat")
                .disabled(onSpawnServitor == nil)
                .accessibilityIdentifier("spawnServitorButton")
            }
        }
        .onAppear {
            Self.logger.debug("[ServitorListView] onAppear - items: \(viewModel.items.count)")
        }
        .onDisappear {
            Self.logger.debug("[ServitorListView] onDisappear")
        }
        .onChange(of: viewModel.selectedServitorId) {
            Self.logger.debug("[ServitorListView] selectedServitorId changed: \(viewModel.selectedServitorId?.uuidString ?? "nil")")
        }
        .onChange(of: editingDescriptionForServitorId) {
            Self.logger.debug("[ServitorListView] editingDescriptionForServitorId changed: \(editingDescriptionForServitorId?.uuidString ?? "nil")")
        }
        .sheet(item: $editingDescriptionForServitorId) { servitorId in
            EditDescriptionSheet(
                description: $editedDescription,
                onSave: {
                    let desc = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    onUpdateDescription?(servitorId, desc.isEmpty ? nil : desc)
                    editingDescriptionForServitorId = nil
                },
                onCancel: {
                    editingDescriptionForServitorId = nil
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

private struct ServitorListRow: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "agents")

    let item: ServitorListItem
    let isSelected: Bool
    var onClose: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        let _ = Self.logger.debug("[ServitorListRow] body - name: \(item.name), isJake: \(item.isJake), state: \(String(describing: item.state)), selected: \(isSelected)")

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

                // Show description or "New chat" placeholder for servitors
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

            // Close button (visible on hover for servitors)
            if let onClose = onClose, isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close chat")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - State Indicator

private struct StateIndicator: View {
    let state: ServitorState
    let isJake: Bool

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .opacity(shouldPulse ? (isPulsing ? 0.4 : 1.0) : 1.0)
            .animation(
                shouldPulse
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onChange(of: shouldPulse) {
                isPulsing = shouldPulse
            }
            .onAppear {
                isPulsing = shouldPulse
            }
            .accessibilityLabel(accessibilityStateLabel)
    }

    private var shouldPulse: Bool {
        state == .working || (isJake && state == .working)
    }

    private var color: Color {
        if isJake && state != .error {
            return state == .working ? .green : .orange
        }

        switch state {
        case .idle: return .gray
        case .working: return .green
        case .waiting: return .yellow
        case .verifying: return .purple
        case .done: return .green
        case .error: return .red
        }
    }

    private var accessibilityStateLabel: String {
        switch state {
        case .idle: return "Idle"
        case .working: return "Working"
        case .waiting: return "Needs attention"
        case .verifying: return "Verifying"
        case .done: return "Done"
        case .error: return "Error"
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

// Static inline preview — avoids a macOS SwiftUI crash where NSOutlineView's
// OutlineListCoordinator.outlineView(_:child:ofItem:) triggers a fatalError
// when views with @State or ObservableObject interact during initial preview layout.
// See: TableViewListCore_Mac2.swift:5170
//
// Uses inline views instead of ServitorListRow because @State (hover tracking,
// animation pulsing) in subviews also triggers the NSOutlineView inconsistency.

#Preview("Servitor List") {
    List {
        HStack(spacing: 12) {
            Circle().fill(.orange).frame(width: 10, height: 10)
            VStack(alignment: .leading) {
                HStack {
                    Text("Jake").font(.headline).fontWeight(.bold)
                    Text("(The Proprietor)").font(.caption).foregroundColor(.orange)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)

        ForEach(["Frodo", "Samwise"], id: \.self) { name in
            HStack(spacing: 12) {
                Circle().fill(name == "Frodo" ? .green : .gray)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading) {
                    Text(name).font(.headline).fontWeight(.medium)
                    Text(name == "Frodo" ? "Investigating the ring" : "New chat")
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 400)
}

#Preview("Edit Description Sheet") {
    EditDescriptionSheet(
        description: .constant("Working on authentication"),
        onSave: { print("Save") },
        onCancel: { print("Cancel") }
    )
}
