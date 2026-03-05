# Session Management Refactor — Design & Implementation

**Date:** 2026-03-05
**Sessions:** 2 (first ran out of context, continued in second)
**Scope:** Session resume, ClodSession mechanism layer, file-system persistence, dead code cleanup, UDD consolidation direction

---

## The Problem

[U] We need to go deep on how session management vs servitor chats work, because our sessions keep getting broken. Gist is, we need to make sure that whenever you talk to a servitor, that we always do "the right thing" to restore the session as best as possible, and provide a seamless experience. Go get your groundings first.

[U] No, we need to talk this whole thing out in depth, just get oriented.

[U] Give me some diagrams explaining our current situation, especially showing where there's duplication, and give me good details on what is duplicated too.

[C] *Produced three Mermaid diagrams and a method-by-method duplication audit. Key findings: session resume was commented out everywhere (each message started a brand new Claude session), session mechanics were duplicated 6x across Jake, Mortal, and ClodSession, and servitor persistence was in UserDefaults (machine-local, no session history, no break sigils).*

---

## Two Prongs

[U] There's basically two prongs here. One is to talk out how to deduplicate and unfuck up this mess, and what we really need from the ClodSession vs we implement internally. The second is to talk about what "restore dynamics" means. There's a lifecycle in Claude for a session, and we need to take correct actions when a Claude session is no longer available, but the user is expecting a contiguous chat with the servitor, vs when the user indicates they want a new chat.

---

## Servitor = Policy, ClodSession = Mechanism

[U] Yes and no, a servitor Jake or other can do anything they can with a ClodSession, if it's supported, so ClodSessions need to support all the Claude features, and a servitor is basically an object containing the business logic of how that series of sessions gets used.

[U] The structure of servitors is meant to facilitate mapping app functionality into the ClodSession, such as how we compose the prompt, feeding in specific MCP servers as warranted, and so on. Right now we just need to support every feature from ClodSession, and map it into an app-specific way, but later, we will add further app functionality. For instance, the commitments system is business logic that will apply to mortal servitors, whereas drones and daemons will see other logic entirely.

[U] We may maintain our own storage of session history separate from the Claude JSONL, for instance, and at such time, we will need to populate the state of a servitor in multiple ways when we reinitialize a servitor into memory. Think about them as a bunch of objects persisted to storage and the manager classes are like CoreData managers in many ways. Right now we have more ephemeral servitors, because we haven't wired them up to any persistence per se, so we have to work on that better.

[C] *Synthesized the split:*

**Clearly ClodSession's job:**
- Build QueryOptions (system prompt, permissions, working dir, MCP servers)
- Set resume / handle resume failure
- Call messenger (query + queryStreaming)
- Persist session ID after response
- Reset conversation
- Map permission modes

**Clearly the servitor's job:**
- State machine (`_isCogitating` for Jake, `idle->working->waiting->done` for Mortal)
- Completion signal detection (Mortal only)
- Commitment verification (Mortal only)
- MCP server lifecycle (Jake only — but ClodSession already accepts MCP servers via config)
- System prompt content (each type has its own)

So Jake becomes: state management + MCP wiring + a `ClodSession` it delegates to. Mortal becomes: state machine + completion detection + commitments + a `ClodSession` it delegates to.

[C] The servitor decides *policy* (what to do when resume fails), and ClodSession provides *mechanism* (the ability to attempt resume, start fresh, persist IDs, etc.).

---

## Session States and Resume-with-Fallback

[U] Now, as for Claude states, what's the difference between expired and orphaned? Let's talk that out before we talk about desired behaviors.

[C] **Expired** and **orphaned** are actually the same thing from our perspective. The `ControlProtocolError.timeout` is the only signal we get, and it means the same thing: **this session ID is no longer resumable.**

So really, the Claude session states from our perspective are:
1. **None** — no session ID. First message will create one.
2. **Resumable** — session ID exists, server accepts resume. We only discover this by succeeding.
3. **Not resumable** — session ID exists, server rejects resume. We only discover this by failing.

We can't tell 2 from 3 without trying. There's no "ping" or "check session health" API. The only way to know is to attempt resume and see what happens.

___

[S] *This is the key insight that drives the resume-with-fallback pattern: try resume optimistically, catch the timeout, log the expired event, clear the session, retry fresh. No health checks, no proactive detection — just optimistic resume with graceful degradation.*

---

## Data Model: Servitor → Many Sessions

[U] Well, here's the data relationship: a servitor is one data instance that maps to many ordered sessions. The servitor has a conversation state that's the aggregate of all sessions. If a servitor has a session, it fails to start, then create a new session, that part is easy. We need to stub an intermediate step where we fill the new Claude session with info to help it resume and put a pin in it for this discussion. Don't let me leave without addressing it.

[U] If the user decides to "clear" the servitor chat, or start a new chat, then we insert our own break sigil into the storage locally, and then start a new session, cleanly, and go on.

[C] **The two "new session" triggers are different:**
1. **Infrastructure failure** (session expired/unreachable) — transparent recovery, user shouldn't care. Context injection needed so Claude isn't amnesiac. (Pinned for later.)
2. **User intent** (clear/new chat) — deliberate break, stored as a sigil, clean slate.

---

## Context Injection — Pinned for Future Design

[U] This is an open area for design, and as such, we need to create a bead and also put some notes in the specs and such.

[U] One idea is that we treat it like compaction, we do our own compaction, e.g. we run our own Haiku prompts on custom stuff, and provide that output to the new session, and then visually show this to the user.

[U] Another is that we somehow use the SDK to fill in all the messages as we've logged it into a new session, so that the new session has the same context as the previous.

