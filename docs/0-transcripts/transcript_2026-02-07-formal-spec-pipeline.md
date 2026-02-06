# Transcript: Formal Specification Pipeline

**Date:** 2026-02-07
**Session type:** Design + Implementation
**Topics:** Document pipeline organization, formal spec skeleton, pipeline tooling, beads epic for spec fill


---


## Pipeline Concept

**[U]** Let's develop a formal spec for this project, and first, let's organize the documents we have to fit a sort of "pipeline", to make sure organizing them is as intuitive for agents and humans as possible.

The pipeline is transcripts → prd → specs → arch decision records → code → tests → docs → final product.

Ultrathink this out, and ask me to clarify anything that's not straightforward.

Then, for spec, let's start with all the transcripts and PRDs. Based off the PRD document, we need to create a skeleton of a spec, which we can then fill in with details from the transcripts, the actual session logs, or human input.

In terms of pipeline, what that means is as we talk out more things, add things to the PRD document, we want to be able to incrementally add that to the spec and all other resources downstream, and then be able to verify that each downstream element is complete according to the upstream element.


**[C]** Mapped existing documents to the pipeline stages. Identified 29 transcripts, 3 reader syntheses, 1 PRD, 1 ADR + 48 proposals, partial code and tests, and various reference docs. The reader acts as a "compiled transcript" — a bridge between raw transcripts and PRD/spec. Noted that `docs/seed-design/` currently mixes all pipeline stages 0-1 together.

Presented three design questions:
1. Organization approach — add spec/ only, full reorganization, or index + symlinks
2. Formality level — structured natural language, semi-formal, or formal methods
3. Spec shape — modular (~16 docs) or monolithic


**[U]** *(Selected: Full reorganization, Structured natural language, Modular)*


**[C]** Initial classification proposed a "reference" bucket for docs like jake-character.md and stress-testing.md, and a "planning" bucket for v1-implementation-plan.md.


**[U]** *(Corrected the classification)* No "reference" bucket. No "planning" bucket. Every document belongs in exactly one pipeline stage. Plans are OODA loop artifacts, not a permanent stage.

- jake-character.md → transcripts (design artifact from conceive)
- stress-testing.md → ADR (decision about testing approach)
- swiftui-persistence-*.md → ADR (architectural research)
- architecture-v1.md → docs (produced after writing code)
- v1-implementation-plan.md → transcripts (historical OODA artifact)


**[C]** Reclassified every document. The final pipeline:
```
docs/
├── pipeline.md                    # Overview + verification rules
├── 0-transcripts/                 # Raw design conversations + artifacts
├── 1-prd/                        # Product requirements
├── 2-spec/                       # Formal specifications (NEW)
│   ├── index.md                  # Traceability matrix
│   └── [16 module files]
├── 3-adr/                        # Architecture decision records
│   └── proposals/                # Research feeding into ADRs
└── 4-docs/                       # Post-implementation documentation
```

Stages 4-6 (code, tests, product) live in the main project structure (`Tavern/`), not in `docs/`.


---


## 16 Module Breakdown

