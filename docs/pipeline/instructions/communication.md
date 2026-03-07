# Communication Instructions

_Sources: 009-communication, 022-chat-discussions, ADR-008_

Load alongside `core.md` for work on messaging, bubbling, chat, inter-agent communication, or notification routing.

---

## Communication Model (REQ-COM)

### Bubbling (REQ-COM-001)
- Messages bubble up from children to parents through the servitor tree.
- Each level can filter, aggregate, or pass through.
- High-priority messages bypass intermediate levels.
- The user sees only what reaches the top (or what they explicitly focus on).

### Message Types (REQ-COM-002)
- Status updates (progress, completion)
- Questions (blocking vs non-blocking)
- Errors and failures
- Results and artifacts
- Patter (coordination messages between agents)

### Question Triage (REQ-COM-003)
- Questions classified by: urgency (blocking/non-blocking), type (clarification/approval/information), source (agent/system).
- Blocking questions: agent cannot proceed without answer. Surface immediately.
- Non-blocking questions: queue and batch.
- Multiple agents' questions can be collected and presented together.

### Notification Routing (REQ-COM-004)
- Routing depends on operating mode (hands-on/supervisory/away).
- Hands-on: all notifications visible.
- Supervisory: escalations only.
- Away: queue everything, batch on return.

### Direct-to-User Messages (REQ-COM-005)
- Agents can send messages directly to the user (bypassing tree).
- These appear as notifications/badges.
- Used for critical questions or results.

### Lateral Communication (REQ-COM-006)
- Agents in the same tree can communicate laterally (sibling-to-sibling).
- Requires capability grant from parent.
- Communication goes through the shared workspace (doc store files).

### Status Updates (REQ-COM-007)
- Agents emit periodic status updates.
- Parents aggregate child status for their own updates.
- Dashboard reflects real-time status.

### Error Propagation (REQ-COM-008)
- Errors propagate up the tree.
- Parent decides: retry, reap, or escalate.
- All errors are visible (Invariant #7).

---

## Chat Discussions (REQ-CDS)

### Chat as Primary Interface (REQ-CDS-001)
- Every servitor has a chat interface.
- Chat is the primary way users interact with individual servitors.
- Chat history persists across sessions.

### Chat History Display (REQ-CDS-002)
- Messages rendered in chronological order.
- Content blocks (text, thinking, tool calls) rendered by type-specific components.
- All display is passthrough (REQ-DET-002).

### Chat Input (REQ-CDS-003)
- User can send text messages to any servitor.
- Messages are delivered to the servitor's session.
- Input is available during any servitor state (though response depends on state).

### Multi-Servitor Chat (REQ-CDS-004)
- User can switch between servitor chats.
- Each chat maintains its own scroll position and state.
- Switching is instant (no reload).

### Chat Persistence (REQ-CDS-005)
- Chat history loaded from Claude's native JSONL storage.
- Display-only (no API calls for history).
- Session IDs persisted in `.tavern/servitors/<name>/servitor.md`.

---

## Implementation Patterns

### ChatViewModel
- `@MainActor`, conforms to pattern in `core.md`.
- Observes servitor state for UI updates.
- Sends messages through `ServitorMessenger`.
- Handles content block rendering via `MessageType` enum.

### Message Rendering
- Text blocks: markdown rendering.
- Thinking blocks: collapsible, styled differently.
- Tool calls: structured display showing tool name, params, result.
- All rendering is deterministic and passthrough.

### Shared Workspace Communication
- Agents communicate primarily through files in the doc store.
- "If it's not in a file, it doesn't exist" (Invariant #5).
- File-based communication is the blackboard pattern.
- Changes to shared files are visible to all agents with read access.
