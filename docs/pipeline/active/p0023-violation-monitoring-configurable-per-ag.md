---
id: p0023
slug: violation-monitoring-configurable-per-ag
title: "Violation monitoring — configurable per-agent rules and enforcement"
phase: 1-design
gate: pending
priority: 3
source-bead: jake-2ni
child-beads: []
blocked-by: []
pipeline-branch: null
created: 2026-03-07
updated: 2026-03-07
assigned-agent: null
---

# Violation monitoring — configurable per-agent rules and enforcement

## Brief
> Migrated from bead jake-2ni (feature, priority 3). Stub — needs design before implementation.

## Status
| Phase | Gate | State |
|-------|------|-------|
| 1. Design | Gate 1: Human Approval | **STUB** |
| 2. Breakdown | Gate 2: Summary Approval | Waiting |
| 3. Execution | Gate 3: Self-Review + Scope Check | Waiting |
| 4. Verification | Post-work Review | Waiting |

**Next action:** Assign design agent to research and develop this stub.

## Stub
DISCUSSION STARTING POINT — not a final task. Discuss with user before promoting to real work.

Dynamic violation list configurable per-project or per-agent. Examples: modifying files outside designated directories, exceeding token budgets, spawning more than N children, accessing network when disallowed, running commands on blocklist. When detected: log, notify parent/user, optionally pause/reap/warn.

Sources: PRD section 16 (Violation Monitoring).

Key questions: How are rules specified (config file, code, both)? Real-time monitoring or post-hoc? What is the enforcement mechanism — hooks, sandbox, or agent-level checks? Agents cannot modify their own violation rules — how is this enforced?

## Design Log

## Design Statements

## Work Breakdown Plan

## Verification Results

## Agent Context
### Relevant Specs
### Relevant ADRs
### Key Code
### Distilled Instructions

## Child Beads

## Generated Stubs