[U] Another is that we give the servitor a "personhood card" that has all the details on what it's been doing and so on, and enable it to just pick up from where it left off. This last one might be most useful for drone or other background servitors.

[U] For now, let's just show the session break to the user and then start a new one, to keep it simple in the stub, so we can focus on other core things.

[C] *Three candidate approaches captured for future design (bead `jake-o9a1`):*
1. **Custom compaction** — Run Haiku on conversation history, produce summary, inject as context
2. **Message replay** — Use SDK to feed logged messages into new session for same context window
3. **Personhood card** — Persistent document describing servitor's work, state, decisions. Most useful for background agents (drones/daemons)

*These aren't mutually exclusive — different servitor types might use different strategies.*

---

## File-System Persistence

[U] Jake is just cogitating any time the app's just waiting for his response, that's it. Nothing fancy. Anyways, what about data persistence?

[C] *Identified the persistence gap:* The servitor's assignment, which sessions belong to which servitor in order, break sigils between user-initiated clears, any notion of "this servitor has had 3 sessions over its lifetime", the aggregate conversation state across sessions — none of these were persisted.

[U] We have a persistence layer, the file system, so a servitor can be a markdown file with an accompanying JSONL for logging things, and we can put them in `.tavern/servitors/` for the project.

[U] Each tavern has a Jake, naming is, if you did your research, distinct for a tavern, so we can use the names rather than UUIDs. This persistence layer needs to exist anyways, so we need to wire in the minimum capabilities we need from the file system driver to build this for now.

[C] *Proposed directory structure:*
```
.tavern/servitors/
├── jake/
│   ├── servitor.md          # Identity, config, current state (YAML frontmatter)
│   └── sessions.jsonl       # Ordered session log (IDs, breaks, metadata)
├── gandalf/
│   ├── servitor.md
│   └── sessions.jsonl
```

___

[S] *The format choices: YAML frontmatter for `servitor.md` (human-readable, matches existing doc conventions), JSONL for `sessions.jsonl` (append-only, one event per line, machine-parseable). Names as directory keys rather than UUIDs, since the NameGenerator enforces uniqueness within a project.*

---

## Plan Approval

[C] *Presented an 11-step plan covering: ServitorStore + data types, StreamEvent + ChatMessage types, MockMessenger stale-session support, ClodSession mechanism rewrite, Jake delegation, Mortal delegation, ChatTile session break handling, clear conversation break sigils, TavernProject + ClodSessionManager restoration, tests, cleanup.*

*The user approved the plan after correcting one minor point about Jake's cogitation state.*

---

## Implementation Notes

*The implementation spanned two sessions (first ran out of context). Key technical outcomes:*

- ClodSession consolidated all session plumbing into one 321-line file
- Jake went from ~200 lines of session mechanics to ~50 lines of delegation
- Mortal similarly reduced — kept only state machine, completion detection, commitments
- ServitorStore provides file-system persistence (414 lines, queue-protected)
- SessionStore stripped from ~260 lines to ~55 lines (just Jake history loading from Claude's native JSONL)
- `sessionId` added to Servitor protocol
- 21 new tests (8 ServitorStoreTests + 11 ClodSessionTests + 2 updated assertions)
- 34 files changed, all 632 unit + 28 integration tests pass

---

## UnixDirectoryDriver Consolidation — Next Direction

[U] Servitor store should be the same class as file system driver, and that driver class just implements a couple provider protocols, including this one. The reason why is we only want one object vending out actual objects from files, to prevent conflicts and stuff. Talk out the refactoring first, with me.

[C] *Identified the conflict: three separate file-touching objects (DocStore, ServitorStore, DocumentStore), each with their own FileManager and dispatch queue, no coordination between them.*

[U] Where is file system driver?

[C] *Found `UnixDirectoryDriver` — currently a tiny class that just opens a directory and returns a handle.*

[U] Unix directory driver should be the singular point that talks to the actual file system. It offers up a directory, that we use as a project and source for records with the project provider and other providers.

[C] *Proposed consolidation:*
```
UnixDirectoryDriver
  ├── ProjectProvider
  ├── ResourceProvider     (absorbs DocumentStore)
  ├── ServitorRecordProvider (absorbs ServitorStore)
  └── DocumentProvider     (absorbs DocStore)
```

[U] Commit what we have so far, then start this refactor in full. The Unix dir driver will vend a directory object. That object will implement all the provider protocols and be a central tracker to know which objects map to which files, to make sure that if multiple objects map to one file, we deal with concurrency issues. (If we even allow that.) Meanwhile, depending on our needs, we can either have that directory be a fully featured implementation, or just a delegate back to the Unix driver itself, where it's essentially currying a URL to a directory in every function call. This option here can be part of our design pattern language, which we should also document, that we use. It may be OK to have multiple objects independently handling files, because they never overlap, and this is better for threading performance, or it could be that they do overlap and we have to use the delegate pattern. For other providers, similar concerns may arise, such as connection pooling across multiple projects to a backend service. In sum, everything must go into UDD.

___

[S] *Two design patterns emerge for provider resource sharing:*

1. **Independent providers** — Each provider owns its own resource access (queue, FileManager, etc.). Acceptable when providers never overlap on the same resources. Better threading performance — no single bottleneck queue.

2. **Delegate-to-driver** — Provider delegates all resource access back to the driver, which centralizes concurrency control. The provider is essentially currying a context (directory URL, connection, etc.) into every function call. Required when multiple providers might touch the same underlying resource.

*The choice between these patterns should be documented as part of the project's design pattern language, applicable not just to file I/O but to any shared resource (connection pools, backend services, etc.).*

*The UDD consolidation is the next major refactoring bead.*
