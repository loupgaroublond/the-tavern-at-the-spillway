# The Tavern at the Spillway

## What This Is

A multi-agent orchestrator for macOS. Jake is the top-level coordinating agent — The Proprietor. He talks weird, works perfect.

**Tech Stack:** Swift 6, SwiftUI, macOS 13+, ClaudeCodeSDK (local fork), XcodeGen, SPM


## Project Structure

```
the-tavern-at-the-spillway/
├── clean.do                         # Project-wide clean (redo)
├── Tavern/                          # Main Swift package
│   ├── Package.swift                # SPM manifest
│   ├── project.yml                  # XcodeGen config
│   ├── *.do                         # redo build scripts (build, run, test, etc.)
│   ├── LocalPackages/ClaudeCodeSDK/ # Forked SDK (JSON fix)
│   ├── Sources/
│   │   ├── Tavern/                  # App target (SwiftUI)
│   │   │   ├── TavernApp.swift      # Entry point
│   │   │   └── Views/               # SwiftUI views
│   │   └── TavernCore/              # Framework target
│   │       ├── Agents/              # Jake.swift, MortalAgent.swift
│   │       ├── Chat/                # ChatViewModel, ChatMessage
│   │       ├── Coordination/        # TavernCoordinator, AgentSpawner
│   │       ├── Commitments/         # Commitment verification
│   │       ├── Persistence/         # DocStore, SessionStore
│   │       └── Registry/            # AgentRegistry
│   └── Tests/
├── docs/
│   ├── architecture-v1.md           # Architecture guide
│   └── seed-design/                 # Design transcripts
└── scripts/
    └── loc.sh                       # Line count
```


## Build Commands (redo)

```bash
# From project root
redo clean                    # Remove all build artifacts (project-wide)
redo Tavern/run               # Build + kill existing + launch app
redo Tavern/build             # Build only (auto-runs xcodegen if needed)
redo Tavern/test              # Run all tests
redo Tavern/test-core         # TavernCoreTests only
redo Tavern/test-integration  # TavernTests only
redo Tavern/stop              # Stop running instances
redo Tavern/xcodegen          # Regenerate Xcode project
```

Build output: `~/.local/builds/tavern` (avoids iCloud interference)


## After Changing project.yml

```bash
cd Tavern
redo xcodegen         # Or: xcodegen generate
redo build
```


## Current State

**Working:**
- Jake responds using `.json` format (SDK bug fixed via local fork)
- Session persistence via UserDefaults (survives restart)
- Agent spawning with themed names + UI (toolbar + button)
- Content block rendering infrastructure (MessageType enum)
- 173 tests passing

**Not Implemented:**
- Project root selection (Jake works from cwd)
- Real verification logic (commitments use mock)
- Background agent execution
- Agent-to-agent communication
- Streaming responses (batch only)


## Key Files

| File | Purpose |
|------|---------|
| `Sources/TavernCore/Agents/Jake.swift` | Main agent |
| `Sources/TavernCore/Persistence/SessionStore.swift` | Session IDs (UserDefaults) |
| `Sources/TavernCore/Errors/TavernErrorMessages.swift` | Error mapping |
| `LocalPackages/ClaudeCodeSDK/` | Forked SDK |
| `docs/architecture-v1.md` | Architecture |


## Debugging

Logs use `os.log` with subsystem `com.tavern.spillway`.

**Console.app:**
1. Filter by `subsystem:com.tavern.spillway`
2. Category filters: `category:agents`, `category:chat`, `category:coordination`, `category:claude`

**Terminal:**
```bash
log stream --predicate 'subsystem == "com.tavern.spillway"' --level debug
```

**Diagnosing issues:**
1. Reproduce with app running
2. Check logs for `.error` level entries
3. Trace state transitions leading to the error
4. API call parameters and responses should be logged


## Seed Design Interview Process

Design discussions use a formalized interview methodology:

1. **Continuous Interview** — Ask questions to understand user's vision; keep asking rather than assuming

2. **Two Input Streams:**
   - User describes concepts in general strokes
   - Line-by-line walkthrough of reference materials

3. **Transcript Notation:**
   - **[U]** = User's words (high fidelity, like a magazine interview)
   - **[C]** = Claude's responses
   - **[T]** = Claude's thinking (italics, when it adds understanding)
   - **[S]** = Synthesis (after `___` divider, when new whole ideas emerge)

4. **Transcribe-and-Commit** — `/commit` updates `docs/seed-design/transcript_*.md`

**Why this exists:**
- Context continuity after compaction
- Multi-session design spanning real-world days
- High fidelity to user's concept, not generic best practices
- Prevents assumption drift — actual dialogue preserved
- Documentation artifact showing not just what, but WHY

**Key rule:** When new principles emerge during implementation, transcribe and commit to preserve design rationale.

**Files:** `docs/seed-design/transcript_*.md`


## Design Principles

1. **Informative Error Principle** — Errors must be specific and actionable
2. **Sum Type Error Design** — Enumerate all failure modes upfront via GADTs/sum types; forces comprehensive handling at design time
3. **Instrumentation Principle** — Logs must diagnose issues without screenshots
4. **Autonomous Testing Principle** — Tests run without human interaction
5. **App Restart Workflow** — After rebuilding, kill and relaunch the app for testing (use `redo run`)


## Honor System

Claude must adhere to development standards:
- All new code includes logging via `TavernLogger`
- Every feature requires tests
- No silent failures — every error logged with context


## Known Issue: iCloud Corrupts Xcode Projects

The project is in iCloud-synced `~/Documents`. Running `xcodegen generate` while iCloud syncs can create corrupted numbered copies (`Tavern 5.xcodeproj`). Root cause: `brctl status` shows `.build/` and `.git/` being actively synced; `com.apple.fileprovider.fpfs#P` xattrs confirm iCloud created the copies.

**Workaround:**
```bash
cd Tavern
rm -rf "Tavern"*.xcodeproj
redo xcodegen
```

**Permanent fix options:**
1. Move project to non-synced location (`~/Developer/`, `~/.local/projects/`)
2. Rename `.xcodeproj` to `.xcodeproj.nosync` and symlink
3. Use `xattr` to exclude from sync

Derived data already builds to `~/.local/builds/tavern` to avoid code signing issues.


---

## Jake: The Character

Jake is the top-level coordinating agent — The Proprietor. Full character specification is in [`docs/jake-character.md`](docs/jake-character.md).

**Quick summary:** Used car salesman energy, carnival barker enthusiasm, CAPITALS for EMPHASIS, reveals flaws AFTER the hype, sketchy-but-warm. The voice is the costume; the work is flawless.
