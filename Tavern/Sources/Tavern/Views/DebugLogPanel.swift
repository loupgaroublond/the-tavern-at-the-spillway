#if DEBUG
import AppKit
import SwiftUI
import TavernCore
import os.log

// MARK: - Provenance: REQ-OBS-007, REQ-OBS-008, REQ-OBS-009

/// Manages the NSPanel-based debug log window (DEBUG only)
///
/// The panel is a floating utility window that displays log entries
/// from the `LogBuffer`. Open/closed state persists in UserDefaults.
@MainActor
final class DebugLogPanelController {

    static let shared = DebugLogPanelController()

    private static let logger = Logger(subsystem: "com.tavern.spillway", category: "debug-panel")

    private var panel: NSPanel?
    private static let userDefaultsKey = "debugLogPanelVisible"

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private init() {}

    /// Restore panel state from UserDefaults (call at app launch)
    func restoreIfNeeded() {
        if UserDefaults.standard.bool(forKey: Self.userDefaultsKey) {
            show()
        }
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        Self.logger.debug("[DebugLogPanel] show()")
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            UserDefaults.standard.set(true, forKey: Self.userDefaultsKey)
            return
        }

        let contentView = NSHostingView(rootView: DebugLogPanelView())
        let newPanel = NSPanel(
            contentRect: NSRect(x: 200, y: 200, width: 800, height: 500),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.title = "Debug Log"
        newPanel.contentView = contentView
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = false
        newPanel.level = .floating
        newPanel.isReleasedWhenClosed = false
        newPanel.delegate = PanelDelegate.shared

        newPanel.makeKeyAndOrderFront(nil)
        self.panel = newPanel
        UserDefaults.standard.set(true, forKey: Self.userDefaultsKey)
    }

    func hide() {
        Self.logger.debug("[DebugLogPanel] hide()")
        panel?.orderOut(nil)
        UserDefaults.standard.set(false, forKey: Self.userDefaultsKey)
    }
}

/// Delegate to track panel close via the X button
@MainActor
private final class PanelDelegate: NSObject, NSWindowDelegate {
    static let shared = PanelDelegate()

    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "debugLogPanelVisible")
    }
}

// MARK: - SwiftUI Content

private struct DebugLogPanelView: View {

    @State private var viewModel = DebugLogViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar: filters
            filterBar

            Divider()

            // Log content
            logContent
        }
        .frame(minWidth: 600, minHeight: 300)
        .task {
            await viewModel.startStreaming()
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        VStack(spacing: 6) {
            // Category toggles
            HStack(spacing: 4) {
                ForEach(TavernLogger.allCategories, id: \.self) { category in
                    Toggle(category, isOn: viewModel.binding(for: category))
                        .toggleStyle(.button)
                        .controlSize(.small)
                        .font(.caption)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                // Level filter
                Picker("Level", selection: $viewModel.minimumLevel) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                // Search
                TextField("Search...", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)

                Spacer()

                // Pause/Resume auto-scroll
                Button {
                    viewModel.autoScrollEnabled.toggle()
                } label: {
                    Image(systemName: viewModel.autoScrollEnabled ? "pause.fill" : "play.fill")
                }
                .help(viewModel.autoScrollEnabled ? "Pause auto-scroll" : "Resume auto-scroll")

                // Clear
                Button {
                    viewModel.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Clear log")
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private var logContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.filteredEntries) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 8)
            }
            .font(.system(.caption, design: .monospaced))
            .onChange(of: viewModel.filteredEntries.last?.id) { _, newValue in
                if viewModel.autoScrollEnabled, let id = newValue {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .foregroundStyle(.secondary)
                .frame(width: 85, alignment: .leading)

            Text(entry.level.label)
                .foregroundStyle(levelColor)
                .frame(width: 45, alignment: .leading)

            Text(entry.category)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(entry.message)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: .secondary
        case .info: .primary
        case .error: .red
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
private final class DebugLogViewModel {

    var searchText: String = ""
    var minimumLevel: LogLevel = .debug
    var autoScrollEnabled: Bool = true

    private(set) var allEntries: [LogEntry] = []
    private var enabledCategories: Set<String>

    init() {
        self.enabledCategories = Set(TavernLogger.allCategories)
    }

    var filteredEntries: [LogEntry] {
        allEntries.filter { entry in
            guard enabledCategories.contains(entry.category) else { return false }
            guard entry.level >= minimumLevel else { return false }
            if !searchText.isEmpty {
                guard entry.message.localizedCaseInsensitiveContains(searchText) else { return false }
            }
            return true
        }
    }

    func binding(for category: String) -> Binding<Bool> {
        Binding(
            get: { self.enabledCategories.contains(category) },
            set: { enabled in
                if enabled {
                    self.enabledCategories.insert(category)
                } else {
                    self.enabledCategories.remove(category)
                }
            }
        )
    }

    func clear() {
        allEntries.removeAll()
        Task {
            await TavernLogger.logBuffer.clear()
        }
    }

    func startStreaming() async {
        // Load existing entries
        let existing = await TavernLogger.logBuffer.entries
        allEntries = existing

        // Stream new entries
        let stream = await TavernLogger.logBuffer.stream()
        for await entry in stream {
            allEntries.append(entry)
        }
    }
}

// MARK: - Preview

#Preview("Debug Log Panel") {
    DebugLogPanelView()
        .frame(width: 800, height: 500)
}
#endif
