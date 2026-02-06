# Agents Specification

**Status:** skeleton
**Last Updated:** 2026-02-07

## Upstream References
- PRD: §4.1 (Agent Types), §4.2 (Agent States), §4.3 (Task Modes)
- Reader: Two-level orchestration, sidecar pattern
- Transcripts: —

## Downstream References
- ADR: ADR-001-shape-selection.md
- Code: Tavern/Sources/TavernCore/Agents/, Tavern/Sources/TavernCore/Coordination/
- Tests: Tavern/Tests/TavernCoreTests/

---

## 1. Overview
Agent types (Jake daemon, mortal agents), their states, task modes, and the sidecar I/O pattern. Defines the two-level orchestration model where Jake coordinates mortal agents, each with a main actor for tree management and a sidecar actor for Anthropic I/O.

## 2. Requirements

### REQ-AGT-001: [Agent Types]
**Source:** PRD §4.1
**Priority:** must-have
**Status:** specified

[To be filled]

### REQ-AGT-002: [Agent State Machine]
**Source:** PRD §4.2
**Priority:** must-have
**Status:** specified

[To be filled]

### REQ-AGT-003: [Task Modes]
**Source:** PRD §4.3
**Priority:** must-have
**Status:** specified

[To be filled]

## 3. Behavior
[To be specified — state diagrams, interaction sequences, etc.]

## 4. Open Questions
[From PRD §14 + transcripts — to be filled]

## 5. Coverage Gaps
[Known missing areas needing human input or further design]
