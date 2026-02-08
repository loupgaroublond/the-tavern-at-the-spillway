# Transcript: Resource Panel — Ideation & Planning

**Date:** 2026-02-07 afternoon
**Branch:** resource-viewer
**Session:** 15dbbc9f
**Plan output:** `~/.claude/plans/merry-wandering-falcon.md`

---

## Context

Formal `/ideate` session that produced the complete implementation plan for the resource panel feature. Continued from the incomplete exploration session on Feb 5/6.

---

## Dialogue

**[U]:** `/ideate` — How can we add a feature, on the right side of the chat, we can see resources, such as the file tree, or to view files in there, or diffs, or other things related to the session. The initial goal is to make a file viewer so that after v1, we can use v1.5 purportedly without another IDE as well.

*[T] Claude explored the current layout (NavigationSplitView with AgentSidebar + ChatView), then worked through design decisions with the user.*

**[C]:** *(Extended thinking about layout options — HSplitView vs NavigationSplitView 3-column, tradeoffs, clarifying questions)*

**Key Design Decisions:**

- **Layout:** HSplitView wrapping ChatView + ResourcePanel inside the NavigationSplitView detail pane
- **Scope:** Per-window, not per-agent
- **Toggle:** Toolbar button (`sidebar.right` SF Symbol)
- **Persistence:** `@SceneStorage("resourcePanelVisible")`
- **Panel width:** min 250, ideal 350, max 600
- **Internal split:** VSplitView — file tree on top, file content on bottom

**v1 Scope:**
- File tree browser (lazy, one level at a time)
- Read-only file viewer with line numbers (monospace)
- Binary detection (null bytes in first 8KB → "Binary file")
- File size cap (>1MB → "File too large")
- Filtering: skip .git, .build, .swiftpm, node_modules, DerivedData, .DS_Store, xcuserdata, hidden files

**Deferred:**
- v1.1: Syntax highlighting via HighlightSwift (SPM package, wraps highlight.js via JavaScriptCore)
- Later: Agent-aware file highlighting, file editing, git status indicators, file search, file watching, diff viewer, tabs

---

## Outcome

Comprehensive plan saved to `~/.claude/plans/merry-wandering-falcon.md` covering:
- 4 new TavernCore files (FileTreeNode, FileTreeScanner, ResourcePanelViewModel, FileTypeIcon)
- 4 new Tavern view files (ResourcePanelView, FileTreeView, FileContentView, LineNumberedText)
- 3 test files (FileTreeScannerTests, ResourcePanelViewModelTests, FileTypeIconTests)
- 2 modified files (TavernApp.swift, TavernLogger.swift)
- Full test matrix (9 + 9 + 3 = 21 planned tests)

---

## Synthesis

___

**[S]:** The resource panel design chose HSplitView-in-detail over NavigationSplitView 3-column for a key reason: the resource panel is supplementary to chat, not a peer of it. A 3-column NavigationSplitView would give the resource panel equal footing with the sidebar and chat, but the resource panel should feel like a toggleable inspector — present when useful, hidden when not. HSplitView nests inside the existing detail pane, preserving the current sidebar/detail hierarchy while adding a resizable right panel.

The lazy scanning approach (one directory level at a time) is critical for performance with large projects — expanding a node triggers a single `contentsOfDirectory` call rather than a recursive walk. This is the same pattern VS Code uses for its explorer tree.
