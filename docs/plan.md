# Skill /plan

Builds an implementation plan from a task file. Reads the task, explores the codebase via sub-agents,
makes architectural decisions, decomposes the work into atomic tasks, and picks the execution strategy.
The output is a plan file that `/yoke:do` executes autonomously.

## Input

`$ARGUMENTS` — path to the task file produced by `/yoke:task`.

```
/yoke:plan .yoke/ai/86-black-jack-page/86-black-jack-page-task.md
```

## Phases

The skill runs autonomously through 4 sequential phases. Interaction point: Complete (Phase 4).

| Phase | Name         | What happens                                                                                                                                                                    |
| ----- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1     | **Load**     | Read the task file, extract fields: title, slug, complexity, requirements, constraints                                                                                          |
| 2     | **Design**   | Sub-agent `plan-architect` investigates the codebase, makes design decisions, decomposes into tasks, builds the DAG, picks routing mode; interactive clarifications happen here |
| 3     | **Write**    | Write the plan file to `.yoke/ai/<slug>/<slug>-plan.md`; self-check prose; auto-commit the artifact                                                                             |
| 4     | **Complete** | Completion loop: run /yoke:do (recommended) / review via revdiff / finish                                                                                                       |

## Output

File `.yoke/ai/<slug>/<slug>-plan.md` with the following structure:

- **Header** — Task, Complexity, Mode, Parallel
- **Design decisions** — numbered (DD-1, DD-2…), with rationale and alternatives
- **Tasks** — atomic tasks with files, dependencies, scope (S/M/L), verify command
- **Execution** — mode, parallel, order (text DAG)
- **Resolved questions** — closed questions with answers
- **Verification** — criteria from the task file

`/yoke:do` reads the `Mode` and `Parallel` header fields directly.

## Routing

Three execution modes, chosen by complexity, task count, and file intersections:

| Mode         | When                                                            | Characteristic                                                          |
| ------------ | --------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `inline`     | Simple tasks, 1–3 tasks, single module                          | Sequential in the current thread, minimum overhead                      |
| `sub-agents` | 3+ tasks, independent groups exist                              | Each task is a separate sub-agent; parallel groups run at the same time |
| `agent-team` | Cross-layer (frontend + backend + tests), coordination required | A team of agents with shared context via TeamCreate                     |

The orchestrator decides based on the file intersection matrix from the Design phase.

## Sub-agents

| Agent            | Model | Role                                                                                                                      |
| ---------------- | ----- | ------------------------------------------------------------------------------------------------------------------------- |
| `plan-architect` | opus  | Codebase investigation, design decisions, decomposition into tasks, file intersection matrix, DAG, routing recommendation |

## Example

```
/yoke:plan .yoke/ai/86-black-jack-page/86-black-jack-page-task.md
```

## Connections

```
/yoke:task → /yoke:plan → /yoke:do → /yoke:review
```

`/task` defines the task. `/plan` builds the implementation plan. `/do` executes the plan.
