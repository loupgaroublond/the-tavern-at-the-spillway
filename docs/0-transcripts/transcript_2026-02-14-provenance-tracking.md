# Transcript: Provenance Tracking System

**Date:** 2026-02-14
**Sessions:** Spec review → planning → implementation
**Topic:** Machine-readable traceability between specifications and implementations

---

[U] Have a look at all the beads concerning the spec, read them through, give me a list of their titles, and then, we'll start working on the spec together.

[C] Read through all spec-related beads. Found the `vpn` epic (16/16 children complete), three tooling beads (`f99` for /spec-status, `e4p` for /trace, `9uc` for /audit-spec), and `azy` (formal spec pipeline, blocked on the backlog epic `azu`). Presented titles and statuses.

[U] I had some different ideas, but first, bead azy, look at its completed beads, I think we completed that work, so, does it need to be blocked on the backlog? Maybe not.

[C] Checked `azy`'s dependency on the backlog epic `azu`. The pipeline discussion (`azy`) was blocked on the backlog mining epic, but the pipeline work (pipeline.md, the full spec module suite) was completed independently. The dependency no longer applies.

[T] *User is reframing the beads — the pipeline discussion bead doesn't need to be gated on the massive backlog mining epic. The pipeline work happened organically through other sessions.*

[U] That can be part of your plan, but first, go through the spec files, give me a rundown of all the open questions.

[C] Read all 16 spec modules (002–017) and cataloged ~70 open questions across them. Heaviest areas: Communication (6), Lifecycle (6), Deterministic Shell (6), Spawning (6), Agents (5). Presented the full list organized by module.

[U] VPN can be closed, so let's talk about the P2 group. We need an ADR that requires comments in code, tests, and docs that link it back to the ADR, spec, or PRD section it implements. With provenance tracking, we can properly provide status updates, and perform audits and traces easily.

We also need to work this back into the PRD. This ADR can't come from nowhere, so we need a section in the spec for detailed requirements on ensuring fidelity to the spec, and therefore a section at the bottom of the PRD also requiring full adherence and so on to the spec, but high level.

Otherwise, this ADR would come out of nowhere and not make sense.

After that, we can go implement those other tooling beads, and then perform the first audit, and remediation by making sure we have accounted backwards and forwards for everything. Every section of code must work back to some doc, and every section of every doc must work forward to something.

[C] Understood the scope: this is a pipeline-compliant provenance tracking system. The ADR needs upstream justification through the full pipeline — PRD section, then spec module, then ADR. Entered plan mode and designed a comprehensive implementation plan covering 8 steps: housekeeping (close vpn, unblock azy), PRD §19.4, spec module 018, index/intro updates, ADR-007, pipeline.md updates, CLAUDE.md honor system, and bead updates.

[T] *The key insight is the self-verification principle: if Invariant #3 says agent commitments must be verified independently, then development commitments (requirements → code) must be verifiable too. The development process is subject to the same rigor as the system itself.*

[U] *(Approved plan)*

[C] Implemented all 8 deliverables:

1. **PRD §19.4** — "Completeness and Correctness Standards" inserted after §19.3, covering the why (mistakes/regressions), the requirement (machine-readable provenance), and the self-verification principle.

2. **018-spec-fidelity.md** — New spec module with 7 requirements (REQ-FID-001 through REQ-FID-007): completeness verification, code provenance comments, test provenance tags, bidirectional reference, status derivation, coverage verification, comment format spec.

3. **000-index.md** — Updated coverage matrix (45 sections, 41 covered), module status (018 added), total requirements (162).

4. **001-introduction.md** — Updated to 19 modules (000–018), added document assignment row.

5. **ADR-007** — Provenance tracking decision record: MARK comments for code, Swift Testing `.tags()` for tests, bidirectional traceability, status derivation, incremental backfill. Five alternatives rejected (JSON sidecars, custom doc tags, filename conventions, external matrix, compiler directives).

6. **pipeline.md** — Expanded traceability rule, updated verification checks to reference grep-based provenance mechanism.

7. **CLAUDE.md Honor System** — Two new items: provenance MARK comments for new code, `.tags()` for new tests.

8. **Bead updates** — Added upstream spec references and data contracts to `f99`, `e4p`, `9uc`.

**Housekeeping:** Closed `vpn` epic (16/16 complete), removed `azy`'s dependency on `azu`.

___

[S] **Self-Verification Principle**

The development process that builds the system is subject to the same rigor as the system itself. Invariant #3 (commitments verified independently) applies not just to agents completing tasks, but to developers implementing requirements. If an agent can't self-certify completion, neither can a developer — provenance tracking makes this machine-verifiable.

**Pipeline Compliance Pattern**

When a new concern emerges that needs an ADR, it must be justified upstream first: PRD section (high-level why) → spec module (detailed requirements) → ADR (technical decisions) → implementation. This prevents orphaned decisions and maintains traceability. The pipeline is not just for features — it applies to process requirements too.

**The Provenance Data Contract**

The format `// MARK: - Provenance: REQ-PREFIX-NNN` was chosen for Xcode integration (jump bar navigation), greppability (simple tooling), and composability (comma-separated for multi-requirement files). Test tags use Swift Testing's `.tags()` for filtered test runs. Forward references (spec → code) are always computed, never manually maintained — preventing the drift that killed every previous traceability matrix approach.
