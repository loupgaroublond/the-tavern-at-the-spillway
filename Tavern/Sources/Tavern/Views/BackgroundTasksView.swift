import SwiftUI
import TavernCore
import os.log

/// Displays background tasks with status indicators and output viewing
struct BackgroundTasksView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    @ObservedObject var viewModel: BackgroundTaskViewModel

    var body: some View {
        let _ = Self.logger.debug("[BackgroundTasksView] body - tasks: \(viewModel.tasks.count), running: \(viewModel.runningCount)")
        VStack(spacing: 0) {
            if viewModel.tasks.isEmpty {
                let _ = Self.logger.debug("[BackgroundTasksView] SHOWING EMPTY STATE")
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No background tasks")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                let _ = Self.logger.debug("[BackgroundTasksView] SHOWING TASK LIST")
                // Task list + optional output viewer
                VSplitView {
                    taskList
                        .frame(minHeight: 100)

                    if let selected = viewModel.selectedTask {
                        taskOutputView(selected)
                            .frame(minHeight: 80)
                    }
                }
            }
        }
        .onAppear {
            Self.logger.debug("[BackgroundTasksView] onAppear - tasks: \(viewModel.tasks.count)")
        }
        .onDisappear {
            Self.logger.debug("[BackgroundTasksView] onDisappear")
        }
    }

    // MARK: - Subviews

    private var taskList: some View {
        VStack(spacing: 0) {
            // Header with clear button
            HStack {
                Text("\(viewModel.tasks.count) task\(viewModel.tasks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.tasks.contains(where: { $0.status != .running }) {
                    Button("Clear Finished") {
                        viewModel.clearFinished()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()

            List(viewModel.tasks, selection: $viewModel.selectedTaskId) { bgTask in
                BackgroundTaskRow(bgTask: bgTask, onStop: {
                    viewModel.stopTask(bgTask.id)
                })
            }
            .listStyle(.sidebar)
        }
    }

    private func taskOutputView(_ bgTask: TavernTask) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(bgTask.name)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                Button(action: { viewModel.deselectTask() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close output")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if bgTask.output.isEmpty {
                Spacer()
                Text("No output yet")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Spacer()
            } else {
                ScrollView {
                    Text(bgTask.output)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

/// A single row in the background task list
private struct BackgroundTaskRow: View {
    let bgTask: TavernTask
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            statusIndicator

            VStack(alignment: .leading, spacing: 2) {
                Text(bgTask.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                Text(elapsedText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if bgTask.status == .running {
                Button(action: onStop) {
                    Image(systemName: "stop.circle")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Stop task")
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch bgTask.status {
        case .running:
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .frame(width: 16, height: 16)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .frame(width: 16, height: 16)
        case .stopped:
            Image(systemName: "stop.circle.fill")
                .foregroundColor(.orange)
                .frame(width: 16, height: 16)
        }
    }

    private var elapsedText: String {
        let seconds = Int(bgTask.elapsed)
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m \(seconds % 60)s"
        } else {
            return "\(seconds / 3600)h \(seconds % 3600 / 60)m"
        }
    }
}

// MARK: - Preview

#Preview("Background Tasks") {
    BackgroundTasksView(viewModel: BackgroundTaskViewModel())
        .frame(width: 300, height: 400)
}
