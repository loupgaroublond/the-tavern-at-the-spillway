# Transcript: Per-Agent Session Mode Control

**Date:** 2026-02-14
**Type:** Design discussion → Implementation
**Session:** Planning session (315b564e) + implementation session

---

## Design Discussion

[U] The app urgently needs a control to switch session modes. Agents start in plan mode, this must be user controllable, among other things. Look into this, and then follow up with any questions for things that need clarification.

[C] Found that Tavern has a `PermissionMode` enum and `PermissionManager` with `PermissionSettingsView`, and ClodKit has `QueryOptions.permissionMode` and `ClaudeSession.setPermissionMode()` for mid-session changes. **These are completely disconnected** — the Tavern permission system works entirely via the `canUseTool` callback. The SDK's `permissionMode` is never set on QueryOptions, so the CLI itself doesn't know what mode the agent is in. The permission mode is global (one mode for all agents in a project), stored in UserDefaults. The `PermissionSettingsView` exists but isn't wired into any accessible menu or toolbar.

[C] Asked three clarifying questions: (1) Should permission mode be per-agent or global? (2) Where should the mode control live in the UI? (3) What other session controls beyond permission mode?

[U] This is Claude's "plan, auto-edit, normal, yolo" 4 modes, so of course it applies to each servitor. It's orthogonal to the tool use permissions, which also need to be wired into tool use by agents. Clearly we need to file a bead bug about the permissions settings, mark it as a stub to be spelled out later.

[U] Input bar area.

[U] We'll need the full suite of controls eventually, so open bug beads and mark as stubs to be defined further. The other consideration is making sure we can handle the agent writing a plan and then calling ExitPlanMode.

[T] *The actual flow is: set `permissionMode: .plan` on QueryOptions, the CLI enforces read-only behavior internally, the agent calls ExitPlanMode which triggers a `can_use_tool` request, Tavern intercepts this via the callback to show the user the plan and get approval, then the mode transitions if approved.*

[T] *The per-agent `permissionMode` should go into QueryOptions and reach the CLI, which handles mode behavior like read-only tools in plan mode. Meanwhile, the `canUseTool` callback can manage ExitPlanMode approvals and fine-grained permissions, while PermissionManager handles tool-specific allow/deny patterns but leaves mode enforcement to the CLI instead of duplicating it.*

___

[S] **Key design decisions:**

1. **Per-agent mode control** — Each agent (Jake, each Servitor) has its own independent session mode, not a global setting.

2. **Four modes** exposed in UI: Plan, Normal, Auto-Edit, YOLO (matching Claude CLI's modes). DontAsk omitted from picker for simplicity.

3. **Default mode**: Plan — agents start in plan mode.

4. **UI placement**: Compact mode picker strip in the input bar area.

5. **Orthogonality principle**: Session modes (plan/normal/yolo) are separate from tool-use permission rules (allow/deny patterns). Both need implementation but are independent concerns.

6. **ExitPlanMode flow**: Agent in plan mode calls ExitPlanMode → comes through `canUseTool` callback → Tavern presents plan for user review → on approval, mode switches to Normal and tool is allowed → on rejection, tool is denied with feedback.

7. **Division of responsibility**: CLI enforces mode behavior (read-only tools in plan mode, etc.). Tavern handles ExitPlanMode approval UI and tool-specific permission rules.

8. **Mode mapping**: Tavern's `.normal` maps to ClodKit's `.default`. All other cases match directly (`.plan`→`.plan`, `.acceptEdits`→`.acceptEdits`, `.bypassPermissions`→`.bypassPermissions`, `.dontAsk`→`.dontAsk`).

9. **Future controls**: Model selection, thinking tokens, and full session control panel tracked as stub beads for later.
