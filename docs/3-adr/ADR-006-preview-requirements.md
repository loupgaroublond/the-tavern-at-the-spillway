# ADR-006: Preview Requirements

**Status:** Accepted
**Date:** 2026-02-13
**Context:** Previews enable rapid visual iteration without launching the full app. Missing previews slow down UI development and let visual regressions slip through. At the time of this decision, 14 of 18 view files lacked `#Preview` blocks.


## Decision

1. Every SwiftUI view file must include at least one `#Preview` block

2. Previews must be self-contained — no dependency on running services, saved sessions, or real file system state

3. Use `/tmp/tavern-preview` as the standard preview project URL

4. Previews must not use `NavigationSplitView` directly — macOS SwiftUI has a known crash bug in `OutlineListCoordinator` during preview rendering. Preview component parts separately instead.

5. Complex preview setup should use helper functions (pattern from `AgentListView.swift`)

6. New view PRs must include working preview — CI/peer review checks this


## Consequences

- Faster UI iteration loop — changes visible in seconds without full app launch

- Visual regressions caught earlier — each view's expected appearance is documented inline

- Serves as living documentation of component states and their visual appearance

- Slightly more code per view file, but preview blocks are typically 5-15 lines
