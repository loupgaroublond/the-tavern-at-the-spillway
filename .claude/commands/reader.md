# System Design Reader Synthesis

Generate a standalone "System Design Reader" document that synthesizes all transcripts in `docs/0-transcripts/`.

## Purpose

Someone with zero prior context can read this instead of tailing transcripts. This is the authoritative summary of the system design as understood through the conceiving process.

## Output

Write to: `docs/0-transcripts/reader_$DATETIME.md` (use current datetime, e.g., `reader_2026-01-25-1430.md`)

## Structure

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

## Rules

- Write for a reader with zero memory of past sessions
- Include timestamps and source references for traceability
- Use plain technical names, not character voice (Jake's colorful vocabulary is presentation layer)
- Flag resolved vs unresolved questions clearly
- When updating from a previous reader, carry forward all content and ADD new material — don't lose information
- Reference the previous reader if one exists, noting what's new

## Before Writing

1. Read the current reader (if any) to understand baseline
2. Read all transcript files to find new content since last reader
3. Read process doc for open questions status
4. Identify what's new vs what's unchanged

## After Writing

Commit with message: "Update system design reader with [brief summary of new content]"
