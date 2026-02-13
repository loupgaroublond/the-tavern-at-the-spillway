# Transcript: Spec Enumeration with Stable Content Addressing

**Date:** 2026-02-12
**Type:** Specification infrastructure / cross-referencing design

---

[U] Let's enumerate the spec documents, so that the first document is 0, and so on. Then, we can address different clauses across the spec by numbers like 0.4.2, which is section 4.2 in the first doc. File names should use NNN, like 001, to make sure they get sorted properly. If we break up a spec file into sub files, the content addressing should still remain the same. Content can only be added to the enumerated list, so that once we assign a number to a section, it follows the section for the whole lifetime.

This will allow us to point to other parts of the spec, where they're related. The goal for this is to help us keep parts of the spec concise rather than duplicating too much info.

[C] Explored all 16 spec modules plus `index.md`. Each file already uses `## N.` section headings internally, and requirements are numbered sequentially (REQ-PREFIX-NNN). This means the addressing scheme can layer on top of the existing structure — `§DOC.SECTION.SUBSECTION` maps directly to document number, section heading, and requirement order.

*[T] Key insight: the `§` prefix distinguishes spec references from PRD section numbers (which also use §N notation). Leading zeros dropped in references for readability — `§4.2.5` not `§004.2.5`.*

[U] *(On whether index.md gets a number or stays unnumbered)* It's 000, and 001 is some kind of intro document.

[C] Got it — 000 is the index, 001 is an intro/preamble that explains the conventions. Read several spec files to verify section structure is consistent across all modules.

[U] Does this change have all the thorough steps for the whole project? I just see the renumbering itself.

[C] You're right — the numbering is just the foundation. The real goal is using it to deduplicate and cross-reference. Did a deep analysis across all 16 spec files and found 27 duplication/cross-reference opportunities — 12 major concepts restated in multiple files.

*[T] The analysis surfaced a clear pattern: high-value concepts like "two-level orchestration" and "commitment verification" are explained in 3-4 files each, with varying detail. Each file adds its own domain-specific angle but restates the base concept. The fix: designate one file as canonical home, and have others reference it via `§` address.*

[C] Expanded the plan to four phases:

1. **Rename and number** — `git mv` all files, add NNN to titles, create 001-introduction.md, update 000-index.md
2. **Internal references** — Update Upstream/Downstream sections and inline cross-refs
3. **Deduplication** — 12 concepts with canonical homes, non-canonical copies shortened to "See §X.Y.Z"
4. **External documentation** — Update CLAUDE.md, pipeline.md, project-status.md, open-beads-reader.md; leave historical transcripts untouched

Also checked which external files reference spec filenames — 4 live docs need updating, 4 historical docs left as-is, scripts work regardless of naming.

___

[S] **Stable content addressing for specs.** The `§DOC.SECTION.SUBSECTION` scheme layers onto existing structure without changing REQ codes. Append-only numbering means addresses are permanent — retired content keeps its number. Sub-file splitting preserves addresses by converting a file into a directory with `_index.md`. The addressing enables concise cross-references that replace restated content, keeping each spec module focused on its own domain.

**Document ordering rationale.** Rules (002) → Architecture (003) → Agents: creation (004-005) → lifecycle (006) → operation (007) → control (008) → communication (009) → Infrastructure: storage (010) → safety (011) → workflows (012) → Presentation: UX (013) → views (014) → Operations: monitoring (015) → testing (016) → Scoping (017).

**Deduplication strategy.** 12 concepts identified across spec files, each assigned a canonical home. Non-canonical copies keep their domain-specific angle but replace restated base concepts with `**See also:** §X.Y.Z` references. Five high-priority concepts appear in 3+ files (two-level orchestration, agent state machine, commitment verification, done signal detection, mock/AgentMessenger testability). Seven medium-priority concepts appear in 2 files.
