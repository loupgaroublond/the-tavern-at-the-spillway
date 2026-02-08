import SwiftUI
import TavernCore

/// Displays the content of a selected file with line numbers
struct FileContentView: View {
    @ObservedObject var viewModel: ResourcePanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            // File name header
            if let fileName = viewModel.selectedFileName {
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
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if let content = viewModel.selectedFileContent {
                LineNumberedText(content: content)
            } else if let error = viewModel.error {
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
    }
}
