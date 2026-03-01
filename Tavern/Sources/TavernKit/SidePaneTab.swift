import Foundation

/// The tabs available in the side pane
public enum SidePaneTab: String, CaseIterable, Identifiable, Sendable {
    case files = "Files"
    case tasks = "Tasks"
    case todos = "TODOs"

    public var id: String { rawValue }

    /// SF Symbol name for this tab
    public var symbolName: String {
        switch self {
        case .files: return "folder"
        case .tasks: return "terminal"
        case .todos: return "checklist"
        }
    }
}
