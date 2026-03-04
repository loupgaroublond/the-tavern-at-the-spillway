---
description: Light cleanup — audit transcripts, update reader, compile spec, update status
---

# Update Status — Light Cleanup Orchestrator

Run 4 cleanup steps in sequence with error gating. Each step must succeed before the next begins.

**Steps:** audit-transcripts → reader → spec-reader → status

**Error gating:** After each step, check result. "Nothing new found" is SUCCESS. Broken data, file write failures, exceptions = FAILURE → halt immediately.


---


## Step 1: Audit Transcripts

Audit all session history for missing design transcripts and repair gaps.

### 1a. Discovery (Worktree-Aware)

When using ccmanager, worktrees are created as subdirectories with copied sessions. The audit must find all related project directories and deduplicate sessions by ID.

**Why deduplication matters:**
- ccmanager copies `~/.claude/projects/<path>` sessions when creating worktrees
- Same session ID may exist in main AND worktree directories
- Without deduplication, agents would analyze the same session multiple times
- We prefer the newest copy (by mtime) in case of active sessions

**Discovery Commands:**

```bash
# Show all related project directories
./scripts/audit/list-project-dirs.sh

# List all sessions (deduplicated, sorted by timestamp)
./scripts/audit/list-sessions.sh

# Quick mode (uses mtime instead of parsing files)
./scripts/audit/list-sessions.sh --quick

# Major sessions only (>1MB)
./scripts/audit/list-sessions.sh --min-size 1000000

# Just session paths (for piping to other tools)
./scripts/audit/list-sessions.sh --paths-only --min-size 100000

# JSON output
./scripts/audit/list-sessions.sh --json --min-size 100000

# List existing transcripts
ls -la docs/0-transcripts/transcript_*.md 2>/dev/null || echo "No transcripts found"
```

### 1b. Parallel Verification

Launch 5-7 Agent subagents in parallel, each covering a date range or batch of sessions.

**Agent prompt template:**
```
You are a transcript verification agent for the-tavern-at-the-spillway project.

## Your Mission
Verify if existing transcripts cover the design discussions in these sessions. If you find crucial missing content, produce ONE transcript and terminate immediately.

## Sessions to Review
[List deduplicated session files with paths and sizes - use discovery script output]

## Existing Transcripts
[List relevant transcripts by date]

## Instructions
1. Read session files using jq to extract ALL user messages (type="human"). Never sample — verify every message.
2. Read existing transcripts to understand what's covered
3. Look for design discussions NOT in transcripts:
   - Design principles
   - Architecture decisions
   - Feature discussions
   - Process/methodology discussions
   - [U] content that looks like interview material
4. **User completeness check**: Verify that EVERYTHING the user said in the session is accounted for in transcripts. User statements are primary sources — nothing they said should be lost or summarized away.
5. If you find missing content:
   - Produce a transcript following [U], [C], [T], [S] notation
   - Return filename and full content
   - STOP after ONE transcript
6. If nothing missing, report what you verified

## Return Format
STATUS: [MISSING_FOUND | ALL_COVERED]
VERIFIED_SESSIONS: [list]
VERIFIED_TOPICS: [what's already covered]

[If MISSING_FOUND:]
TRANSCRIPT_FILENAME: transcript_YYYY-MM-DD-HHMM.md
TRANSCRIPT_CONTENT:
[full transcript]
```

**Batching strategy:**
- Group sessions by date range
- Each agent gets 2-4 sessions max
- **Large sessions (>20MB) must be chunked** — spawn multiple agents with message offsets so every user message is verified. Example: agent 1 gets messages 0-500, agent 2 gets 501-1000, etc. Never sample large files.
- Calculate message counts first: `jq -s '[.[] | select(.type=="human")] | length' < session.jsonl`

### 1c. Repair

For each agent that returns `MISSING_FOUND`:
1. Extract the transcript filename and content
2. Write to `docs/0-transcripts/[filename]`
3. Serialize writes (one at a time to prevent contamination)

### 1d. Final Audit

Launch one Agent subagent to verify completeness:

```
You are the final auditor for transcript coverage.

## Mission
Comprehensive audit to verify ALL design discussions are captured.

## Check
- All major sessions (list them)
- All transcripts (count: should be N after repairs)

## Return
AUDIT STATUS: COMPLETE - ALL COVERED
or
AUDIT STATUS: INCOMPLETE - MISSING CONTENT FOUND
[with transcript if missing]
```

### Step 1 Gate

- **SUCCESS** — Final audit returns ALL_COVERED, or MISSING_FOUND with repairs completed
- **FAILURE** — Agent errors, discovery script fails, or file write failures

If FAILURE, stop here. Report what went wrong. Do not proceed to Step 2.


---


## Step 2: Reader

Generate a standalone "System Design Reader" document that synthesizes all transcripts in `docs/0-transcripts/`.

Someone with zero prior context can read this instead of tailing transcripts. This is the authoritative summary of the system design as understood through the conceiving process.

**Output:** `docs/0-transcripts/reader_{DATETIME}.md` (use current datetime, e.g., `reader_2026-01-25-1430.md`)

### Structure

1. **Executive Summary** — What is this system? Core value proposition in 2-3 paragraphs.

2. **Problem Statement** — Pain points that drove the design. Include source references (transcript file + timestamp).

