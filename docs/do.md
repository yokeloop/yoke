# Skill /do

Executes a task from a plan end to end without stopping. Reads the plan file,
runs tasks, runs the post-implementation pipeline (validate, document, finalize),
and writes a report. The developer starts it and returns on notification.

## Input

`$ARGUMENTS` — path to the plan file produced by `/yoke:plan`.

```
/yoke:do docs/ai/86-black-jack-page/86-black-jack-page-plan.md
```

## Pipeline

6 stages, each tracked in TodoWrite. Stages 1–5 run without confirmations; Stage 6 has a Complete loop with an AskUserQuestion.

| Stage | Name         | What happens                                                                                                                               |
| ----- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 1     | **Parse**    | Read the plan file, extract Mode, tasks, depends_on, verification. Build the todo list.                                                    |
| 2     | **Execute**  | Run tasks: inline (trivial/simple) or sub-agents sequential (medium/complex). Dispatch task-executor + combined task-reviewer per task.    |
| 3     | **Validate** | Dispatch validator + formatter in parallel: lint, type-check, tests, build; format changed files.                                          |
| 4     | **Document** | Opt-in via `--update-docs` flag or plan frontmatter `update_docs: true`. Sub-agent updates README, CHANGELOG, JSDoc/TSDoc for new exports. |
| 5     | **Finalize** | Write the report directly (orchestrator), format, send notification.                                                                       |
| 6     | **Complete** | Offer completion options: /yoke:review (recommended) / review via revdiff / finish                                                         |

## Output

File `docs/ai/<slug>/<slug>-report.md` with the following structure:

- **Header** — Plan, Mode, Status (complete / partial / failed)
- **Tasks** — per-task status table (DONE, BLOCKED, SKIPPED)
- **Post-implementation** — statuses for validate, document, format
- **Concerns** — concerns raised by sub-agents (when DONE_WITH_CONCERNS)
- **Validation** — result of each command (lint, tests, build)
- **Changes summary** — files, actions, descriptions
- **Commits** — hashes and messages in chronological order

## Execution modes

`/do` reads the mode from the plan file's `Mode` and `Complexity` fields:

| Mode                    | When             | Characteristic                                                      |
| ----------------------- | ---------------- | ------------------------------------------------------------------- |
| `inline`                | trivial / simple | Sequential in the current thread, minimum overhead                  |
| `sub-agents sequential` | medium / complex | Each task is a separate sub-agent via Agent tool, context isolation |

V1 runs everything sequentially and ignores `Parallel: true` in the plan.
`Mode: agent-team` → falls back to sub-agents sequential.

## Status protocol

Sub-agents return a status after running a task:

| Status               | Meaning                      | Orchestrator action                                 |
| -------------------- | ---------------------------- | --------------------------------------------------- |
| `DONE`               | Task complete, verify passes | Commit, next task                                   |
| `DONE_WITH_CONCERNS` | Complete but with concerns   | Commit, record concerns in the report               |
| `NEEDS_CONTEXT`      | Missing information          | Add context, re-dispatch (max 1 retry)              |
| `BLOCKED`            | Cannot proceed               | Skip dependent tasks, keep running independent ones |

## Sub-agents

| Agent           | Model  | Role                                                                                                        |
| --------------- | ------ | ----------------------------------------------------------------------------------------------------------- |
| `task-executor` | opus   | Runs one task: implementation, verification, commit                                                         |
| `task-reviewer` | sonnet | Combined spec compliance + code quality review in one pass (replaces old spec-reviewer/quality-reviewer)    |
| `validator`     | haiku  | Lint, type-check, tests, build + auto-fix                                                                   |
| `formatter`     | haiku  | Detects the formatter and runs it on changed files                                                          |
| `doc-updater`   | sonnet | Updates README, CHANGELOG, JSDoc/TSDoc (Phase 4 — opt-in only)                                              |
| `code-polisher` | opus   | Simplifies code: over-engineering, duplication, extra wrappers (exists in agents/ but not in main pipeline) |

## Example

```
/yoke:do docs/ai/86-black-jack-page/86-black-jack-page-plan.md
```

## Connections

```
/yoke:task → /yoke:plan → /yoke:do → /yoke:review
```

`/task` defines, `/plan` builds, `/do` executes, `/review` prepares the report.
