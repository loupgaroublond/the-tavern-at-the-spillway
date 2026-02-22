Spec Notes

Doc 003

Req 001 is out of date on npm need, can run on claude program itself. 

Too specific about what version clodkit

Requirement is also in development, project stay on top of latest improvements in macOS things, until release, since there’s no legacy usage.

Req 005

The diagram of objects is only demonstrative, only the text is part of the requirement

Req 006

No one said this was a thing, drop it

Req 007

Same with the types of queues in particular in that table

Also, isn’t combine the old thing that’s not interesting to apple anymore?

Questions:

There is one Jake per project, because there’s one Jake session log in ~/.claude/sessions, per directory. Jakes’ purview is the directory it’s in and down. Therefore there are multiple jakes, because there are multiple directories.

The other user interface into the core is the testing suite. We don’t need a TUI to prove anything

Lastly, the only distribution method of this project is going to be source code. Full fucking stop. There will be no builds, nothing distributed otherwise. This app is going to violate so many rules if we did that. 

—————
Doc 004

Req 001

Jake also has the authority to hand out capabilities, which are access to resources, to the agents, with various stipulations that are enforced by the deterministic shell.

Jake can not hand himself capabilities beyond what he has.

Put a pin in the capabilities part, because we need to back write this into the PRDs

Req 004

These agents are also children of Jake, fundamentally, though, it’s a key property.

Another key property is that immortal agents, ie daemons, is they are always resuscitated when their session context doesn’t work anymore. 

It’s key that these agents can either run stateless, or persist their state, perhaps frequent, to provide context to the resuscitated (the new session) agent

Req 005

~~What are valid transitions? This must be defined, ask me if you need help, or have questions.~~

Actually, I found it, it needs to be connected to the requirement better, ie pull it up here.

Moreover, there’s failed reaped and dismissed reaped states, depending on whether it was an error code or successful and therefore formally dismissed. The star at the beginning is Summoned. For waiting for input, waiting for wakeup, or done, the target is DismissedReaped. Both “reapeds” point to GC. That just means dropped from the computer’s runtime memory and relegated to disk in perpetu…. <glitch> or failure, lol.

These state transitions are in the agent logs, they only get logged in debug, because otherwise there’s no need for that shit

Req 006

We need to flesh this out, another topic for discussion, put a pin in it too.

Req 007

Needs a complete rewrite in light of claude teams, lol

New principle is this runs orthogonally to the stuff this tool does, and if we can, try to integrate with talking to it’s team agents some how. But otherwise, we are orthogonally managing top level claude sessions.

Req  008

Non blocking or async, really. Let code use promises of future values a point to restart execution at.

Finally, we need to add another requirement that there can be a defined timeout for an agent to pause without issuing a wait or done signal, before it is either prodded to respond or reaped. This can be adjusted to suit purpose, but can be enforced is the essence of the property.

Questions

The agent can decide that they’re done, use the done signal, and then be tested on its commitments. If it passes the test, it’s completed and may go through. Otherwise it’s sent back to work with a gap report.

Perseverance means that the agent is told both in advance, and at every incident, the only way it may signal completion of outputting tokens is with Done. If it tries any wait command, it get’s a response that it must persevere and keep working without getting any response, or taking a break.

Model selection is gonna be another feature, pin in it please, because it needs to go in PRDs. Any session can be set with a specific model for any reason as part of the workflow. Drone’s are not special in that regard, but it’s more the nature of the tasks that it’ll be asked to perform.

We need to define failure boundaries, where one parent agent may say either that child has failed, kill it, or declare that itself has failed. The idea is the system reverts as much as possible to the state before they existed, in this kind of failure, which is the fish or cut bait approach. If the agent is running into issues, then it can consider whether to spare the remaining tokens in its budget, or keep going.

Lastly, agents are limited to possible token budgets and the capabilities that they are given (delegated to), from another agent. 

——————
Doc 005

