# Transcript Audit & Repair

Audit all session history for missing design transcripts and repair gaps.

## Process Overview

1. **Discovery** — Identify all sessions and existing transcripts
2. **Parallel Verification** — Launch rewind agents to check coverage
3. **Repair** — Write any missing transcripts (serialized)
4. **Final Audit** — One agent verifies completeness

## Step 1: Discovery

First, gather the data:

```bash
# List existing transcripts
ls -la docs/seed-design/transcript_*.md

# List major sessions (>100KB)
find ~/.claude/session-archives/-Users-yankee-Documents-Projects-the-tavern-at-the-spillway -name "*.jsonl" -size +100k -exec ls -lh {} \;

# Count sessions by date
for f in ~/.claude/session-archives/-Users-yankee-Documents-Projects-the-tavern-at-the-spillway/*.jsonl; do
  ts=$(head -1 "$f" | jq -r '.timestamp // empty' 2>/dev/null)
  size=$(ls -lh "$f" | awk '{print $5}')
  echo "$ts | $size | $(basename $f)"
done | sort
```

## Step 2: Parallel Verification

Launch 5-7 rewind agents in parallel, each covering a date range or batch of sessions.

**Agent prompt template:**
```
You are a transcript verification agent for the-tavern-at-the-spillway project.

## Your Mission
Verify if existing transcripts cover the design discussions in these sessions. If you find crucial missing content, produce ONE transcript and terminate immediately.

## Sessions to Review
[List session files with paths and sizes]

## Existing Transcripts
[List relevant transcripts by date]

## Instructions
1. Read session files using jq to extract user messages (sample large files)
2. Read existing transcripts to understand what's covered
3. Look for design discussions NOT in transcripts:
   - Design principles
   - Architecture decisions
   - Feature discussions
   - Process/methodology discussions
   - [U] content that looks like interview material
4. If you find missing content:
   - Produce a transcript following [U], [C], [T], [S] notation
   - Return filename and full content
   - STOP after ONE transcript
5. If nothing missing, report what you verified

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
- Group sessions by date range (Jan 18-19, Jan 20, Jan 21 early, Jan 21 late, Jan 22, Jan 23-25)
- Each agent gets 2-4 sessions max
- Large sessions (>20MB) get dedicated agents

## Step 3: Repair

For each agent that returns `MISSING_FOUND`:
1. Extract the transcript filename and content
2. Write to `docs/seed-design/[filename]`
3. Serialize writes (one at a time to prevent contamination)

## Step 4: Final Audit

Launch one final agent to verify completeness:

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

## Key Files

**Session archives:**
~/.claude/session-archives/-Users-yankee-Documents-Projects-the-tavern-at-the-spillway/

**Transcripts:**
docs/seed-design/transcript_*.md

**Transcript format reference:**
- [U] — User's words (high fidelity)
- [C] — Claude's responses
- [T] — Claude's thinking (italics)
- [S] — Synthesis (after `___` divider)

## When to Run

- After extended development sessions
- Before major milestones
- When context compaction may have lost design discussions
- Periodically to ensure continuity

## Success Criteria

- All major sessions audited
- All design discussions captured in transcripts
- Final audit returns ALL_COVERED with HIGH confidence
- Implementation-only sessions appropriately have no transcripts
