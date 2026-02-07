# Transcript: Backlog Mining from Transcripts & Sessions

**Date:** 2026-02-05 to 2026-02-06
**Sessions:** c2aa29d5 (initial mining), 5a6334db (incremental pass + commit)
**Topic:** Comprehensive backlog extraction from all project sources into beads


## Context

Two sessions spanning two days performed systematic mining of all project documentation, transcripts, session archives, code TODOs, and branch diffs to populate the beads issue tracker with a complete backlog.


## Session 1: Initial Mining (Feb 5)

[U] Let's go through all the transcripts and the session logs in ~/.claude, grab everything that looks like a potential bead task, grab the main information needed for that, and then create a bead with two things. Make a backlog epic for this to go into, and then make sure the instructions clearly state, use this as a starting point for discussion with the user, these are not final clearly defined tasks of their own.

[T] *Claude read all 29 transcripts (via reader_2026-02-05.md), the PRD, implementation plan, project status, open questions (?2-?19), code TODOs, and handoff docs. Created epic `azu` and 40 child beads across 4 priority tiers.*

[C] All 40 children linked to the epic. Here's the summary:

**Epic: Tavern Feature Backlog — Mined from Transcripts & Sessions** (`the-tavern-at-the-spillway-azu`)

40 child beads created across 4 priority tiers. Every bead is marked "DISCUSSION STARTING POINT — not a final task" with source references and key questions for discussion.

**P1 — Critical (5 beads):**
- Streaming responses (replace batch-only)
- Jake autonomous spawning (real Claude for agents)
- Real commitment verification (replace mocks)
- SDK testing strategy (restore testability post-ClodeMonster)
- ClodeMonster apostrophe bug (shell escaping)

**P2 — High (10 beads):**
- Perseverance mode & lifecycle states
- Agent hierarchy (trees, Erlang-style depth)
- Inter-agent communication (bubbling)
- Calling & hanging up protocol
- Sidecar pattern (separate I/O actors)
- Doc store continuous sync
- Composable tile view system
- Notification & attention routing
- Token budget & cost visibility
- Preflight checks

**P3 — Medium (16 beads):**
- Plugin system, violation monitoring, work queues, workflow engine
- Gang of experts, model selection, context cards, .tavern/ config
- Inter-agent message storage, sandbox/changesets
- Fish-or-cut-bait, user consent UX, agent reasoning visibility
- GUI testing, metrics & telemetry

**P4 — Backlog (9 beads):**
- Progressive unlocks, saved layouts, rewind & branch
- Merge queue, rollback, hygiene daemons
- Discovery sharing, iCloud sync, self-improvement

**Sources mined:** All 29 transcripts (via reader_2026-02-05.md), PRD, implementation plan, project status, open questions (?2-?19), code TODOs, handoff docs.

[T] *Note: This session created the beads but never committed the JSONL export. The `bd sync --flush-only` wasn't run, leaving `issues.jsonl` empty in git.*


## Session 2: Incremental Pass (Feb 6)

[U] Let's go through all the transcripts and the session logs in ~/.claude, grab everything that looks like a potential bead task, grab the main information needed for that, and then create a bead with two things. Make a backlog epic for this to go into, and then make sure the instructions clearly state, use this as a starting point for discussion with the user, these are not final clearly defined tasks of their own.

[C] Let me gather everything first — transcripts, session logs, and existing beads — in parallel.

[T] *Claude discovered the existing epic with 40 children and shifted to finding gaps. Scanned: latest reader open questions, 2 newer transcripts (Feb 2, Feb 5), 566 session archives across 13 worktrees (474 MB), all code TODOs (7 occurrences, all SDK mocking), and the `new-sdk` branch diff.*

[C] Good — there's already an epic with 40 children. Let me find what's **not** covered yet by scanning the latest reader for open questions, the newer transcripts, session archives, and code TODOs.

[C] Great, I have a complete picture now. Here's what I found:

**Existing coverage:** The epic `azu` already has 40 children covering most transcript-sourced items.

**Issues:**
- Duplicate bead: `7g6` and `w3u` both track "Streaming responses"

**New items NOT yet tracked** (from recent sessions and the reader):

1. **Resource panel / file viewer** — Right-side panel with file tree, diffs, file contents. Goal: make Tavern usable without a separate IDE by v1.5. *(from resource-viewer session)*

2. **Formal spec pipeline** — Transcripts → PRD → specs → ADRs → code → tests → docs with incremental downstream propagation. *(from formal-spec session)*