Let’s keep capability delegation separate, so we don’t overload the spawn functions’s remit. An agent calling spawn, which we really need to call summon, across the board, it can call a subsequent delegate command, using a handle or id it receives from the agent summon. The agent summon is async, so the id is the id of the promise that ultimately does become the agent pointer, and then the main actor for the agent that is spawned receives the capability handle right away, and just needs to wait on the session to notify it that it’s received the capability and can now invoke things. 

Req 003

Jake spawned agents may receive an assignment that tells the new servitor to work on a task, ask the user a question, say something, or wait for user input, as well. The servitor will only receive a grant of capability from the deterministic harness only if the Jake, or other parent servitor ticks that box in the spawn call, with assignment.

Req 004

Each tree may have a different naming scheme, and Jake has to cycle through them. There may be rules on how to cycle, when to include specific sets. We’re gonna need a lot. Seriously. Loads of pins go here.

Req 005

Once a name is used, it’s set as one agent. However, remaining names in the naming set are still possible to assign to new servitors. Root servitors of trees must ensure they coordinate on using the name set, to maintain this property. (This can be maintained in the deterministic shell, as well, to ensure the agent can lock the name before creating the agent.)

Req 006

To clarify, tier 1 names is a set of name sets. Jake will rotate through assigning those, until they’re depleted or the user unlocks other tiers.

Req 008

Keep as a STUB for now.

Questions

Model selection is orthogonal to the agent, and can be set by user request or by Jake or the servitor for various reasons.

Token budget system will need fine tuning, but the gist is, the agents may get periodic updates, and so on.

When the agent is done, it has a deterministic flag set to tell it to check a work queue and wait idle if it’s empty, dismiss it, or just wait in idle. When it’s waiting in idle, some daemon may be periodically checking on the queue and waking up idle agents.

If the summon fails, then the parent agent gets notified of the event. Same as getting notified that it’s Completed, or being reaped.

No maximum. Deal with it.

We do not migrate agents. Agents may communicate across trees if granted the capability.

—————————
Doc 006

Req 001

Another condition is the agent decides to abort.

Req 005

Note that this is something the agents may also control partially with capabilities, ie. Erlang style, they may fire off a team of workers, and if any one fails, the whole gang is terminated and restarted, and very fast. However, they must leave the artifacts in place, in some kind of change set draft, for debugging, potentialy.

Finally, you have a different agent lifecycle graph here, fix this inconsistency.

Questions

Rewind storage will probably be set at run time based on the particular sandbox rules for the agent. That can mean just conversation history, the whole change set, or other distinctions.

No limits

We just keep things lying around unless space concerns come up, and then we’ll burn that bridge when we get there.

The parent agent may decide to cut bait at the whole gang level.

When an agent is resummoned, its system prompt tells it as much, and provides as much context as possible for it.

Hibernation is waiting idle.

—————————
Doc 007

We have several states and modes for agents, let’s try to get them together into a single spec doc, and then have other spec docs refer to that doc.Create a new spec doc with a new number, put the stuff in there, and then we can just deprecate the sections that are redundant earlier in the spec. However, most important, we should have all possible agent states and modes represented in one place.

Also, let’s be careful to rename everything servitor instead of agent, consistently. Even I keep making this same mistake.

Req 003

Zooming isn’t the right word, here. Yes, the user is “zooming in” on the situation, but the idea is that the user joins and leaves agent sessions, it’s technically orthogonal from perseverance and backgrounding. Backgrounding means the agent doesn’t get a first class chat window. Perseverance means the agent is not allowed to go idle. Joining a session means the agent is notified the user is present or absent, as it occurs. The agent is aware of these three states and may alter their behavior accordingly, especially in terms of how they communicate with other agents.

Req 004, this is a better use of “zoom”.

Req 005, this is not a mode, just an initial prompt, plus our expectations of the servitor’s next steps. That’s why it’s not a parametrizable thing, but simply a distinction between what the user is allowed to do vs Jake 

Req 006

Technically, the exact sets of cogitation words isn’t part of the spec, but a few things are. One is the use of these words. Another is how they are formatted, linguistically. Another is that they are different than everyone else’s. Lastly, like the various servitor names, they are tiered and access to sets of verbs is gated by conditions, such as number of hours spent in app, or so on.

