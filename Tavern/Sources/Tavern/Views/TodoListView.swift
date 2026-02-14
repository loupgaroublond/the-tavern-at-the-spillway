import SwiftUI
import TavernCore
import os.log

/// Displays a checklist of TODO items with add/toggle/remove functionality
struct TodoListView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    @ObservedObject var viewModel: TodoListViewModel

    var body: some View {
        let _ = Self.logger.debug("[TodoListView] body - items: \(viewModel.items.count), pending: \(viewModel.pendingCount)")
        VStack(spacing: 0) {
            // Input bar
            HStack(spacing: 8) {
                TextField("Add a TODO...", text: $viewModel.draftText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.addItem()
                    }

                Button(action: { viewModel.addItem() }) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Add TODO")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if viewModel.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No TODOs yet")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // Header with counts + clear button
                HStack {
                    Text("\(viewModel.pendingCount) pending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if viewModel.completedCount > 0 {
                        Button("Clear Done") {
                            viewModel.clearCompleted()
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Divider()

                List {
                    ForEach(viewModel.items) { item in
                        TodoItemRow(item: item, onToggle: {
                            viewModel.toggleItem(item.id)
                        }, onDelete: {
                            viewModel.removeItem(item.id)
                        })
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .onAppear {
            Self.logger.debug("[TodoListView] onAppear - items: \(viewModel.items.count)")
        }
        .onDisappear {
            Self.logger.debug("[TodoListView] onDisappear")
        }
    }
}

/// A single TODO item row with checkbox and delete
private struct TodoItemRow: View {
    let item: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(item.text)
                .strikethrough(item.isCompleted)
                .foregroundColor(item.isCompleted ? .secondary : .primary)
                .lineLimit(2)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview("TODO List") {
    TodoListView(viewModel: TodoListViewModel())
        .frame(width: 300, height: 400)
}
