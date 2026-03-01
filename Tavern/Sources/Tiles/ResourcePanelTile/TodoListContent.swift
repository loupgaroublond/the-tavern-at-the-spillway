import SwiftUI
import TavernKit
import os.log

struct TodoListContent: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    @Bindable var tile: ResourcePanelTile

    var body: some View {
        let _ = Self.logger.debug("[TodoListContent] body - items: \(tile.todoItems.count), pending: \(tile.pendingCount)")
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Add a TODO...", text: $tile.todoDraftText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        tile.addTodoItem()
                    }

                Button(action: { tile.addTodoItem() }) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(tile.todoDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Add TODO")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if tile.todoItems.isEmpty {
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
                HStack {
                    Text("\(tile.pendingCount) pending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if tile.completedCount > 0 {
                        Button("Clear Done") {
                            tile.clearCompletedTodos()
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
                    ForEach(tile.todoItems) { item in
                        TodoItemRow(item: item, onToggle: {
                            tile.toggleTodoItem(item.id)
                        }, onDelete: {
                            tile.removeTodoItem(item.id)
                        })
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

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
    VStack(spacing: 0) {
        HStack(spacing: 8) {
            TextField("Add a TODO...", text: .constant(""))
                .textFieldStyle(.roundedBorder)
            Button(action: {}) {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

        Divider()

        HStack {
            Text("2 pending").font(.caption).foregroundColor(.secondary)
            Spacer()
            Button("Clear Done") {}.font(.caption).buttonStyle(.plain).foregroundColor(.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)

        Divider()

        List {
            TodoItemRow(item: TodoItem(text: "Fix streaming bug"), onToggle: {}, onDelete: {})
            TodoItemRow(item: TodoItem(text: "Add preview blocks"), onToggle: {}, onDelete: {})
            TodoItemRow(item: TodoItem(text: "Write tests", isCompleted: true), onToggle: {}, onDelete: {})
        }
        .listStyle(.sidebar)
    }
    .frame(width: 300, height: 350)
}
