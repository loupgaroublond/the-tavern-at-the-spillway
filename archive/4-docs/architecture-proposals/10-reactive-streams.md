# Reactive Streams Architecture

**One-line summary:** Agents are publishers and subscribers with backpressure-aware communication, enabling natural flow control when the user or downstream agents are overwhelmed.


## Core Concept

Reactive Streams treats every agent as both a **publisher** (emitting events like questions, status updates, and completions) and a **subscriber** (receiving assignments, answers, and control signals). The key insight is that subscribers control the rate of consumption through **demand signaling** — they explicitly request how many items they can handle.

This maps directly to the PRD's sacred invariant: "User attention is sacred — never force new content on user without consent." In a reactive streams model, the user's attention is a subscriber with limited capacity. Agents can publish questions freely, but those questions only reach the user when the user signals demand (opens a chat, clicks a notification, or explicitly requests updates).

The architecture also solves the bubbling problem elegantly. Child agents publish to their parent, who acts as a subscriber with its own backpressure constraints. The parent may buffer, filter, or throttle before republishing upward. Jake, at the top, manages the final stage before user delivery — deciding which questions surface immediately versus which accumulate in a "needs attention" queue.


## Key Components

```mermaid
graph TB
    subgraph "User Layer"
        UserSub["UserAttentionSubscriber<br/>(demand = visible chat slots)"]
        NotifQ["NotificationBuffer<br/>(pending questions)"]
    end

    subgraph "Coordination Layer"
        JakePub["Jake Publisher"]
        JakeSub["Jake Subscriber"]
        Triage["QuestionTriage<br/>(quick vs deep)"]
    end

    subgraph "Agent Layer"
        Agent1Pub["Mortal Agent 1<br/>Publisher"]
        Agent1Sub["Mortal Agent 1<br/>Subscriber"]
        Agent2Pub["Mortal Agent 2<br/>Publisher"]
        Agent2Sub["Mortal Agent 2<br/>Subscriber"]
    end

    subgraph "Backpressure Signals"
        Demand["Demand(n)"]
        Cancel["Cancel"]
    end

    Agent1Pub -->|questions| JakeSub
    Agent2Pub -->|questions| JakeSub
    JakeSub --> Triage
    Triage --> JakePub
    JakePub -->|filtered questions| NotifQ
    NotifQ -->|on demand| UserSub

    UserSub -.->|Demand(1)| NotifQ
    NotifQ -.->|Demand(n)| JakePub
    JakeSub -.->|Demand(n)| Agent1Pub
    JakeSub -.->|Demand(n)| Agent2Pub
```


## Pros

- **Natural attention management** — Backpressure directly models "user can only handle N things right now"

- **Graceful degradation** — When overwhelmed, system buffers rather than drops or interrupts

- **Composable** — Operators (filter, merge, debounce) build complex routing from simple primitives

- **First-class in Swift** — Combine and AsyncSequence are mature, well-tested implementations

- **Testable** — Time-based operators enable deterministic testing via virtual schedulers

- **Streaming support** — When Claude SDK adds streaming responses, reactive streams handle it natively


## Cons

- **Learning curve** — Reactive programming requires different mental model than imperative code

- **Debugging complexity** — Stack traces through publishers/subscribers are notoriously opaque

- **Combine is in maintenance mode** — Apple is moving toward AsyncSequence; mixing both adds complexity

- **Overkill for v1** — Current batch-response model doesn't benefit from streaming primitives

- **Backpressure semantics unclear for LLM** — Can't pause Claude mid-response; backpressure applies only between responses


## When to Choose This Architecture

Choose Reactive Streams when:

1. The system will have many concurrent agents (10+) publishing events simultaneously

2. Streaming responses become available and need progressive UI updates

3. The attention management problem proves unsolvable with simpler polling/notification patterns

4. You need sophisticated routing (merge multiple streams, debounce rapid-fire updates, sample high-frequency events)

Avoid if v1 scope remains limited to batch responses and single-digit agent counts — the complexity overhead isn't justified until scale demands it.