*[T] The PRD has 40 total sections but 4 are context-only (§1 Executive Summary, §3 Problem Statement/Goals, §14 Open Items/TBD, §15 Day 1 Questions). The remaining 36 sections cluster naturally into 16 topical modules based on domain boundaries. Some modules cover multiple related PRD sections (e.g., `agents.md` covers §4.1-4.3 because they're all about agent types and states). One module (`view-architecture.md`) derives from the Reader rather than the PRD — it captures the dynamic view/tile system discussed in design transcripts that hasn't been promoted to PRD yet.*

**[C]** Spec modules with PRD traceability:

| Module | Prefix | PRD Sections | Code Mapping |
|--------|--------|-------------|-------------|
| `invariants.md` | REQ-INV | §2 | Cross-cutting |
| `agents.md` | REQ-AGT | §4.1-4.3 | Agents/, Coordination/ |
| `operating-modes.md` | REQ-OPM | §4.4, §5.2 | Chat/, UI/ |
| `doc-store.md` | REQ-DOC | §4.5, §6.6 | Persistence/ |
| `sandbox.md` | REQ-SBX | §4.6, §6.4 | Not yet implemented |
| `deterministic-shell.md` | REQ-DET | §4.7 | Commitments/ |
| `communication.md` | REQ-COM | §5.3, §5.5 | Chat/ |
| `spawning.md` | REQ-SPN | §6.2, §6.3, §7 | Naming/, AgentSpawner |
| `user-experience.md` | REQ-UX | §5.1, §5.4, §8 | Tavern/, UI/, Project/ |
| `view-architecture.md` | REQ-VIW | Reader §8 only | Not yet implemented |
| `system-architecture.md` | REQ-ARCH | §6.1 | TavernCore/ |
| `workflows.md` | REQ-WRK | §10, §11, §6.5 | Not yet implemented |
| `lifecycle.md` | REQ-LCM | §12, §13 | Partial |
| `observability.md` | REQ-OBS | §9, §16 | Logging/, Errors/ |
| `quality.md` | REQ-QA | §17, §19, §21 | Tests/ |
| `v1-scope.md` | REQ-V1 | §18, §20 | — |


---


## Verification & Incremental Flow

**[C]** Each pipeline stage can be verified against its upstream:

- **PRD ← Transcripts**: Reader covers all transcripts (existing `/audit-transcripts`)
- **Spec ← PRD**: Every PRD section appears in `index.md` matrix
- **ADR ← Spec**: Spec modules reference relevant ADRs
- **Code ← Spec**: Spec downstream references list code modules
- **Tests ← Spec**: Spec downstream references list test files

Incremental update flow: new design conversation → transcribe → update reader → update PRD if changed → update spec modules → update index.md → update/create ADRs if needed → downstream code/tests/docs.


---


## Future Pipeline Tooling

**[U]** Elaborate on some of those future commands, a bit.


**[C]** Four commands that fall naturally out of the pipeline structure:

**`/audit-spec`** — The spec counterpart to `/audit-transcripts`. Walks the PRD section by section, checks that `2-spec/index.md` maps each one to a module, then reads each module to verify the requirements actually exist (not just placeholders). Reports coverage gaps and status. Could also cross-check downstream references — "this spec module says code lives in `Agents/`, does that directory exist? Does it have tests?"

**`/fill-spec <module>`** — The heavy lifter. Takes a skeleton spec module, reads its upstream PRD sections and reader sections, and drafts concrete requirements with the `REQ-PREFIX-NNN` format. Wouldn't auto-complete — it would draft and then ask questions where the PRD is ambiguous or the reader has open questions. Basically the spec equivalent of `/conceive` but for requirements rather than design conversations.

**`/trace <REQ-ID>`** — Follow a single requirement through the pipeline. Given `REQ-AGT-003`, show: PRD source → spec text → ADR (if any) → code files → test files → status at each stage. Quick way to answer "is this requirement fully implemented and tested?"

**`/spec-status`** — Dashboard view. For each of the 16 modules: status (skeleton/partial/complete/verified), requirement count, how many are implemented, how many have tests. Basically `index.md` but computed live from the actual files rather than manually maintained.


---


## Beads Strategy

**[U]** Make some beads, one for audit-spec, trace and spec-status, as you specified them. For fill-spec, this sounds more like a one-time-ish prompt, rather than recurring. Create an epic that has the instructions you proposed in it about filling out spec modules. Then, create a bead for every spec module that needs attention, with a copy of instructions from the epic. Then, in the epic, leave notes to keep the epic open indefinitely, in case we expand to more modules, and that every time you add a bead to the epic, you must copy the instructions into the bead itself on how to fill the spec.


**[C]** Created the tracking structure:

- 3 standalone feature beads (p2) for the recurring commands: `/audit-spec`, `/trace`, `/spec-status`
- 1 epic (p1, stays open indefinitely) for filling spec modules, with full fill instructions in the description
- 16 child task beads under the epic — one per spec module, each containing a full copy of the fill instructions so it can be worked standalone
- 12 at p1 (implemented or core modules), 4 at p2 (unimplemented features)
- Epic notes: keep open indefinitely, always copy instructions into new children


___


**[S]** Key design decisions from this session:

1. **Every document belongs to exactly one pipeline stage** — No "reference" bucket, no "planning" bucket. Things are either transcript inputs, requirements, specs, architectural decisions, or post-code documentation. Plans are ephemeral OODA loop artifacts.

2. **Numbered directory stages** — `0-transcripts/` through `4-docs/` in `docs/`, with code/tests/product living in the main project structure. The numbering makes flow direction self-evident.

3. **Structured natural language specs, modular** — 16 modules with REQ-PREFIX-NNN requirement IDs, Mermaid diagrams where helpful, explicit upstream/downstream references. Readable by humans and parseable by agents.

4. **Traceability is the skeleton** — `index.md` maps every PRD section to spec modules. Each spec module traces back to PRD sections and forward to code/test directories. Coverage gaps are visible at a glance.

5. **Fill-spec is tracked work, not a command** — Unlike the recurring verification commands (audit-spec, trace, spec-status), filling specs is one-time per module. Tracked as an indefinite epic with per-module child beads, each self-contained with instructions.

6. **Verification at every stage boundary** — Each pipeline stage can be checked against its upstream. This enables incremental confidence: new design → transcript → PRD → spec → ADR → code → tests, with automated verification possible at each transition.
