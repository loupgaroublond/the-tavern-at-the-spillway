You are the swarm coordinator. There are open beads to complete, and you will create a workteam to do them. You will not work directly on beads yourself — you organize, assign, coordinate merges, and ensure quality.

**Plan mode:** If you are in plan mode, propose a plan for how you would organize the team — which beads go together, what the worktree/branch strategy is, how many agents you'd run, what order you'd merge in. Present that plan for approval rather than jumping straight into execution.

## Worktree Strategy

Either everyone works on the same shared code (requiring careful coordination to avoid conflicts), or they build worktrees. Create worktrees as subdirectories from the project root, matching the branch name. You can run as many team members as you think you can, as long as all the other constraints are met.

## Bead Analysis and Assignment

Look at all the beads for structure and flow, to see what areas of the code will be altered in which bead. Then create team members and assign them individual or several beads — whatever makes sense to develop a git commit. Focus on smaller, incremental changes, and it's ok to spend more time waiting on tests if the team is testing smaller incremental git commits. If all the open tickets focus on the same area, you probably can only run one team member at a time, but if there are elements that can be parallelized, run multiple. Spin them up and down as you need them. A team member should work on multiple beads making multiple changes if they are all related. Otherwise, try to use fresh agents when moving to new areas.

Use your judgement how to assign the beads, how to organize the team, which ones to do on main vs worktrees, and what model the agent should use — some beads might be ok to run on sonnet or haiku, you can take a look. While team members may talk to each other to collaborate, you are the ultimate arbiter of questions.

## Merge Discipline

As workers complete their tasks, your job is to coordinate merging into main. Each worker must make sure all their commits will fast-forward merge to main, i.e., their shared root is the HEAD of main. If their code is behind main, they must rebase first before they can merge. You decide in what order each agent may merge into main. You allow each agent to merge only when it is their turn to do so — however, it is their responsibility to be aware of changes to main and ensure their work is compatible. You may proactively communicate about changes to the team.

Keep everyone working as efficiently as possible. Do things where it will help efficiency. These are not suggestions — the word "may" here means you have permission. You will do all of these things.

## Scope

$ARGUMENTS

If no scope was provided above, query all open beads with `bd list -n 0 --status open --json` and use your judgement to organize the work.

## Bead Commands

Use `bd list -n 0 --status open --json` when querying beads. Use `bd show <id> --json` to get full details on individual beads. Use `bd update <id> --status in_progress` when claiming, and `bd close <id> --reason "..."` when done.

## Build and Test Commands

redo-based, each command includes everything above it:

```bash
redo Tavern/xcodegen     # Regenerate Xcode project from project.yml
redo Tavern/build        # + compile the project (xcodebuild)
redo Tavern/test-core    # + run TavernCoreTests only (framework layer — fast)
redo Tavern/test         # + run ALL Grade 1+2 unit tests (TavernCore + app-level)
redo Tavern/run          # + kill any running instance + launch the app
```

Use `test-core` when changes are limited to `Sources/TavernCore/` — it's the fastest feedback loop, covering only the framework layer. Use `test` when changes touch the app target (`Sources/Tavern/`) or you want full unit test coverage before merging. Both skip integration tests (Grade 3+) which hit real Claude API.

## Testing Discipline for Merges

- During normal development cycles, team agents run `test-core` or `test` as appropriate. Grade 3 integration tests (`redo Tavern/test-grade3`) use real Claude API calls — a finite resource — so they are NOT part of the regular testing loop.
- When a team agent is ready to merge their work into main, they must run Grade 3 tests on their branch BEFORE merging. This is a merge gate.
- After you (the coordinator) merge work into main, you also run Grade 3 tests to verify the integrated result.
- At the very end of the entire process, once all work is merged into main, wait for the user's signal before running Grade 4 tests (`redo Tavern/test-grade4`). These are XCUITests that steal window focus and require a dedicated environment.
