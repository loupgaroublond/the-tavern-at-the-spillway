# Architecture Proposal: Leader Election

**One-line summary:** Dynamic coordinator selection among peer agents with leadership transfer capabilities, replacing Jake's fixed role with elected leadership.


## Core Concept

Leader Election applies distributed systems consensus patterns to agent orchestration. Rather than hardcoding Jake as the eternal coordinator, agents participate in an election process to determine who leads. The elected leader coordinates work, spawns children, and communicates with the user. If the leader fails, becomes overloaded, or is better suited for direct work, a new election occurs and leadership transfers.

This fundamentally challenges the Tavern's premise: Jake is not "The Proprietor" by divine right, but by election. He may be the natural choice initially (the only agent at startup), but as mortal agents spawn and gain context, leadership could transfer. A mortal agent deeply embedded in a codebase might coordinate better than Jake, who maintains tavern-wide perspective but lacks local expertise.

The model draws from Raft, Paxos, and Zookeeper's leader election, but adapted for agent orchestration. Elections are not about fault tolerance (though that is a benefit) but about dynamic optimization: the right agent leading at the right time. A code review task might elect a specialized reviewer as coordinator. A debugging session might elect the agent with deepest context. Jake remains available as a candidate, but he is peer to the others.


## Key Components

```mermaid
graph TD
    subgraph "Election Infrastructure"
        EM[ElectionManager]
        ET[ElectionTerm]
        HB[HeartbeatService]
    end

    subgraph "Peer Pool"
        Jake[Jake<br/>candidate]
        M1[MortalAgent 1<br/>candidate]
        M2[MortalAgent 2<br/>candidate]
        M3[MortalAgent 3<br/>follower-only]
    end

    subgraph "Leadership Role"
        Leader[Current Leader<br/>elected dynamically]
    end

    subgraph "User Interface"
        User[User]
        UI[TavernUI]
    end

    EM --> ET
    EM --> HB

    Jake -.->|votes in| EM
    M1 -.->|votes in| EM
    M2 -.->|votes in| EM
    M3 -.->|votes in| EM

    EM -->|elects| Leader
    Leader -->|coordinates| M1
    Leader -->|coordinates| M2
    Leader -->|coordinates| M3
    Leader -.->|may be| Jake

    UI -->|communicates with| Leader
    User --> UI
```

**Election Flow:**

```mermaid
sequenceDiagram
    participant EM as ElectionManager
    participant J as Jake
    participant M1 as Mortal1
    participant M2 as Mortal2
    participant User

    Note over EM: Term 1 begins
    EM->>J: request vote (term=1)
    EM->>M1: request vote (term=1)
    EM->>M2: request vote (term=1)

    J-->>EM: vote for Jake
    M1-->>EM: vote for Jake
    M2-->>EM: vote for Jake

    EM->>J: you are leader (term=1)
    Note over J: Jake leads

    User->>J: assign task
    J->>M1: spawn for subtask
    J->>M2: spawn for subtask

    Note over M2: M2 gains deep context

    User->>J: need expert for this area
    J->>EM: trigger re-election

    EM->>J: request vote (term=2)
    EM->>M1: request vote (term=2)
    EM->>M2: request vote (term=2)

    J-->>EM: vote for M2 (domain expert)
    M1-->>EM: vote for M2
    M2-->>EM: vote for M2

    EM->>M2: you are leader (term=2)
    Note over M2: M2 leads
    User->>M2: continue work
```


## Pros

- **Dynamic optimization**: Leadership transfers to the agent best suited for current work, not fixed by design

- **Natural fault tolerance**: If leader fails, election produces new leader without special recovery code

- **Scales expertise**: Deep specialists can coordinate domain-specific work without routing through generalist

- **Reduces Jake bottleneck**: High-load scenarios can distribute coordination across multiple leaders (per-subtree)

- **Matches distributed systems intuition**: Developers familiar with Raft/Paxos understand the model immediately

- **Enables agent autonomy**: Agents are peers, not permanent subordinates; aligns with agent capability growth

- **Supports hierarchical elections**: Each mortal tree could have its own elected leader, not just one global leader


## Cons

- **Destroys Jake's identity**: The Proprietor is central to Tavern's character; making him electable undermines the premise

- **Election overhead**: Consensus protocols require message rounds; adds latency to leadership changes

- **Split-brain risk**: Network partitions or async timing could produce multiple agents thinking they lead

- **User confusion**: "Who is in charge?" becomes dynamic; harder to explain than "Jake coordinates"

- **State transfer complexity**: New leader must acquire predecessor's coordination state (active tasks, pending questions)

- **Over-engineering for v1**: Current scope has one Jake, simple mortal pool; elections are heavyweight machinery

- **Character inconsistency**: How does Jake "sound" when he is not leader? Does he still have carnival barker energy as a follower?


## When to Choose This Architecture

Choose Leader Election when:

1. **Multi-project coordination exists**: Multiple Jakes across projects might need meta-coordination with elected global leader

2. **Agent expertise matters**: Tasks benefit from specialist leadership rather than generalist routing

3. **Fault tolerance is critical**: System must survive coordinator failure without user intervention

4. **Peer-to-peer model is desired**: Agents are conceptually equal, with leadership as temporary role

5. **Load balancing is needed**: Single coordinator is bottleneck; distributing leadership helps

Avoid Leader Election when:

- **Character identity matters**: Jake-as-Proprietor is central to user experience

- **System is simple**: One project, one coordinator, few agents; elections add no value

- **Determinism is valued**: Elections introduce non-determinism in who leads

- **User mental model is "one boss"**: Dynamic leadership confuses rather than empowers
