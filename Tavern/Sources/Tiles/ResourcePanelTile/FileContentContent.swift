import SwiftUI
import TavernKit
import os.log

struct FileContentContent: View {
    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "sidepane")

    @Bindable var tile: ResourcePanelTile

    var body: some View {
        let _ = Self.logger.debug("[FileContentContent] body - file: \(tile.selectedFileName ?? "none"), loading: \(tile.isLoading)")

        VStack(spacing: 0) {
            if let fileName = tile.selectedFileName {
                HStack {
                    Image(systemName: FileTypeIcon.symbolName(
                        for: URL(fileURLWithPath: fileName).pathExtension,
                        isDirectory: false
                    ))
                    .foregroundColor(.secondary)

                    Text(fileName)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    Button(action: { tile.deselectFile() }) {
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

                if tile.isLoading {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                } else if let content = tile.selectedFileContent {
                    LineNumberedText(content: content)
                } else if let error = tile.error {
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                    Spacer()
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("Select a file to view")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview("File Content - Empty") {
    VStack(spacing: 8) {
        Image(systemName: "doc.text")
            .font(.title)
            .foregroundColor(.secondary)
        Text("Select a file to view")
            .foregroundColor(.secondary)
    }
    .frame(width: 300, height: 200)
}

#Preview("File Content - With File") {
    VStack(spacing: 0) {
        HStack {
            Image(systemName: "swift")
                .foregroundColor(.secondary)
            Text("Package.swift")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer()
            Button(action: {}) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))

        Divider()

        LineNumberedText(content: "// swift-tools-version: 6.0\nimport PackageDescription\n\nlet package = Package(\n    name: \"Tavern\"\n)")
    }
    .frame(width: 400, height: 250)
}
