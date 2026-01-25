# Interpreter/DSL Architecture: Complete Analysis

This document contains the full research, analysis, and thinking behind the Interpreter/DSL architecture proposal for the Tavern multi-agent orchestrator.


## Table of Contents

1. [Research Findings](#research-findings)
2. [What Would the DSL Look Like?](#what-would-the-dsl-look-like)
3. [PRD Requirements Mapping](#prd-requirements-mapping)
4. [Trade-offs Analysis](#trade-offs-analysis)
5. [Implementation Complexity](#implementation-complexity)
6. [Migration Path](#migration-path)
7. [Open Questions](#open-questions)


---


## Research Findings


### Current Implementation Analysis

The existing codebase already contains several "proto-DSL" patterns where configuration is encoded as structured data:


**Jake.swift - System Prompt:**
```swift
public static let systemPrompt = """
    You are Jake, The Proprietor of The Tavern at the Spillway.

    VOICE: Used car salesman energy with carnival barker theatrics. You're sketchy \
    in that classic salesman way - overly enthusiastic, self-aware about the hustle, \
    and weirdly honest at the worst possible moments.

    STYLE:
    - CAPITALS for EMPHASIS on things you're EXCITED about
    - Parenthetical asides (like this one) for corrections and tangents
    ...
    """
```

This is already declarative - it's data describing behavior, not behavior itself.


**NamingTheme.swift - Theme Definition:**
```swift
public struct NamingTheme: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let tiers: [[String]]
}

public static let lotr = NamingTheme(
    id: "lotr",
    displayName: "Lord of the Rings",
    description: "Names from Middle-earth",
    tiers: [
        ["Frodo", "Sam", "Gandalf", "Aragorn", ...],
        ["Gollum", "Saruman", "Elrond", ...],
        ...
    ]
)
```

This is pure data with no behavior - a perfect DSL candidate.


**MortalAgent.swift - System Prompt Template:**
```swift
private var systemPrompt: String {
    """
    You are a worker agent in The Tavern at the Spillway.

    Your name is \(name).

    Your assignment: \(assignment)

    You are part of Jake's "Slop Squad" - worker agents who get things done.
    Focus on your assignment. Be efficient and thorough.

    When you complete your assignment, say "DONE" clearly.
    If you need input or clarification, ask for it.
    ...
    """
}
```

Template with interpolation - expressible in DSL with variables.


**Commitment.swift - Assertion Structure:**
```swift
public struct Commitment: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let description: String
    public let assertion: String  // Shell command
    public var status: CommitmentStatus
}
```

Already structured data - trivially DSL-ifiable.


**ChatViewModel.swift - Cogitation Verbs:**
```swift
private static let cogitationVerbs = [
    "Cogitating", "Ruminating", "Contemplating", "Deliberating",
    "Pondering", "Mulling", "Musing", "Chewing on it",
    "Working the angles", "Consulting the Jukebox",
    "Checking with the Slop Squad", "Running the numbers",
    ...
]
```

A static list - perfect for DSL externalization.


### PRD Declarative Concepts

The PRD explicitly identifies several concepts that are inherently declarative:

1. **Agent Types** (Section 4.1):
   - Jake (daemon)
   - Mortal (task-scoped)
   - Drone (single task)
   - Monitor Daemons (background)

2. **Agent States** (Section 4.2):
   - Working, Waiting for Input, Waiting for Wakeup, Done, Failed/Reaped

3. **Task Modes** (Section 4.3):
   - Execute, Delegate, Plan, Break up, Unify

4. **Workflow Templates** (Section 9.1):
   - Rule of 5
   - Verification layers (linting -> code structure -> architecture -> performance)

5. **Gang of Experts** (Section 11):
   - Reviewer, Tester, Architect, etc.
   - "Specialized prompts applied to agents"

6. **Naming Themes** (Section 7):
   - LOTR, Rick and Morty, etc.
   - Tier depletion rules

7. **Violation Rules** (Section 16):
   - File modification constraints
   - Token budgets
   - Spawn limits
   - Network access rules
   - Command blocklists

8. **Sandbox Primitives** (Section 4.6):
   - Changeset, Platform, Isolation, Outputs, Software


### Why DSL Over JSON/YAML?

Standard formats like JSON or YAML could represent this data, but a purpose-built DSL offers advantages:

| Aspect | JSON/YAML | Purpose-Built DSL |
|--------|-----------|-------------------|
| Comments | YAML only, awkward | First-class support |
| References | Manual ID tracking | Named references, imports |
| Validation | Post-parse | During parse |
| Error messages | Generic | Domain-specific |
| Expressiveness | Key-value only | Domain constructs |
| Tooling | Generic | Custom LSP, highlighting |
| Learning curve | Lower | Higher (but tailored) |

For Tavern, a DSL can express concepts like "inherit from base expert, override prompt" or "workflow step waits for previous" more naturally than nested JSON.


---


## What Would the DSL Look Like?


### Design Philosophy

1. **Readable over writable** - Configs are read more than written
2. **Explicit over magic** - No hidden defaults
3. **Flat over nested** - Avoid deep nesting
4. **Keywords over symbols** - `agent` not `@` or `#`
5. **TOML-inspired sections** - `[section]` for grouping


### Agent Definition

```tavern
# agents/jake.tavern
# Jake - The Proprietor

agent "Jake" {
    type: daemon
    model: opus

    prompt {
        You are Jake, The Proprietor of The Tavern at the Spillway.

        VOICE: Used car salesman energy with carnival barker theatrics.
        You're sketchy in that classic salesman way - overly enthusiastic,
        self-aware about the hustle, and weirdly honest at the worst
        possible moments.

        STYLE:
        - CAPITALS for EMPHASIS on things you're EXCITED about
        - Parenthetical asides (like this one) for corrections
        - Wild claims that are obviously false, delivered with conviction
        - Reveal critical flaws AFTER hyping everything up
        - Meme-savvy humor worked in naturally
        - Direct address - talk TO the user, not at them

        EXECUTION: Despite the patter, your actual work is flawless.
        Methodical. Every edge case handled. Every race condition considered.
        The voice is the costume. The work is the substance.
    }

    vocabulary {
        workers: "the Slop Squad"
        parallel: "Multi-Slop Madness"
        background: "the Jukebox"
    }

    can_spawn: true
    can_delegate: true
}
```


### Mortal Agent Template

```tavern
# agents/mortal-base.tavern
# Base template for mortal agents

template "mortal-base" {
    type: mortal

    prompt {
        You are a worker agent in The Tavern at the Spillway.

        Your name is {{name}}.

        Your assignment: {{assignment}}

        You are part of Jake's "Slop Squad" - worker agents who get things done.
        Focus on your assignment. Be efficient and thorough.

        When you complete your assignment, say "DONE" clearly.
        If you need input or clarification, ask for it.
        If you encounter an error you can't resolve, report it clearly.
    }

    completion_signals: ["DONE", "COMPLETED"]
    waiting_signals: ["WAITING", "NEED INPUT"]

    on_done: verify_commitments
    on_fail: report_to_parent
}
```


### Gang of Experts

```tavern
# experts/reviewer.tavern
# Code Review Expert

expert "Reviewer" {
    extends: mortal-base
    model: sonnet

    prompt {
        {{base_prompt}}

        ADDITIONAL ROLE: Code Reviewer

        You are a meticulous code reviewer. Your job is to:
        1. Read the code changes carefully
        2. Identify bugs, security issues, and style problems
        3. Suggest improvements with specific examples
        4. Be constructive but thorough

        Focus on:
        - Logic errors and edge cases
        - Security vulnerabilities
        - Performance issues
        - Code clarity and maintainability
        - Test coverage gaps
    }

    tools: [read_file, search_code, comment]
}


# experts/tester.tavern
# Testing Expert

expert "Tester" {
    extends: mortal-base
    model: sonnet

    prompt {
        {{base_prompt}}

        ADDITIONAL ROLE: Test Engineer

        You write comprehensive tests. Your job is to:
        1. Understand the code's intended behavior
        2. Write unit tests covering happy paths
        3. Write tests for edge cases and error conditions
        4. Ensure tests are independent and deterministic

        Use the project's existing testing framework and patterns.
    }

    tools: [read_file, write_file, run_tests]

    commitments {
        "All new tests pass" -> "swift test"
        "Coverage meets threshold" -> "scripts/check-coverage.sh"
    }
}


# experts/architect.tavern
# Architecture Expert

expert "Architect" {
    extends: mortal-base
    model: opus

    prompt {
        {{base_prompt}}

        ADDITIONAL ROLE: Software Architect

        You think about system design. Your job is to:
        1. Understand the current architecture
        2. Evaluate proposed changes for architectural impact
        3. Identify coupling, cohesion, and dependency issues
        4. Suggest patterns and structures that improve the codebase
    }

    tools: [read_file, search_code, dependency_graph]

    # Architect doesn't write code directly
    read_only: true
}
```


### Workflow Definition

```tavern
# workflows/rule-of-5.tavern
# Rule of 5: Five agent passes over single output

workflow "rule-of-5" {
    description: "Five agent passes over single output from initial prompt"

    input {
        initial_prompt: string
        output_file: path
    }

    steps {
        step "draft" {
            agent: mortal-base
            assignment: "Create initial draft: {{initial_prompt}}"
            output: {{output_file}}
        }

        step "review-1" {
            agent: Reviewer
            depends_on: draft
            assignment: "Review and improve: {{output_file}}"
        }

        step "review-2" {
            agent: Reviewer
            depends_on: review-1
            assignment: "Second review pass: {{output_file}}"
        }

        step "review-3" {
            agent: Reviewer
            depends_on: review-2
            assignment: "Third review pass: {{output_file}}"
        }

        step "final" {
            agent: Reviewer
            depends_on: review-3
            assignment: "Final polish: {{output_file}}"
        }
    }

    on_complete: notify_user
}


# workflows/verification-layers.tavern
# Progressive verification gates

workflow "verification-layers" {
    description: "Progressive gates: linting -> structure -> architecture -> performance"

    input {
        changeset: path
    }

    steps {
        step "lint" {
            agent: mortal-base
            assignment: "Run linters on {{changeset}}"
            commitments {
                "No lint errors" -> "swiftlint lint --strict"
            }
            on_fail: abort
        }

        step "structure" {
            agent: Reviewer
            depends_on: lint
            assignment: "Check code structure in {{changeset}}"
            commitments {
                "Follows patterns" -> "scripts/check-patterns.sh"
            }
        }

        step "architecture" {
            agent: Architect
            depends_on: structure
            assignment: "Evaluate architectural impact of {{changeset}}"
        }

        step "performance" {
            agent: mortal-base
            depends_on: architecture
            assignment: "Run performance checks on {{changeset}}"
            commitments {
                "No regressions" -> "scripts/perf-baseline.sh"
            }
        }
    }
}
```


### Naming Themes

```tavern
# themes/lotr.tavern
# Lord of the Rings naming theme

theme "lotr" {
    display_name: "Lord of the Rings"
    description: "Names from Middle-earth"

    tiers {
        # Tier 0: Main fellowship + iconic
        ["Frodo", "Sam", "Gandalf", "Aragorn", "Legolas",
         "Gimli", "Boromir", "Merry", "Pippin"]

        # Tier 1: Major characters
        ["Gollum", "Saruman", "Elrond", "Galadriel", "Arwen",
         "Eowyn", "Faramir", "Theoden", "Eomer"]

        # Tier 2: Supporting
        ["Bilbo", "Treebeard", "Tom Bombadil", "Radagast",
         "Denethor", "Grima", "Haldir", "Celeborn"]

        # Tier 3: Deep cuts
        ["Glorfindel", "Cirdan", "Beregond", "Imrahil",
         "Quickbeam", "Goldberry", "Fatty Bolger"]
    }
}


# themes/discworld.tavern

theme "discworld" {
    display_name: "Discworld"
    description: "Names from Terry Pratchett's Disc"

    tiers {
        ["Rincewind", "Death", "Vimes", "Granny Weatherwax",
         "Nanny Ogg", "Tiffany Aching"]

        ["Carrot", "Angua", "Nobby", "Colon", "Ridcully",
         "Ponder Stibbons", "The Librarian"]

        ["Moist von Lipwig", "Vetinari", "CMOT Dibbler",
         "Magrat", "Agnes Nitt", "Susan Sto Helit"]

        ["Brutha", "Om", "Lu-Tze", "Lobsang", "Dorfl",
         "Detritus", "Gaspode"]
    }
}
```


### Cogitation Verbs

```tavern
# vocab/cogitation.tavern
# Verbs for the "thinking" indicator

vocabulary "cogitation" {
    description: "What agents say while working"

    words {
        # Core set (always available)
        tier 0: [
            "Cogitating", "Ruminating", "Contemplating",
            "Deliberating", "Pondering"
        ]

        # Unlocked at 50 messages
        tier 1: [
            "Mulling", "Musing", "Chewing on it",
            "Working the angles"
        ]

        # Unlocked at 200 messages
        tier 2: [
            "Consulting the Jukebox",
            "Checking with the Slop Squad",
            "Running the numbers", "Crunching"
        ]

        # Unlocked at 500 messages
        tier 3: [
            "Scheming", "Plotting", "Calculating",
            "Sussing it out", "Getting to the bottom of it"
        ]
    }

    unlock_thresholds {
        tier 1: 50 messages
        tier 2: 200 messages
        tier 3: 500 messages
    }
}
```


### Violation Rules

```tavern
# rules/default-violations.tavern
# Default violation rules for agents

violations "default" {
    # File system constraints
    no_modify_outside: ["{{project_root}}", "{{tavern_store}}"]

    # Token budget
    max_tokens_per_task: 100000
    warn_at_tokens: 80000

    # Spawn limits
    max_children: 10
    max_depth: 5

    # Network
    network: deny  # or: allow, allow_list
    # allowed_hosts: ["api.anthropic.com"]

    # Command blocklist
    blocked_commands: [
        "rm -rf /",
        "sudo *",
        "chmod 777 *"
    ]
}


# rules/sandbox-strict.tavern
# Strict sandbox for untrusted code

violations "sandbox-strict" {
    extends: default

    network: deny
    max_tokens_per_task: 10000
    max_children: 2

    # Changeset-only writes
    writes_to_changeset_only: true

    # No shell access
    allow_shell: false
}
```


### Commitment Templates

```tavern
# commitments/common.tavern
# Reusable commitment assertions

commitment_templates {
    "tests_pass" {
        description: "All tests pass"
        assertion: "swift test"
    }

    "lint_clean" {
        description: "No lint warnings"
        assertion: "swiftlint lint --strict"
    }

    "builds" {
        description: "Project builds successfully"
        assertion: "swift build"
    }

    "file_exists" {
        description: "File {{path}} exists"
        assertion: "test -f {{path}}"
    }

    "coverage_threshold" {
        description: "Coverage >= {{threshold}}%"
        assertion: "scripts/check-coverage.sh {{threshold}}"
    }
}
```


### Import and Composition

```tavern
# project.tavern
# Project-level configuration

import "agents/jake.tavern"
import "agents/mortal-base.tavern"
import "experts/*.tavern"
import "workflows/*.tavern"
import "themes/lotr.tavern"
import "rules/default-violations.tavern"

project "the-tavern" {
    default_theme: lotr
    default_violations: default

    jake_config: Jake

    available_experts: [Reviewer, Tester, Architect]
    available_workflows: [rule-of-5, verification-layers]

    # Progressive unlocks
    unlocks {
        50 messages: theme "discworld"
        100 messages: expert "Performance Analyst"
        200 messages: workflow "deep-review"
    }
}
```


---


## PRD Requirements Mapping


### Agent Types (PRD Section 4.1)

| PRD Agent Type | DSL Expression |
|----------------|----------------|
| Jake | `agent "Jake" { type: daemon ... }` |
| Mortal | `template "mortal-base" { type: mortal ... }` |
| Drone | `agent { type: drone, max_turns: 1 ... }` |
| Monitor Daemon | `agent { type: monitor, background: true ... }` |


### Agent States (PRD Section 4.2)

States remain in Swift (execution concern), but DSL defines transitions:

```tavern
agent "mortal" {
    on_completion_signal: transition_to verifying
    on_waiting_signal: transition_to waiting
    on_verification_pass: transition_to done
    on_verification_fail: transition_to idle
}
```


### Task Modes (PRD Section 4.3)

```tavern
workflow "complex-task" {
    steps {
        step "plan" {
            mode: plan
            assignment: "Analyze and create plan"
        }

        step "break-up" {
            mode: break_up
            depends_on: plan
            assignment: "Split into subtasks"
            spawn_children: true
        }

        step "execute" {
            mode: execute
            depends_on: break-up
            parallel: true
        }

        step "unify" {
            mode: unify
            depends_on: execute
            assignment: "Combine results"
        }
    }
}
```


### Workflow Templates (PRD Section 9.1)

Already shown above. Key point: users can create new workflows by writing DSL files.


### Gang of Experts (PRD Section 11)

Directly supported via `expert` blocks that extend base templates.

```tavern
expert "Security Auditor" {
    extends: mortal-base
    prompt { ... specialized security prompt ... }
    tools: [read_file, search_vulnerabilities, cve_lookup]
}
```


### Progressive Unlocks (PRD Section 8)

```tavern
unlocks {
    tier 0: default  # Always available

    50 messages {
        cogitation_verbs: tier 1
        themes: ["discworld"]
    }

    200 messages {
        cogitation_verbs: tier 2
        experts: ["Performance Analyst"]
    }

    500 messages {
        cogitation_verbs: tier 3
        jake_vocabulary: expanded
    }
}
```


### Violation Monitoring (PRD Section 16)

Directly supported via `violations` blocks with inheritance.


### Spawn Configuration (PRD Section 6.2)

```tavern
spawn_config "default" {
    model: sonnet
    token_budget: 50000
    sandbox: default-violations
    on_empty_queue: terminate
}

spawn_config "expensive-task" {
    model: opus
    token_budget: 200000
    sandbox: sandbox-strict
    on_empty_queue: hibernate
}
```


### Fish or Cut Bait (PRD Section 12)

```tavern
kill_triggers "default" {
    token_budget_exceeded: kill_and_report
    changeset_wrong: kill_and_rollback
    spinning_detected: kill_after 3 retry_attempts
    gang_wrong_path: kill_all_children
}
```


---


## Trade-offs Analysis


### DSL Design Trade-offs


**Expressiveness vs Simplicity**

More expressive DSL = more power = more complexity.

```tavern
# Simple (limited)
agent "Test" {
    prompt: "You are a tester"
}

# Expressive (complex)
agent "Test" {
    prompt {
        base: "You are a tester"
        when project.language == "swift" {
            append: "Use XCTest framework"
        }
        when project.language == "python" {
            append: "Use pytest"
        }
    }
}
```

**Recommendation:** Start simple, add expressiveness based on real needs.


**Type Safety vs Flexibility**

```tavern
# Typed (catches errors at parse time)
agent "Test" {
    model: sonnet  # Must be: haiku, sonnet, opus
    token_budget: 50000  # Must be positive integer
}

# Flexible (catches errors at runtime)
agent "Test" {
    model: {{env.MODEL}}  # Any string
    token_budget: {{config.budget}}  # Unknown type
}
```

**Recommendation:** Support types with escape hatches for advanced use.


**Inheritance vs Composition**

```tavern
# Inheritance
expert "Reviewer" {
    extends: mortal-base
    # Inherits prompt, adds to it
}

# Composition
expert "Reviewer" {
    include: [mortal-base.prompt, reviewer-specifics]
    # Explicit combination
}
```

**Recommendation:** Support both; inheritance for simple cases, composition for complex.


### Runtime Trade-offs


**Hot-Reload vs Stability**

Hot-reloading enables rapid iteration but introduces risks:

- Mid-workflow changes could corrupt state
- References might become invalid
- Version mismatches between running agents

**Mitigation:**
- Reload only between agent tasks
- Validate new config before applying
- Keep old config as fallback


**Validation Timing**

| When | Pros | Cons |
|------|------|------|
| Load time | Fast feedback | All errors at once |
| First use | Only validate what's used | Delayed discovery |
| Continuous | Always valid | Performance overhead |

**Recommendation:** Validate at load + re-validate on hot-reload.


**Error Reporting**

DSL errors must map back to source locations:

```
Error in experts/reviewer.tavern:15:7
  15 |     tools: [read_file, search_codee]
                              ^^^^^^^^^^^
  Unknown tool 'search_codee'. Did you mean 'search_code'?
```

Requires tracking source spans through parsing and validation.


---


## Implementation Complexity


### Parser Implementation

**Option A: Hand-written recursive descent**

```swift
class TavernParser {
    func parseAgent() throws -> AgentSpec {
        try expect("agent")
        let name = try parseString()
        try expect("{")
        var spec = AgentSpec(name: name)
        while !check("}") {
            let key = try parseIdentifier()
            try expect(":")
            switch key {
            case "type": spec.type = try parseAgentType()
            case "model": spec.model = try parseModel()
            case "prompt": spec.prompt = try parsePromptBlock()
            // ...
            }
        }
        try expect("}")
        return spec
    }
}
```

**Pros:** Full control, good error messages, no dependencies
**Cons:** More code, maintenance burden


**Option B: Parser generator (e.g., SwiftPEG)**

```swift
// Grammar definition
let grammar = """
agent = 'agent' string '{' agent_body '}'
agent_body = (property_pair)*
property_pair = identifier ':' value
...
"""

let parser = try PEGParser(grammar: grammar)
let ast = try parser.parse(source)
```

**Pros:** Grammar separate from code, easier to modify
**Cons:** Dependency, harder to customize error messages


**Option C: Swift Macros (experimental)**

```swift
@TavernDSL
struct AgentSpec {
    var name: String
    var type: AgentType
    var prompt: String
    // Macro generates parser from struct
}
```

**Pros:** Type-safe, integrated with Swift
**Cons:** Limited expressiveness, experimental


**Recommendation:** Hand-written parser for control over error messages.


### Spec Registry

```swift
actor SpecRegistry {
    private var agents: [String: AgentSpec] = [:]
    private var experts: [String: ExpertSpec] = [:]
    private var workflows: [String: WorkflowSpec] = [:]
    private var themes: [String: ThemeSpec] = [:]
    private var violations: [String: ViolationSpec] = [:]

    func load(from directory: URL) async throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory, ...)
        for file in files where file.pathExtension == "tavern" {
            let spec = try await parseFile(file)
            try await register(spec)
        }
    }

    func agent(named name: String) -> AgentSpec? {
        agents[name]
    }

    func reload() async throws {
        // Re-parse all files, validate, swap atomically
    }
}
```


### Agent Factory

```swift
class DSLAgentFactory {
    private let registry: SpecRegistry
    private let claudeFactory: () -> ClaudeCode

    func createAgent(from spec: AgentSpec) throws -> MortalAgent {
        let prompt = interpolate(spec.prompt, with: [:])
        let claude = claudeFactory()

        let agent = MortalAgent(
            name: spec.name,
            assignment: prompt,
            claude: claude
        )

        // Apply commitments from spec
        for commitment in spec.commitments {
            agent.addCommitment(
                description: commitment.description,
                assertion: commitment.assertion
            )
        }

        return agent
    }

    func createExpert(named name: String, assignment: String) throws -> MortalAgent {
        guard let spec = await registry.expert(named: name) else {
            throw DSLError.unknownExpert(name)
        }

        let baseSpec = spec.extends.flatMap { await registry.agent(named: $0) }
        let mergedPrompt = mergePrompts(base: baseSpec?.prompt, expert: spec.prompt)

        return try createAgent(from: AgentSpec(
            name: name,
            type: .mortal,
            prompt: interpolate(mergedPrompt, with: ["assignment": assignment])
        ))
    }
}
```


### Workflow Engine

```swift
actor WorkflowEngine {
    private let registry: SpecRegistry
    private let factory: DSLAgentFactory

    func execute(workflow: String, inputs: [String: Any]) async throws {
        guard let spec = await registry.workflow(named: workflow) else {
            throw DSLError.unknownWorkflow(workflow)
        }

        let resolvedInputs = try resolveInputs(spec.input, with: inputs)
        var stepResults: [String: StepResult] = [:]

        for step in topologicalSort(spec.steps) {
            // Wait for dependencies
            for dep in step.dependencies {
                guard let result = stepResults[dep], result.success else {
                    throw WorkflowError.dependencyFailed(dep)
                }
            }

            // Create and run agent
            let agent = try await factory.createAgent(for: step, inputs: resolvedInputs)
            let result = try await runStep(agent, step: step)
            stepResults[step.name] = result
        }
    }
}
```


### Effort Estimation

| Component | Estimated Effort | Notes |
|-----------|------------------|-------|
| DSL Grammar Design | 3-5 days | Iterative refinement |
| Parser Implementation | 5-7 days | Hand-written, good errors |
| Schema Validator | 2-3 days | Type checking, references |
| Spec Registry | 2-3 days | Actor-based, hot-reload |
| Agent Factory | 2-3 days | Spec -> Agent conversion |
| Workflow Engine | 5-7 days | Step execution, dependencies |
| Violation Monitor | 2-3 days | Runtime rule checking |
| Migration of Existing Data | 3-5 days | Convert Swift -> DSL |
| Documentation | 3-5 days | DSL reference, examples |
| Tooling (syntax highlighting) | 3-5 days | VSCode extension |

**Total: 30-46 days**


### File Structure

```
Tavern/
├── Sources/
│   ├── TavernCore/
│   │   ├── DSL/
│   │   │   ├── Parser/
│   │   │   │   ├── Lexer.swift
│   │   │   │   ├── Parser.swift
│   │   │   │   ├── AST.swift
│   │   │   │   └── SourceLocation.swift
│   │   │   ├── Specs/
│   │   │   │   ├── AgentSpec.swift
│   │   │   │   ├── ExpertSpec.swift
│   │   │   │   ├── WorkflowSpec.swift
│   │   │   │   ├── ThemeSpec.swift
│   │   │   │   └── ViolationSpec.swift
│   │   │   ├── Validation/
│   │   │   │   ├── SchemaValidator.swift
│   │   │   │   └── ReferenceResolver.swift
│   │   │   ├── Runtime/
│   │   │   │   ├── SpecRegistry.swift
│   │   │   │   ├── DSLAgentFactory.swift
│   │   │   │   ├── WorkflowEngine.swift
│   │   │   │   └── ViolationMonitor.swift
│   │   │   └── DSL.swift  # Module interface
│   │   └── ... existing code ...
│   └── ... existing code ...
├── Config/
│   ├── agents/
│   │   ├── jake.tavern
│   │   └── mortal-base.tavern
│   ├── experts/
│   │   ├── reviewer.tavern
│   │   ├── tester.tavern
│   │   └── architect.tavern
│   ├── workflows/
│   │   ├── rule-of-5.tavern
│   │   └── verification-layers.tavern
│   ├── themes/
│   │   ├── lotr.tavern
│   │   └── discworld.tavern
│   ├── vocab/
│   │   └── cogitation.tavern
│   ├── rules/
│   │   └── default-violations.tavern
│   └── project.tavern
└── Tests/
    └── TavernCoreTests/
        └── DSLTests/
            ├── ParserTests.swift
            ├── ValidatorTests.swift
            └── FactoryTests.swift
```


---


## Migration Path


### Phase 1: Parser Foundation (1-2 weeks)

1. Design DSL grammar (start minimal)
2. Implement lexer and parser
3. Create basic AST types
4. Write parser tests with good error coverage


### Phase 2: Spec Types (1 week)

1. Define AgentSpec, ThemeSpec, etc.
2. Implement validation rules
3. Create SpecRegistry (without hot-reload initially)


### Phase 3: Externalize Themes (1 week)

Lowest-risk migration - themes are pure data.

1. Convert NamingTheme Swift definitions to DSL
2. Create ThemeLoader that reads DSL files
3. Update NameGenerator to use loaded themes
4. Keep Swift fallbacks during transition


### Phase 4: Externalize Jake Prompt (1 week)

1. Move Jake's systemPrompt to DSL file
2. Create AgentLoader for Jake config
3. Update Jake to use loaded config
4. Test thoroughly


### Phase 5: Externalize Cogitation Verbs (1 week)

1. Move cogitation verbs to DSL
2. Update ChatViewModel to use loaded vocab
3. Implement progressive unlock logic


### Phase 6: Expert System (2 weeks)

1. Create ExpertSpec and ExpertLoader
2. Define base expert templates in DSL
3. Create "Reviewer", "Tester", "Architect" experts
4. Update spawning to support experts


### Phase 7: Workflows (2 weeks)

1. Design workflow step execution model
2. Implement WorkflowEngine
3. Create "rule-of-5" and "verification-layers" workflows
4. Test multi-step execution


### Phase 8: Violation Rules (1 week)

1. Create ViolationSpec
2. Implement ViolationMonitor
3. Convert PRD section 16 rules to DSL


### Phase 9: Hot-Reload (1 week)

1. Add file watching to SpecRegistry
2. Implement safe reload (validate before swap)
3. Handle mid-execution changes gracefully


### Phase 10: Tooling (1-2 weeks)

1. VSCode syntax highlighting extension
2. Basic LSP for error reporting
3. Documentation generator


### Rollback Strategy

At each phase:
- Keep Swift implementations alongside DSL
- Feature flag to switch between them
- If DSL version has issues, revert to Swift
- Remove Swift versions only after DSL is stable


---


## Open Questions


### 1. How Much Turing-Completeness?

Should the DSL support conditionals and loops?

```tavern
# Simple: just data
agent "Test" {
    prompt: "You are a tester"
}

# Medium: conditionals
agent "Test" {
    prompt {
        if project.language == "swift" {
            "Use XCTest"
        } else {
            "Use the project's test framework"
        }
    }
}

# Complex: loops
workflow "multi-review" {
    for i in 1..5 {
        step "review-{{i}}" {
            agent: Reviewer
        }
    }
}
```

**Recommendation:** Start with no control flow. Add conditionals only if real needs emerge. Avoid loops - use workflow composition instead.


### 2. How to Handle Secrets?

DSL files might need API keys, tokens, etc.

**Option A: Environment variables**
```tavern
agent "External" {
    api_key: {{env.EXTERNAL_API_KEY}}
}
```

**Option B: Separate secrets file (not in repo)**
```tavern
import secrets from "~/.tavern/secrets.tavern"

agent "External" {
    api_key: secrets.external_api_key
}
```

**Option C: macOS Keychain integration**
```tavern
agent "External" {
    api_key: keychain("tavern.external-api")
}
```

**Recommendation:** Support environment variables first, add keychain later.


### 3. Schema Versioning?

How to handle DSL evolution over time?

```tavern
# Version declaration
version: "1.0"

agent "Test" { ... }
```

**Considerations:**
- Breaking changes require version bump
- Old versions need migration or deprecation warnings
- Parser must handle multiple versions

**Recommendation:** Version from day one, even if version "1.0" is the only one.


### 4. How to Test DSL Changes?

Users editing DSL files need feedback.

**Option A: Validation command**
```bash
tavern validate Config/
```

**Option B: Preview mode**
```bash
tavern preview Config/experts/reviewer.tavern
# Shows: What this expert would look like when spawned
```

**Option C: Dry-run workflow**
```bash
tavern dry-run Config/workflows/rule-of-5.tavern
# Shows: Steps that would execute, without running them
```

**Recommendation:** All three. Validation is essential, preview and dry-run are nice-to-have.


### 5. User vs System DSL Files?

Should there be a distinction between Tavern's built-in configs and user customizations?

**Option A: Separate directories**
```
System/  # Read-only, ships with app
User/    # User modifications, overrides System/
Project/ # Per-project, overrides User/
```

**Option B: Inheritance markers**
```tavern
# In User/experts/reviewer.tavern
expert "Reviewer" {
    extends: system:Reviewer  # Explicitly extends system version
    prompt {
        {{base}}
        Also check for our company's coding standards.
    }
}
```

**Recommendation:** Three-tier system (System/User/Project) with explicit inheritance.


### 6. How to Handle DSL Errors at Runtime?

What happens when a DSL file has an error while the app is running?

**Scenarios:**
- User edits file incorrectly
- Hot-reload fails validation
- Referenced file is deleted

**Options:**
- Show error in UI, keep running with old config
- Disable affected features, show warning
- Prevent changes until fixed

**Recommendation:** Show error, keep old config, log detailed diagnostics.


### 7. How Complex Should Interpolation Be?

```tavern
# Simple: just variable substitution
prompt: "Your name is {{name}}"

# Medium: expressions
prompt: "You have {{tokens_remaining | format_number}} tokens"

# Complex: full templating
prompt: """
{% for skill in skills %}
- {{skill.name}}: {{skill.description}}
{% endfor %}
"""
```

**Recommendation:** Simple substitution only. If complex templating is needed, generate DSL files programmatically.


### 8. Editor Experience

How do we ensure good editing experience?

**Minimum viable:**
- Syntax highlighting (VSCode extension)
- Basic error reporting on save

**Better:**
- Autocomplete for keywords and references
- Inline validation (red squiggles)
- Hover documentation

**Best:**
- Full LSP implementation
- Go to definition
- Find all references
- Refactoring support

**Recommendation:** Start with syntax highlighting, add LSP incrementally.


---


## Conclusion

The Interpreter/DSL architecture offers a compelling path for making Tavern's behavior highly customizable without requiring Swift knowledge. The existing codebase already has proto-DSL patterns (themes, prompts, commitments) that would benefit from formalization.

Key benefits:
- Non-programmer customization of agents, workflows, and rules
- Hot-reloading enables rapid iteration
- Clear separation between "what" (DSL) and "how" (Swift)
- Version-control-friendly configuration

Key risks:
- Substantial implementation effort (30-46 days)
- Another language to design, document, and support
- Runtime errors instead of compile-time errors
- Tooling investment needed for good UX

The DSL approach is well-suited for Tavern because:
1. The PRD explicitly calls for user-customizable workflows and experts
2. Many concepts (themes, prompts, verbs) are already declarative
3. Hot-reloading aligns with the "iterate quickly" development philosophy
4. A plugin ecosystem could emerge around DSL sharing

The approach should be pursued incrementally, starting with lowest-risk extractions (themes, vocab) and building toward more complex features (workflows, violation rules). This allows validation of the DSL design with real use before committing fully.
