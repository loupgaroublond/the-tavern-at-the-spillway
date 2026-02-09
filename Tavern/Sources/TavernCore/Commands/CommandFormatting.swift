import Foundation

/// Shared formatting utilities for slash commands.
///
/// Extracted from duplicated implementations across CompactCommand,
/// ContextCommand, CostCommand, StatsCommand, and ThinkingCommand.
public enum CommandFormatting {

    /// Format a token count for display (e.g., 1500 -> "1.5K", 2000000 -> "2.0M")
    public static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    /// Create an ASCII progress bar (e.g., "[==========          ]")
    /// - Parameters:
    ///   - filled: Percentage filled (0-100, clamped)
    ///   - width: Total width of the bar interior in characters
    public static func makeBar(filled: Double, width: Int) -> String {
        let clamped = min(max(filled, 0), 100)
        let filledCount = Int(clamped / 100 * Double(width))
        let emptyCount = width - filledCount
        return "[\(String(repeating: "=", count: filledCount))\(String(repeating: " ", count: emptyCount))]"
    }
}
