# Update Project Status

Update `docs/4-docs/project-status.md` to reflect all transcripts, including any newly created from audits.

## Process

### 1. Discover All Transcripts

```bash
ls -1 docs/0-transcripts/transcript_*.md | sort
```

### 2. Read Current Status

Read `docs/4-docs/project-status.md` and identify:
- Which transcripts are mentioned/covered in the Timeline section
- Which features have been documented

### 3. Find Uncovered Transcripts

Compare the transcript list against what's mentioned in `docs/4-docs/project-status.md`. A transcript is "uncovered" if:
- Its date/topic isn't referenced in the Timeline
- Its content isn't reflected in the Features sections

**Important:** Don't assume chronological ordering. Audits may create transcripts for older sessions that weren't captured at the time.

### 4. Read Uncovered Transcripts

For each uncovered transcript, read it and extract:
- **Timeline entry:** Date, key topics/decisions
- **Feature updates:** What was implemented, what was discussed as remaining

### 5. Update project-status.md

Merge the new information:

**Timeline section:**
- Add entries for uncovered transcripts
- Keep chronological order
- Use the established format: `- **YYYY-MM-DD HH:MM** — Brief description`

**Features sections:**
- Update "Implemented" lists with newly completed items
- Update "Remaining" lists (remove completed items, add new ones)
- Add new feature sections if needed

### 6. Update the Generated Date

Change the `**Generated:**` line to today's date.

## Quality Checks

Before writing the updated file:
- [ ] All transcript dates appear in Timeline
- [ ] No duplicate entries
- [ ] Timeline is chronologically sorted
- [ ] Feature sections reflect current state (not just additions)
- [ ] Implemented/Remaining lists are accurate based on transcripts

## Key Files

**Status file:** `docs/4-docs/project-status.md`
**Transcripts:** `docs/0-transcripts/transcript_*.md`
**PRD:** `docs/1-prd/prd_2026-01-19.md`

## When to Run

- After `/audit-transcripts` creates new transcripts
- After significant development sessions
- Before planning new work (to see current state)
- When resuming after context compaction
