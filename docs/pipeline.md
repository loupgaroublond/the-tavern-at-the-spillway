# Document Pipeline

**Last Updated:** 2026-02-07

## Overview

Every document in this project belongs to exactly one pipeline stage. Documents flow forward through numbered stages, with each stage consuming and refining the output of prior stages.

```
0-transcripts → 1-prd → 2-spec → 3-adr → [code] → [tests] → 4-docs → [product]
```

Stages 4-6 (code, tests, product) live in the main project structure (`Tavern/`), not in `docs/`.

## Stages

### Stage 0: Transcripts (`0-transcripts/`)

Raw design conversations and their artifacts. This is the primary source material.

**Contents:**
- Interview transcripts (`transcript_*.md`) — High-fidelity records of design discussions using [U]/[C]/[T]/[S] notation
- Reader syntheses (`reader_*.md`) — Compiled summaries of all transcripts (machine-generated, latest is authoritative)
- Vocabulary files (`vocab_*.md`) — Collected terminology decisions
- Notes (`notes_*.md`) — Topical notes from early sessions
- Design artifacts — Character specs, session handoffs, historical plans

**Update trigger:** After any design conversation (via `/conceive`)
**Verification:** `/audit-transcripts` checks all sessions have corresponding transcripts

### Stage 1: Product Requirements (`1-prd/`)

Formal requirements derived from transcripts. The PRD is the canonical statement of what the system must do.

**Contents:**
- `prd_2026-01-19.md` — Current PRD (versioned by date)

**Update trigger:** When design conversations reveal new requirements or change existing ones
**Verification:** Every transcript topic should be reflected in PRD sections

### Stage 2: Formal Specifications (`2-spec/`)

Testable, traceable specifications derived from the PRD. Each spec module covers a domain and maps requirements back to PRD sections.

**Contents:**
- `index.md` — Traceability matrix + coverage tracking
- 16 domain modules (see index.md for full list)

**Update trigger:** When PRD changes or when implementation reveals specification gaps
**Verification:** `index.md` must account for every PRD section; each module tracks its own completeness

### Stage 3: Architecture Decision Records (`3-adr/`)

Architectural decisions and the research that informed them. ADRs record the "why" behind technical choices.

**Contents:**
- `ADR-NNN-*.md` — Formal decision records
- Research documents (persistence guides, stress testing approach)
- `proposals/` — Architecture exploration documents that fed into ADRs

**Update trigger:** When spec requirements drive architectural choices
**Verification:** Each ADR should reference the spec requirements it addresses

### Stages 4-6: Code, Tests, Product

These live in `Tavern/Sources/`, `Tavern/Tests/`, and the built application respectively. They consume specs and ADRs.

### Stage 7: Documentation (`4-docs/`)

Post-implementation documentation that describes the built system. Written after code exists.

**Contents:**
- Architecture documentation (describes what was built)
- Instrumentation guides (describes logging practices)
- Status tracking (current implementation state)

**Update trigger:** After significant implementation milestones
**Verification:** Should accurately reflect current code state

## Flow Rules

1. **Forward only** — Each stage consumes from stages before it, never after
2. **Traceability** — Every document references its upstream sources
3. **Single home** — Every document belongs to exactly one stage
4. **No "reference" bucket** — Everything is either input, requirement, specification, decision, or post-code documentation
5. **Plans are ephemeral** — OODA loop artifacts (identify gaps → plan → execute → repeat) are not a permanent stage

## Incremental Update Flow

When new design conversations happen:

1. Transcribe → new `transcript_*.md` in `0-transcripts/`
2. Update reader (via `/reader`)
3. Update PRD in `1-prd/` if requirements changed
4. Update relevant spec modules in `2-spec/`
5. Update `index.md` traceability + status
6. If spec changes affect architecture → update/create ADRs in `3-adr/`
7. Downstream: code → tests → docs as needed

## Verification Checks

Each pipeline stage can be verified against its upstream:

| Check | Upstream | Downstream | Tool |
|-------|----------|------------|------|
| Transcript coverage | Sessions | Transcripts | `/audit-transcripts` |
| PRD coverage | Transcripts | PRD | (manual) |
| Spec coverage | PRD | Spec modules | `2-spec/index.md` matrix |
| ADR coverage | Spec | ADRs | ADR references in spec modules |
| Code coverage | Spec | Code | Downstream references in spec modules |
| Test coverage | Spec | Tests | Downstream references in spec modules |
