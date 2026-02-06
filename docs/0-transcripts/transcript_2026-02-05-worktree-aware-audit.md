# Transcript: Worktree-Aware Audit Discovery

**Date:** 2026-02-05
**Session:** Adding worktree-aware session discovery to the transcript audit system
**Branch:** `transcript-audit`


## Context

The `/audit-transcripts` command (created Jan 25) hardcoded a single session archive path. When the project adopted ccmanager for git worktrees, sessions got duplicated across multiple Claude project directories — one per worktree. The audit needed updating to find and deduplicate sessions across all worktrees.


## The Problem

**[T]** *ccmanager creates git worktrees as subdirectories and copies `~/.claude/projects/<path>` session files into new directories matching each worktree's path. This means the same session ID can exist in multiple locations:*

- `~/.claude/projects/-Users-yankee-Documents-Projects-the-tavern-at-the-spillway/` (main)
- `~/.claude/projects/-Users-yankee-Documents-Projects-the-tavern-at-the-spillway-transcript-audit/` (worktree)

*Without deduplication, audit agents would analyze the same session multiple times, wasting time and potentially producing duplicate transcripts.*


## Solution: Helper Scripts

**[C]** Created two scripts in `scripts/audit/` to encapsulate the worktree discovery complexity:

**`list-project-dirs.sh`** — Uses `git worktree list --porcelain` to enumerate all worktrees, then encodes each path using Claude's naming convention (`/` → `-`) and checks if the corresponding `~/.claude/projects/` directory exists. Works from any worktree (uses `git rev-parse --git-common-dir` to find the main repo).

**`list-sessions.sh`** — Iterates all project directories from `list-project-dirs.sh`, collects every `.jsonl` session file, and deduplicates by session ID. When the same session ID exists in multiple directories, keeps the copy with the newest modification time.

Options: `--min-size BYTES`, `--json`, `--paths-only`, `--quick` (mtime instead of timestamp parsing).


## Design Decisions

**[T]** *Key choices in the deduplication strategy:*

1. **Newest-by-mtime wins** — When a session ID appears in multiple directories, prefer the copy with the latest modification time. Active sessions in worktrees may have newer content than the original copy.

2. **Associative arrays for O(1) dedup** — Bash `declare -A` maps session IDs to file paths and mtimes, so duplicate detection is constant-time per file.

3. **Script separation** — `list-project-dirs.sh` is reusable for any worktree-aware tooling, not just session listing. `list-sessions.sh` composes on top of it.

4. **Quick mode** — `--quick` uses file mtime instead of parsing JSONL for timestamps. Much faster for large session counts, slightly less accurate for sorting.


## Command File Updates

**[C]** Updated `.claude/commands/audit-transcripts.md`:

- Step 1 renamed "Discovery (Worktree-Aware)" with explanation of why deduplication matters
- Discovery commands now use the helper scripts instead of hardcoded `find` commands
- Session directory section updated to explain worktree duplication pattern
- Agent prompt template updated to use "deduplicated session files"


## User Completeness Check

**[C]** Added a fourth instruction to the agent prompt template:

> 4. **User completeness check**: Verify that EVERYTHING the user said in the session is accounted for in transcripts. User statements are primary sources — nothing they said should be lost or summarized away.

This was also added to the Success Criteria section. The principle: user statements are primary sources. Transcripts must account for everything the user said, not just design decisions Claude identified as important.


---

## [S] Synthesis: Infrastructure for Transcript Maintenance

___

### Worktree-Awareness as Infrastructure

The audit system graduated from a one-shot command with hardcoded paths to a composable toolchain:

- **`list-project-dirs.sh`** — general-purpose worktree enumeration
- **`list-sessions.sh`** — session discovery with deduplication, filtering, multiple output formats
- **`audit-transcripts.md`** — orchestration command that uses the scripts

This separation means new tools (e.g., session statistics, cleanup scripts) can reuse the discovery infrastructure without reimplementing worktree logic.

### The User Completeness Principle

Adding the user completeness check reflects a maturation of the audit methodology. The original audit focused on "design discussions" — a judgment call about what's important. The new check is objective: did we capture what the user actually said? This shifts the standard from "important content covered" to "no user content lost."