Table:

This conflates those different orthogonal states of a servitor. A Jake spawned agent doesn’t have to be in perseverance/auto-continuation, necessarily. It may or may not show up as a background servitor vs getting a chat window. (Background servitors are displayed as resources with their parent servitor, UX is TBD). Etc…

The transition properties seem ok though.

Again, we need to unify these state machine diagrams into a single canonical one.

Questions

Perseverance means it’s an infinite loop until the servitor is confirmed done, or prematurely terminated.

User consent means we don’t pop up chat windows that steal focus when the user doesn’t expect it. This is grounded in a number of factors and settings, such as user preferences, context, or per agent rules.

Yes, modes are persistent across app restarts, but we should leave a pin in things where either the app can start in safe mode with no agent actually processing anything, all are idle, or just simply, paused until the user presses a resume button. Put a pin in it, we may want a big red stop/pause button for the whole thing too, not sure.

We have talked about the perseverance prompt a bit, so what questions do we still have? Can we specify its contents?

Notification prioritization is another part of the spec to be tackled separately, because they’re not just about agent state and mode, but rather how the whole app bubbles these things up across agents or to the user.

————————
Doc 008

Req 001 - it might be better to say that invariants in prompts are enforced, so that even if a parent servitor composes the prompt to a child, the system will enforce.

Req 002 - this is really an invariant that all the blocks the user is seeing is a passthrough, and not reinterpreted by the agent. Namely, agent responses, e.g. thinking blocks, messages, are shown verbatim as received, which is the user expectation. It also means, if the agent makes a tool call, the tool call responds with a structured block response, the actual block itself is rendered by a deterministic component in the app, even though the agent will also see the data and then respond non deterministically afterwards.This is really important, and this point must be emphasized first: If the user is looking at a representation of a record or file on disk, they need to see that accurately and be able to trust the system that everything inside that block is not hallucinated.

For instance, if the user pulls up a todo list based on some tags, the list is rendered as received from the data store, and the user can be sure the agent didn’t read the list, hallucinate, and produce a similar but incorrect list of results.

Req 003

This elaborates on the previous req, when it comes to tool calls, but the nuance here is this is about typed structured data, using at minimum, structural types, if not nominal typing. (As in the distinction in type theory).

Req 004

The agent declaring i’m done, is simply a request to check the commitment. Verification may also incorporate another agent to perform an evaluation non deterministically, as long as this is surfaced properly to the user. The invariant, though, is the servitor is not yet Complete, until it’s verified separately.

Req 006

This isn’t a thing at all. Jake works like every other agent, when it comes to tool calls.

Req 007

Can you elaborate more on what this is? I don’t even understand what it’s trying to do here.

Req 008

Other servitors have access to these tools as well. UUIDs aren’t hard requirements, but unique identifiers for servitors is.

Callbacks are too prescriptive about architecture, and not requirements.

Dismissing does not remove an agent from any registry, just the UI. 

Table:

Done = agent says “done”
Complete = verified commitment is met

Jake doing multiple actions is a property of the underlying ClodKit and claude, not Jake.


Questions

The deterministic shell is everything managed by the app vs an agent/servitor. Specifically, it’s the deterministic state machines that dictate agent behavior and how their sessions are displayed. It’s the deterministic rules set up new servitors. New features are developed according to this principle, for example, when we implement workflows, we’ll have a deterministic state machine for them. The requirement here is that the app behaves in ways the user understands and expects, and ensures the servitors can not run off the rails.

The commitment assertions is a big TBD because we need to actively develop what works here. The requirement is still vague on purpose.

The standard tool set is the standard claude tool set, modulated by what ever capabilities the servitor has/hasn’t.

We will need to develop prompt composition further, as well, as we develop things, so it’s’ not a gap so much as a pin to put in things that we should revisit.

Partial completion is easy, the answer is no, it’s not complete. However, realistically, the servitor may receive feedback when it’s told the work is incomplete that indicates what passed so far. This isn’t a requirement in the spec, simply because the user or the parent servitor may also decide to early terminate the agent instead of pushing back.

