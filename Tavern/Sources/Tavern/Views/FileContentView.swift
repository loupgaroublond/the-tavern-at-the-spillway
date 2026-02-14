import SwiftUI
import TavernCore
import os.log

/// Displays the content of a selected file with line numbers
struct FileContentView: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    @ObservedObject var viewModel: ResourcePanelViewModel

    var body: some View {
        let _ = Self.logger.debug("[FileContentView] body - file: \(viewModel.selectedFileName ?? "none"), loading: \(viewModel.isLoading), hasContent: \(viewModel.selectedFileContent != nil), error: \(viewModel.error ?? "none")")

        VStack(spacing: 0) {
            // File name header
            if let fileName = viewModel.selectedFileName {
                let _ = Self.logger.debug("[FileContentView] SHOWING FILE HEADER: \(fileName)")
                HStack {
                    Image(systemName: FileTypeIcon.symbolName(
                        for: viewModel.selectedFileURL?.pathExtension,
                        isDirectory: false
                    ))
                    .foregroundColor(.secondary)

                    Text(fileName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button(action: { viewModel.deselectFile() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close file")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()
            }

            // File content
            if viewModel.isLoading {
                let _ = Self.logger.debug("[FileContentView] SHOWING LOADING")
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if let content = viewModel.selectedFileContent {
                let _ = Self.logger.debug("[FileContentView] SHOWING CONTENT: \(content.count) chars")
                LineNumberedText(content: content)
            } else if let error = viewModel.error {
                let _ = Self.logger.debug("[FileContentView] SHOWING ERROR: \(error)")
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                let _ = Self.logger.debug("[FileContentView] SHOWING EMPTY STATE")
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("Select a file to view its contents")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .onAppear {
            Self.logger.debug("[FileContentView] onAppear - file: \(viewModel.selectedFileName ?? "none")")
        }
        .onDisappear {
            Self.logger.debug("[FileContentView] onDisappear")
        }
        .onChange(of: viewModel.selectedFileName) {
            Self.logger.debug("[FileContentView] selectedFileName changed: \(viewModel.selectedFileName ?? "none")")
        }
    }
}

// MARK: - Preview

#Preview("File Content") {
    FileContentView(viewModel: ResourcePanelViewModel(rootURL: URL(fileURLWithPath: "/tmp/tavern-preview")))
        .frame(width: 400, height: 300)
}
