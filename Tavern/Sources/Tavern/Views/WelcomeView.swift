import SwiftUI
import TavernCore
import AppKit

/// Shown when no project is open
struct WelcomeView: View {
    @EnvironmentObject var projectManager: ProjectManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo/Title
            VStack(spacing: 8) {
                Text("The Tavern at the Spillway")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Pull up a stool. Stay a while.")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            VStack(spacing: 16) {
                Button(action: {
                    Task { @MainActor in
                        await openProjectDialog()
                    }
                }) {
                    Label("Open Project", systemImage: "folder")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Recent projects
                if !projectManager.recentProjectPaths.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Projects")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        ForEach(projectManager.recentProjectPaths.prefix(5), id: \.self) { url in
                            Button(action: {
                                WindowOpeningService.shared.openProjectWindow(url: url)
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundColor(.secondary)
                                    VStack(alignment: .leading) {
                                        Text(url.lastPathComponent)
                                            .fontWeight(.medium)
                                        Text(url.deletingLastPathComponent().path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }

            Spacer()
        }
        .frame(minWidth: 500, minHeight: 400)
        .padding(40)
    }

    @MainActor
    private func openProjectDialog() async {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.message = "Select a project directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        let response = await panel.begin()

        if response == .OK, let url = panel.url {
            WindowOpeningService.shared.openProjectWindow(url: url)
        }
    }
}

// MARK: - Preview

#Preview("Welcome") {
    WelcomeView()
        .environmentObject(ProjectManager.shared)
}