———————
Doc 009

Req 002

Lateral communication is also a capability granted by the parent servitor. The scope can be just siblings, or cousins as well.

Questions:

Bubbling up is ad-hoc in the moment, as the situation demands, modulated by the permissions and capabilities the servitor has.

We will develop a separate spec section for message protocol and systems.

Let’s assume servitors have tools to query their position in the hierarchy and find other servitors.

Message delivery guarantees are things we’ll build on top of the basic messaging protocol. Deterministic messages, ie. Code events, in the app will have their guarantees, so we know for certain that user messages are sent to the underlying claude agent. However, if one agent posts a message to another, that agent will have to use the messaging protocol to wait for a confirmation response, if needed.

Let’s burn the rate limiting bridge when we get there. Agents do have token budgets though.

Privacy is also gonna be TBD and probably project specific. Capabilities will help us here.

————
Doc 010

Req 001 - let’s clarify that database rules layer content is stored in the file store itself, thus they are also database records. The corollary is the only fundamental types and access to the document store is same file api you get for files. However, we may run some run time process that maintains a memory cache, indices, and provide more sophisticated APIs on top of the store.

This indicates we need a follow on ADR that the data store for a Tavern has to be the low layer below and then other, ACID compliant, layers on top, depending on the need. This will implement the run time for things like messaging and queues, that need certain in-memory support to be performant.

The store is the entirety of the Tavern at that directory though. This req does not preclude using macOS provided storage or ~/.tavern/ for system / user level things.

Req 003

No one said anything about namespacing. That’s wrong. Filesystems trees aren’t namespaced in that sense. This requirement is saying in essence any document could potentially be doing the work of one of five roles, or perhaps more.

Req 004

This is just, not a thing at all. None of these things have anything to do with a document store. If they’re even requirements, dubious that is, they belong elsewhere.

Req 005

Let’s introduce a new concept, there is a chat discussion that persists for the lifetime of a servitor. Then there are sessions of claude underneath, where we can sometimes continue a session, or create a new one. However, we’ll provide a context window in the app that gives the user a contiguous experience.

When there’s no resumable session, the app must create a new one to pick up. 

This section is otherwise just explaining how Claude Code works. That’s not a requirement.

Req 008

Why is this a requirement? You’re just showing part of claude code’s implementation and suggesting we adopt it, which sounds a little like an ADR, but even then, we don’t need this. Each servitor will have a distinct name for each project. That’s as canonical an ID key as you will get.

Table

This is missing ~/.tavern, potentially, and even then, .tavern/ in the project might not be version controlled, it’s part of a project, not a repo.

We don’t need session state properties as a table

For core doc storage, source of truth is violated when in-memory state partially flushed to disc at crash time.

Questions

Namespacing is not a thing.

Doc store durability means a) the disk hardware capability, b) the file system’s capability, and c) any in-memory proxy has ACID compliant properties when flushing to disk.

Message protocol is ADR material, messaging requirements is a spec doc we need to create.

Conflict resolution is not an issue, one invariant is that there’s always a merge queue.

File locking is TBD.

Document versioning does not exist, unless the file system provides it.

Storage quotas are a matter for the file system and the computer’s administrator.

——————

Doc 011

Req 001 Rename outputs to connectors.

Req 002, the changeset and diff capabilities rely on features only available in some sandbox configurations.

Graph

There’s an arrow from rejected to abandoned. Abandoned goes to deleted, and applied has an arrow to merged.

Questions

Changeset lifecycles belong to the sandbox, generally.

Protocol is an ADR thing.

When we test container and VM components, do we expect those tests to be faster than regular startup? What’s important is that we make sure there is a path for testing that is as fast as possible, so that agents can iterate quickly, but reliably.

Merge conflicts are resolved by the merge queue.

Define “escaped” before we discuss whether there’s an actual gap here.

Resource limits aren’t application requirements, necessarily.

————

Doc 012

Req 002, this is just an example, not part of the spec.

Req 003, another example.

