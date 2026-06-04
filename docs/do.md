# Skill /do

The universal execution tool. Auto-detects its mode from the input, plans the
"how and where" of the change, executes, and writes a report. Subsumes the
former `/task` and `/plan` skills (now in `deprecated/`).

## Input

`$ARGUMENTS` — any of:

- nothing / a plain task description → **inline**
- a single issue URL, a `<slug>`, or a `*-task.md` path → **sub-agents**
- a PRD issue that has GitHub sub-issues → **team**
- an existing `*-plan.md` path → **sub-agents** (back-compat; executes it directly)

```
/yoke:do                                  # inline — small task described in chat
/yoke:do https://github.com/org/repo/issues/42   # sub-agents — single issue
/yoke:do .yoke/ai/86-black-jack-page/86-black-jack-page-plan.md   # back-compat
```

## Modes

`/do` reads its mode from the **input shape**, then reads the matching
`reference/mode-*.md` body:

| Mode           | When                                | Behavior                                                                                          |
| -------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------- |
| **inline**     | empty / plain chat description      | Brief plan in chat, execute in-session, no pause, no plan file.                                   |
| **sub-agents** | a single issue / slug / task / plan | Write `.yoke/ai/<slug>/<slug>-plan.md`, pause for confirmation, then run the sub-agent pipeline.  |
| **team**       | a PRD ticket with sub-issues        | Write the plan, pause, then dispatch the sub-agents pipeline per sub-issue (TeamCreate deferred). |

A wrong mode guess is caught at the confirmation pause in sub-agents/team modes,
so auto-detection never triggers an unreviewed costly run.

## Pipeline (sub-agents / team)

| Stage | Name         | What happens                                                                                                             |
| ----- | ------------ | ------------------------------------------------------------------------------------------------------------------------ |
| 1     | **Plan**     | Dispatch `task-investigator` (change map) then `plan-architect` (design + decomposition + DAG); write the plan artifact. |
| 2     | **Confirm**  | Present the plan; pause for the user to confirm / adjust / cancel before any code change.                                |
| 3     | **Execute**  | Dispatch `task-executor` per task honoring parallel groups; review each via `task-reviewer` (max 2 fixes).               |
| 4     | **Validate** | Dispatch `validator` + `formatter` in parallel: lint, type-check, tests, build; format changed files.                    |
| 5     | **Document** | Opt-in via `--update-docs` or plan frontmatter `update_docs: true`. Updates README, CHANGELOG, doc-comments.             |
| 6     | **Finalize** | Write the report, commit it, send the notification.                                                                      |
| 7     | **Complete** | Offer completion options: /yoke:review (recommended) / review via revdiff / finish.                                      |

Inline mode collapses planning + execution into the current session and skips the
confirmation pause and the report file.

## Output

File `.yoke/ai/<slug>/<slug>-report.md` (sub-agents / team modes):

- **Header** — Plan, Mode (inline / sub-agents / team), Status (complete / partial / failed)
- **Tasks** — per-task status table (DONE, BLOCKED, SKIPPED)
- **Post-implementation** — statuses for validate, document, format
- **Concerns** — concerns raised by sub-agents (when DONE_WITH_CONCERNS)
- **Validation** — result of each command (lint, tests, build)
- **Changes summary** — files, actions, descriptions
- **Commits** — hashes and messages in chronological order

## Status protocol

Sub-agents return a status after running a task (see `reference/status-protocol.md`):

| Status               | Meaning                      | Orchestrator action                                 |
| -------------------- | ---------------------------- | --------------------------------------------------- |
| `DONE`               | Task complete, verify passes | Commit, next task                                   |
| `DONE_WITH_CONCERNS` | Complete but with concerns   | Commit, record concerns in the report               |
| `NEEDS_CONTEXT`      | Missing information          | Add context, re-dispatch (max 1 retry)              |
| `BLOCKED`            | Cannot proceed               | Skip dependent tasks, keep running independent ones |

## Sub-agents

| Agent               | Model  | Role                                                                                      |
| ------------------- | ------ | ----------------------------------------------------------------------------------------- |
| `task-investigator` | sonnet | Maps the change area: entry points, patterns, tests, risks (Plan phase)                   |
| `plan-architect`    | opus   | Designs the change, decomposes into tasks, builds the DAG, recommends parallel/sequential |
| `task-executor`     | opus   | Runs one task: implementation, verification, commit                                       |
| `task-reviewer`     | sonnet | Combined spec compliance + code quality review in one pass                                |
| `validator`         | haiku  | Lint, type-check, tests, build + auto-fix                                                 |
| `formatter`         | haiku  | Detects the formatter and runs it on changed files                                        |
| `doc-updater`       | sonnet | Updates README, CHANGELOG, JSDoc/TSDoc (Document phase — opt-in)                          |
| `code-polisher`     | opus   | Simplifies code: over-engineering, duplication (used by `/fix`)                           |

## Example

```
/yoke:do https://github.com/org/repo/issues/42
```

## Connections

```
/yoke:do → /yoke:review → /yoke:gp → /yoke:pr
```

`/do` plans and executes; `/review` prepares the report. Upstream, `/grill`,
`/grill-docs`, `/prd`, and `/issues` formalise _what_ to build before `/do`.
