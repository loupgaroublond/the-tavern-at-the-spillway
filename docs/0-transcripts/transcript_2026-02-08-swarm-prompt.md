# Transcript: Swarm Coordinator Prompt

**Date:** 2026-02-08
**Topic:** Extracting and adapting a team coordinator prompt from ClodKit for the Tavern project
**Files produced:** `SWARM.md` (project root), `archive/swarm-prompt.md` (archive copy), `docs/0-transcripts/team-coordinator-prompt.md` (original + adapted)

---

[U] in the clodkit project, namely in ~/.claude/projects, there was one session where i gave a prompt to go clear out a bunch of beads and how to use a team to accomplish that. can you go pull up that prompt, and then we'll write a new one based off it, relevant to this project

[C] Searched ClodKit session files in `~/.claude/projects/-Users-yankee-Documents-Projects-ClodKit/`. Found the prompt in session `84f88d36-0725-43e2-993c-9fb117e1b848`. Extracted the full user prompt — a comprehensive team coordinator instruction covering worktrees, bead assignment, merge coordination, model selection, and efficiency.

[U] first write it down, and then have a look at all the open beads and we'll talk about which ones to work on. make sure when you run bd list, you use -n 0 because there's more than 50 beads

[C] Saved the original prompt plus an adapted version to `archive/team-coordinator-prompt.md`. Ran `bd list -n 0 --status open` and `bd epic status`. Found ~110 open beads across 11 epics + 7 standalone items. The backlog epic (`azu`, 47 items) is described as "starting points for discussion" — not execution-ready. The actionable work is ~66 beads across 9 numbered epics, the spec-fill epic, and 7 standalone items.

[U] everything except the feature backlog

[C] Drafted the adapted prompt scoped to all open beads excluding `the-tavern-at-the-spillway-azu`.

[U] put xcodegen at the top, and order them based on redo dependencies, so that run is on the bottom, and then make it clear that each command does all of the above and this new thing

[C] Read all the redo scripts (`test.do`, `test-core.do`, `test-integration.do`, `test-all.do`, `test-grade3.do`, `test-grade4.do`, `build.do`). Found that:
- `test-core` uses `swift test --filter TavernCoreTests` — framework layer only, fastest
- `test` uses `swift test --skip TavernIntegrationTests --skip TavernStressTests` — all Grade 1+2
- Neither explicitly calls `redo build` — `swift test` compiles internally
- `build.do` depends on xcodegen via `redo-ifchange`

Updated the build chain as cumulative: xcodegen → build → test → test-core → run.

[U] swap test and test-core, also, explain why you would use one over the other, dig into those redo scripts to find out

[C] Swapped order and added guidance: use `test-core` when changes are limited to `Sources/TavernCore/` (fastest feedback loop), use `test` when touching the app target or before merging. Both skip Grade 3+ integration tests.

___

[S] **File placement discussion:**

[U] why's the file in archive? doesn't it belong somewhere else?

[C] Moved to `.claude/commands/swarm.md` as a slash command.

[U] no, in its current form, it's just a document, put it in transcripts

[C] Moved to `docs/0-transcripts/team-coordinator-prompt.md`.

[T] *The user distinguishes between actionable slash commands and reference documents. The prompt in its current form is a template/reference — not yet wired up as a command.*

___

[S] **Creating the execution-ready SWARM.md:**

[U] now, put a copy of just the tavern prompt into a file at the root. then add an instruction to delete the file at the root as the very last step. also, in the prompt add somewhere if the agent is in plan mode, the user is asking for them to propose a plan for orchestrating a team, rather than just jumping into the task. add that when merging in all the work, the team agents must run grade 3 tests on their code. when you merge in code, you will also run the grade 3 tests. however, since those use finite resources, we don't want to run them every testing cycle. finally, when merging in all the work at the very end of this process, wait for the user's signal to run the grade 4 tests

[C] Created `SWARM.md` at project root with four additions:
1. **Plan mode** — propose the orchestration plan for approval instead of executing immediately
2. **Grade 3 merge gate** — agents run Grade 3 before merging, coordinator runs Grade 3 after merging, but never during regular dev cycles (finite API resource)
3. **Grade 4 hold** — wait for user signal at the very end (XCUITests steal focus)
4. **Self-destruct** — delete `SWARM.md` as the final step

[U] now save a copy of this in archive

[C] Copied to `archive/swarm-prompt.md`.
