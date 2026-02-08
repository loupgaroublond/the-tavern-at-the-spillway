# Transcript: V1 Chat Parity Planning

**Date:** 2026-02-07
**Session:** Breaking "Chat Parity with Claude Code CLI" into parallelizable epics and creating beads to track them
**Branch:** `get-to-v1`


## Context

The Tavern has a working chat skeleton — Jake talks, sessions persist, agents spawn, 201+ tests pass. But the chat experience lacks feature parity with the Claude Code CLI. V1 means "usable for real daily tasks."

This session took an approved plan and turned it into trackable beads (epics + subtasks) with proper dependency links for parallel agent work.


## The Starting Point

**[U]** Let's talk about what we need to get to v1 as something usable for some basic tasks. There's a bunch of things I think that are crucial, but first, dig around and get a sense of what we're doing, and then loop back to talk about v1 features that we should focus on.

**[C]** Reviewed the full codebase — Jake chats via ClodeMonster SDK, multi-project windows, session persistence, agent spawning with themed names, rich message rendering infrastructure, window restoration, 201 tests passing. The gap between "technically functional" and "actually useful day-to-day" is the target.

**[U]** I need a chat window with an agent or Jake to offer functional parity with the claude code CLI in mostly key areas. Specifically, we need to make sure we render all the different message types correctly, and I want to add a bit more visual distinction there. Slash commands and other things need to work, although things like settings doesn't, wherever it's a complex TUI already. Get a full feature list of the CLI to start, and then we'll go through it to hammer out what's essential here.

**[C]** Compiled the full CLI feature inventory across categories: Message Content Types, Slash Commands (low/medium/high effort), Input Features, Permissions, Session Features, Configuration, Display & UX.

**[U]** Give me a checklist for everything and I'll go through it. Feel free to be more granular, although, what a check means is just a candidate to talk about more detailed requirements.

**[C]** Created interactive checklist. User selected items across all categories.


## Scope Decision

**[T]** *The user went through every feature in the CLI inventory and selected what ships for v1. Key principle: everything selected ships. The job was to chunk the work for parallel agent execution, not to negotiate scope.*

**[U]** *(Confirmed: everything ships.)*


## Epic Structure

**[C]** Proposed 9 epics structured for maximum parallelism:

**Epic 1: Message Rendering Overhaul** — Visual distinction between message types, collapsible tool use/result/thinking blocks, inline diff rendering, copy button on code blocks, web search result rendering, error styling, timestamps. Pure UI work on existing MessageType enum.

**Epic 2: Streaming Responses** — SDK streaming integration (ClodeMonster already exposes AsyncSequence), partial message UI updates, streaming indicator, graceful stream interruption handling.

**Epic 3: Input Enhancement** — Multi-line input (Enter = send, Shift+Enter = newline), @ file mentions with path autocomplete.

**Epic 4: Permissions Subsystem** — Tool approval dialog UI, "always allow" per tool type (persisted), permission mode switching (default, acceptEdits, plan, bypassPermissions, dontAsk), permission rules display/editing UI.

**Epic 5: Slash Command Infrastructure + Core Commands** — Command parser/dispatcher, autocomplete in input, core commands: /compact, /cost, /model, /status, /context, /stats, max thinking tokens control.

**Epic 6: Custom Slash Commands** — Discover .claude/commands/*.md, subdirectory namespacing, argument substitution ($ARGUMENTS, $1, $2), autocomplete integration. *Blocked by Epic 5.*

**Epic 7: Management UIs** — /agents, /hooks, /mcp commands with substantial UIs (sheets/popovers/dedicated panes). *Blocked by Epic 5.*

**Epic 8: Side Pane — TODOs & Background Tasks** — Coordinates with file viewer pane work (another agent). /todos tab, /bashes tab with background task management. *External dependency.*

**Epic 9: Chat UX Polish** — Running cost/token display, per-tool progress indicator, agent sidebar status (idle/working/error), scroll-to-bottom button. *Soft deps on Epic 2 and 5.*


## Dependency Graph

**[T]** *The dependency graph enables maximum parallelism:*

```
Epic 1 (Rendering)     ─── independent
Epic 2 (Streaming)     ─── independent
Epic 3 (Input)         ─── independent
Epic 4 (Permissions)   ─── independent
Epic 5 (Slash Cmds)    ─── independent
  └─► Epic 6 (Custom Cmds)  ─── blocked by Epic 5
  └─► Epic 7 (Mgmt UIs)     ─── blocked by Epic 5
Epic 8 (Side Pane)     ─── external dep (file viewer agent)
Epic 9 (UX Polish)     ─── soft deps on Epic 2, Epic 5
```

*Epics 1-5 can all start immediately with independent agents. Epic 6 and 7 unblock once Epic 5's infrastructure lands.*


## Beads Created

**[C]** Created all beads via `bd create`:

| Epic | Subtasks | Key Labels |
|------|----------|------------|
| Epic 1: Message Rendering Overhaul | 9 | v1, chat, ui |
| Epic 2: Streaming Responses | 4 | v1, streaming, sdk |
| Epic 3: Input Enhancement | 2 | v1, input, chat |
| Epic 4: Permissions Subsystem | 5 | v1, permissions |
| Epic 5: Slash Cmd Infra + Core Cmds | 9 | v1, commands, infrastructure |
| Epic 6: Custom Slash Commands | 4 | v1, commands, customization |
| Epic 7: Management UIs | 3 | v1, commands, management |
| Epic 8: Side Pane | 3 | v1, side-pane |
| Epic 9: Chat UX Polish | 4 | v1, chat, polish |
| **Total** | **43 subtasks** | |

All subtasks linked to parent epics via `parent-child` dependency. Epic 5 → Epic 6 and Epic 5 → Epic 7 linked via `blocks` dependency.


## Cross-Links to Existing Beads

**[C]** Linked 4 pre-existing beads via `relates_to`:

- "Streaming responses — replace batch-only with real-time UI" ↔ Epic 2
- "Component-based chat views — thinking, tools, text as separate renderers" ↔ Epic 1
- "Token budget and cost visibility — per-agent budgets and spend tracking" ↔ Epic 9
- "Resource panel / file viewer — IDE-lite right-side panel" ↔ Epic 8

**[T]** *These existing beads predate the V1 plan but cover overlapping scope. The relates_to links ensure agents working on the new V1 epics can discover relevant prior context.*


___


**[S]** This session established the complete tracking infrastructure for V1 chat parity. The 9-epic structure is designed for parallelism — 5 epics can start immediately with independent agents. The dependency graph is minimal: only Epic 6 and 7 wait on Epic 5's slash command infrastructure. Everything selected ships; the scope is fixed, the execution is what's being parallelized.