Req 004, now you’re talking specs.

Req 005, oh, nvmd, you’re back to examples of workflows.

Req 006, this is a spec, actually, because we do need the merge queue, and then other parts of the spec can refer to this part. It should also be built on top of the workflow engine.

We need a requirement defining the workflow engine.

Interference detection has nothing to do with workflows, that’s a sandboxing concern.

Questions

A workflow has steps, one type of step is another workflow. Nothing prevents non-terminating programs in Turing complete languages.

Template format and workflow formats are a potential ADR

What the heck are expert prompts?

Workflow spec needs a req for defining recovery process at different parts in the workflow, whether to start over, hard fail, go to a recovery stage, etc…

Agents are responsible for their merges, this is in the spec already.

Why do we need workflow metrics?

—————

Doc 013

Req 002 this is conceptual, each chat discussion with a servitor also represents some task the user wants done. Child servitors are subtasks. The representation elements are part of the view architecture.

Req 003 it’s not clear this is a definitive requirement just yet. We just need to require a way to find all the active agents, such that Jake gets prominence, and the user can see what’s going on.

Req 005 to clarify, a chat only view mode is possible by hiding all the other blocks.

Req 007 the project is the directory. We might have a .project or similar file in the root, and that file could even be a file bundle, like Xcode, but that document isn’t the project itself.

Req 009 needs to be the list of controls we need around a chat window, without prescribing too much UI

Req 011 wtf? This isn’t a requirement.

Tables

Dual representation isn’t a thing.

Questions

For some actions in the app, we might offer a yes/no/always do it automatically, three choice prompt. This way, the user can opt in to having certain actions cause new windows to pop up or change. This must be user configurable though.

UI stream separation is a matter for view architecture.

Keyboard shortcuts needs to be another section of the spec.

Same for Accessibility, these are important.

Search as well, another section.

—————

Doc 014

Req 002, need a different term than modes, maybe presentations? Let’s look at more words.

Req 005, this is agent behavior, not view architecture.

Questions

UI stream? What’s the question?

There’s no spec on tiling constraints (yet)

Tiles exist within a window, and that’s your multi monitor answer.

Add a requirement for drag and drop, plus other rearranging tools.

Animation is another requirement, albeit we can talk about its properties, not the specific animations.

Put a pin in responsive layout, well see where that belongs.

————————
Doc 015

Req 005 these aren’t violations if they aren’t enacted. This is more that we report every attempt to act outside the servitor’s bounds.

Req 006 Agents can’t modify their own boundaries or capabilities.

Req 007 this isn’t a requirement in the spec.

Req 008 this sounds like an ADR, rather than describing what properties of logging we want.

2 modes. Debug and Production builds log different things, production is pretty quiet, debug is incredibly verbose, to provide insight without requiring complex IPC to function.

Req 009 this is not an extension of the previous req, but separately, that the debug builds provide the capabilities for agents can develop this app using tools available to them. That can include complex IPC, potentially, but at minimum, a debug build is still logging because sometimes that’s the only option working.

Req 010 isn’t this about user workflows? It doesn’t belong here, and in any case, let’s drop this

Req 011 this is about agent behaviors and communication, not observability of the app itself.

Questions

Metrics are kept in ~/.tavern for now

The question about saturation is already answered above.

Why does the format matter for the spec right now?

The three gaps are future features to design. Not gaps.

———————
Doc 016

100% code coverage during testing, for a full test, and no warnings in the builds needs to be part of the spec.

Add grade 2.9 where we use a local LLM that’s free.

Req 013 - emphasize this is for debug compilation

Req 015 - not part of the spec. Maybe an ARD if framed differently.

Grade 5 is run both pre-release and as needed

Questions

This is a gap, not a question.

Grade 3 needs to be run before merging, and pass. It doesn’t need to be part of the development iteration cycle though, which sticks to grades 1 and 2

This is also a gap, not a question

I just answered the question about code coverage.

What is mutation testing?

Regressions are when the tests fall below the requirements? Or do you mean we need to log runs for metrics analysis?




