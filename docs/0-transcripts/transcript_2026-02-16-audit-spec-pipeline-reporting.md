# Transcript: Audit-Spec PRD Pipeline Flow Reporting

**Date:** 2026-02-16
**Session:** `e389b1f0`
**Topic:** Extending `/audit-spec` with top-to-bottom PRD pipeline flow reporting

---

## The Question

[U] This is a report, what do you propose to do with it, though?

[C] Recognized the gap: `/audit-spec` was presenting its output as if something needed to be done with it, but it's a read-only audit report. There's nothing to "do" — the skill just displays results. Pivoted to presenting it directly inline.

[U] Write this down to markdown, then run `open` on it.

[C] Written to `docs/2-spec/spec-audit-2026-02-16.md` and opened.

---

## PRD Coverage Completeness

[U] Is PRD coverage complete? Or are there sections of the PRD that still need coverage?

I also want some reporting starting from the PRD — what percentage of the PRD appears downstream in implementation and testing? Give me the top to bottom too.

[C] PRD→Spec coverage is **complete** — all 41 non-context sections map to spec modules, and upstream references check out.

[T] *The real gap isn't between PRD and spec — it's the flow from spec down through code and tests. The audit already had the data; it just needed to be restructured as a pipeline table.*

Computed the top-to-bottom view:

**PRD → Spec → Code → Tests (Full Pipeline)**

| PRD Section(s) | Spec Module | Reqs | Impl'd | Tested | Code% | Test% |
|----------------|-------------|------|--------|--------|-------|-------|
| §2 Invariants | 002-invariants | 8 | 4 | 3 | 50% | 38% |
| §6.1 Tech Stack | 003-system-architecture | 10 | 8 | 3 | 80% | 30% |
| §4.1–4.3 Agent Types/States/Modes | 004-agents | 10 | 7 | 6 | 70% | 60% |
| §6.2, §6.3, §7 Spawn/Queues/Naming | 005-spawning | 10 | 9 | 9 | 90% | 90% |
| §12, §13 Fish-or-Cut-Bait/Rewind | 006-lifecycle | 7 | 2 | 1 | 29% | 14% |
| §4.4, §5.2 Operating Modes/Attention | 007-operating-modes | 6 | 5 | 3 | 83% | 50% |
| §4.7 Deterministic Shell | 008-deterministic-shell | 8 | 7 | 2 | 88% | 25% |
| ... | ... | ... | ... | ... | ... | ... |

---

## Updating the Audit Command

[U] Yes, and update the audit command to include these instructions going forward.

[C] Updated two things:

1. **Audit file** (`docs/2-spec/spec-audit-2026-02-16.md`) — Added the full pipeline flow section with per-PRD-section downstream coverage table, aggregate flow diagram, unimplemented breakdown, and test coverage gap analysis.

2. **Slash command** (`.claude/commands/audit-spec.md`) — Added step 9 (PRD Pipeline Flow) with instructions to generate the per-section table, aggregate flow diagram, transition rates, unimplemented categorization, and test gap analysis. Renumbered the summary to step 10.

___

[S] *The key insight is that `/audit-spec` now reports in two directions: (1) structural integrity (provenance markers, count mismatches, orphans) and (2) pipeline flow (what percentage of PRD requirements actually reach code and tests). These are different questions with different audiences — the first is for maintainers keeping the pipeline healthy, the second is for understanding implementation completeness.*

---

## Spec Convention: Strikethrough for Dropped Requirements

*From session `0a261fe0` (2026-02-22)*

[U] When we drop sections in the spec, can you cross them out in markdown as well, so it's visually apparent? We can include the rationale comment visibly too.

[C] Confirmed: use `~~strikethrough~~` on the heading and all body content. Status line stays unstruckthrough, reads `dropped — rationale in italics`.

[U] No, keep the content, just struck through. We can learn from mistakes.

[T] *The original proposal was to delete dropped content. The user's correction preserves it as struck-through — visible history of what was tried and abandoned, with the rationale inline. "We can learn from mistakes" is the principle.*

[C] Finalized convention:
- Dropped requirement headings use `~~strikethrough~~`
- All body content (Source, Priority, Properties, Testable assertion) struck through
- Status line is **not** struck through: `dropped — *rationale here*`
- No hidden HTML comments — rationale always visible inline
- Content preserved for historical record

This convention is documented in `docs/2-spec/000-index.md` §5 (Dropped Requirements).

___

[S] *The strikethrough convention reflects a broader principle: deleted history is lost history. Keeping dropped requirements visible in the spec — with rationale — lets future maintainers understand what was tried and why it was abandoned. The spec is not just a current-state snapshot but a record of the design process.*