3. **Core Concepts** — Key abstractions with definitions:
   - Jake (daemon agent)
   - Mortal agents
   - Perseverance mode vs Chat mode
   - Bubbling
   - Agent naming
   - Any new concepts since last reader

4. **User Flow** — How someone uses the system, step by step. Starting a project, working with agents, zooming in/out, completing work.

5. **Architecture Notes** — Tech stack, agent hierarchy, communication patterns, session management.

6. **Core Systems** — Document store, workflow engine, sandbox primitives, etc. (from initial_notes.md walkthrough if covered).

7. **UI Concepts** — Dashboard, context cards, merge queue, question triage, session inbox, etc.

8. **Agent Communication** — Message protocol, lateral collaboration, surfacing questions.

9. **Open Questions** — Unresolved [?N] items with context for why they matter. Mark resolved ones as RESOLVED with resolution summary.

10. **Vocabulary Decisions** — Cogitation verbs, naming themes, terminology notes.

11. **Conversation Chronicle** — Chronological index of when topics were discussed. Format as tables with Time, Topic, Notes columns. Include session number and file references.

12. **Source Files** — Table listing all input documents and their purpose.

### Rules

- Write for a reader with zero memory of past sessions
- Include timestamps and source references for traceability
- Use plain technical names, not character voice (Jake's colorful vocabulary is presentation layer)
- Flag resolved vs unresolved questions clearly
- When updating from a previous reader, carry forward all content and ADD new material — don't lose information
- Reference the previous reader if one exists, noting what's new

### Before Writing

1. Read the current reader (if any) to understand baseline
2. Read all transcript files to find new content since last reader
3. Read process doc for open questions status
4. Identify what's new vs what's unchanged

### Step 2 Gate

- **SUCCESS** — Reader file written to `docs/0-transcripts/reader_{DATETIME}.md`
- **FAILURE** — File write fails or no transcripts found

If FAILURE, stop here. Report what went wrong. Do not proceed to Step 3.


---


## Step 3: Spec Reader

Compile all active spec modules into a single markdown file, stripping dropped sections.

Run the compilation script:

```bash
python3 scripts/compile-spec.py
```

This script:
1. Reads all spec modules from `docs/2-spec/` matching `NNN-*.md` (three-digit prefix)
2. Strips dropped sections in both formats: `<!-- DROPPED ... -->` HTML comments (legacy) and `~~strikethrough~~` headings (current format per 000-index.md §5)
3. Compiles active content into `docs/2-spec/compiled/spec-reader_YYYY-MM-DD.md`

Report the script's output:
- Total modules compiled
- Number of dropped sections skipped
- Output file path and size

### Step 3 Gate

- **SUCCESS** — Script exits 0 and output file created
- **FAILURE** — Script errors or output file missing

If FAILURE, stop here. Report what went wrong. Do not proceed to Step 4.


---


## Step 4: Status

Update `docs/4-docs/project-status.md` to reflect all transcripts, including any newly created from audits.

### 4a. Discover All Transcripts

```bash
ls -1 docs/0-transcripts/transcript_*.md | sort
```

### 4b. Read Current Status

Read `docs/4-docs/project-status.md` and identify:
- Which transcripts are mentioned/covered in the Timeline section
- Which features have been documented

### 4c. Find Uncovered Transcripts

Compare the transcript list against what's mentioned in `docs/4-docs/project-status.md`. A transcript is "uncovered" if:
- Its date/topic isn't referenced in the Timeline
- Its content isn't reflected in the Features sections

**Important:** Don't assume chronological ordering. Audits may create transcripts for older sessions that weren't captured at the time.

### 4d. Read Uncovered Transcripts

For each uncovered transcript, read it and extract:
- **Timeline entry:** Date, key topics/decisions
- **Feature updates:** What was implemented, what was discussed as remaining

### 4e. Update project-status.md

Merge the new information:

**Timeline section:**
- Add entries for uncovered transcripts
- Keep chronological order
- Use the established format: `- **YYYY-MM-DD HH:MM** — Brief description`

**Features sections:**
- Update "Implemented" lists with newly completed items
- Update "Remaining" lists (remove completed items, add new ones)
- Add new feature sections if needed

### 4f. Update the Generated Date

Change the `**Generated:**` line to today's date.

### Quality Checks

Before writing the updated file:
- [ ] All transcript dates appear in Timeline
- [ ] No duplicate entries
- [ ] Timeline is chronologically sorted
- [ ] Feature sections reflect current state (not just additions)
- [ ] Implemented/Remaining lists are accurate based on transcripts

### Step 4 Gate

- **SUCCESS** — `docs/4-docs/project-status.md` updated and passes quality checks
- **FAILURE** — File write fails or quality checks fail

If FAILURE, stop here. Report what went wrong.


---


## Completion

Report all 4 step results:

| Step | Command | Result | Detail |
|------|---------|--------|--------|
| 1 | audit-transcripts | SUCCESS/FAILURE | {summary} |
| 2 | reader | SUCCESS/FAILURE | {summary} |
| 3 | spec-reader | SUCCESS/FAILURE | {summary} |
| 4 | status | SUCCESS/FAILURE | {summary} |

**Files written:** List all files created or modified across all steps.

If all SUCCESS: "Light cleanup complete."
If any FAILURE: "Stopped at Step N: {reason}"