3. **ClodKit SDK migration** — Clean rename from ClodeMonster to ClodKit on `new-sdk` branch. Needs merge + doc updates. *(from new-sdk branch)*

4. **Component-based chat views** — Render thinking blocks, tool use, text as separate SwiftUI components within chat. Distinct from tile layout (`coj`). *(from reader TBD)*

5. **Background agent execution** — Agents working autonomously while user is elsewhere. Not explicitly covered by sidecar (`vfx`) or perseverance (`pbt`). *(from CLAUDE.md "Not Implemented")*

6. **Session classification automation** — Auto-classify sessions into design/transcription/implementation categories. *(from transcript_2026-02-02)*

[U] So this was partly done already?

[C] Yeah — a previous session had already created the epic and mined 40 items from the transcripts and PRD. That pass covered the core design concepts well (agent trees, sidecar pattern, tile views, doc store, etc.).

What I added just now was from sources that pass missed or that didn't exist yet:

- **3 active worktree sessions** (resource-viewer, formal-spec, new-sdk) — these branches are from the last day or two, after the original mining
- **1 reader TBD** (component-based chat views) that wasn't surfaced as its own bead
- **1 CLAUDE.md gap** (background agent execution was listed as "Not Implemented" but had no bead)
- **1 transcript item** (session classification from the Feb 2 audit transcript)

Plus the duplicate cleanup (`w3u`/`7g6` were identical streaming beads).


### Git Sync Issue

[U] Are the .beads not tracked in git?

[C] The files are tracked in git, but `issues.jsonl` is empty — the beads were created after the last commit and `bd sync --flush-only` didn't export them.

[T] *Ran `bd sync --flush-only` which exported 50 lines to issues.jsonl — but it went to the main worktree, not the backlog worktree.*

[C] The original beads batch (40 items) was created by a previous session that apparently never committed the export. The 6 new ones I just added are in there too.

[U] Why 50 lines? And is it 46 items? Or 47 items?

[C] 50 lines because there are 50 beads total:

- **47 open** (45 real items + 1 epic + the `my4` resource panel that replaced the duplicate)
- **3 closed** (2 duplicates I closed: `w3u` and `6ap`, plus a `ate` "Test dep" from what looks like someone testing beads)

The JSONL exports everything including closed items. `bd list` shows 47 because it filters to open by default.

So the real item count is **46 open items** (45 children + 1 epic), plus 3 closed junk.

[U] What just happened to the backlog?

[T] *User noticed `git status` was clean on the backlog branch — the sync had gone to the wrong worktree.*

[C] The beads are in the bd database but the JSONL export went to the wrong place. When I ran `bd sync --flush-only`, I `cd`'d to `/Users/yankee/Documents/Projects/the-tavern-at-the-spillway` (the main worktree), so the export landed in main's `.beads/issues.jsonl` — not here in the backlog worktree.

[T] *Root cause: The SQLite database only exists in the main worktree. The backlog worktree has no `.beads/*.db` and no redirect file. `bd sync` from the backlog worktree exported 0 lines.*

[C] The simplest fix is to just copy the exported JSONL over.

[T] *Copied the 50-line issues.jsonl from the main worktree to the backlog worktree. It now shows as modified on the backlog branch.*


___

## [S] Synthesis

### Backlog Mining as Two-Pass Process

The full backlog mining happened across two sessions. The first pass (Feb 5) was comprehensive — reading all 29 transcripts, the PRD, implementation plan, project status, and code TODOs — producing 40 beads organized under an epic. The second pass (Feb 6) was incremental, catching 6 items from sources that either didn't exist during the first pass (active worktree sessions from the last 24 hours) or were missed (reader TBDs, CLAUDE.md gaps).

This two-pass pattern is natural for a living project: the first sweep establishes baseline coverage, subsequent passes catch new work as it emerges from active development branches.


### Beads + Worktrees: Sync Friction

The bd tool stores its database in `.beads/*.db` which lives in one worktree. Other worktrees see the committed JSONL but have no live database connection. `bd sync --flush-only` only writes to the worktree where the database lives, not the one you're working in.

Workaround: copy the exported JSONL manually. This is a known friction point with git worktree workflows — the database and the export target can be in different working directories.


### Item Counts

Final state after both passes:
- **1 epic** (`azu`)
- **45 open children** (40 original + 6 new - 1 duplicate closed)
- **3 closed** (2 duplicates: `w3u`, `6ap` + 1 test item: `ate`)
- **50 lines** in issues.jsonl (exports all statuses)
