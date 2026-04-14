# Skill /task

Defines a task for AI implementation from a ticket or free-form description. Explores the codebase via sub-agents,
analyzes the architecture, asks clarifying questions, and produces a task file with context, requirements, and constraints.
The output is a task file that `/sp:plan` turns into an implementation plan.

## Input

`$ARGUMENTS` — ticket URL (GitHub Issues, YouTrack, Jira) and/or a free-form task description.

```
/sp:task https://github.com/owner/repo/issues/86
/sp:task add dark theme to settings
```

## Phases

| Phase | Name            | What happens                                                                                           |
| ----- | --------------- | ------------------------------------------------------------------------------------------------------ |
| 1     | **Parse**       | Fetch ticket contents, extract materials, form task-slug and TICKET_ID                                 |
| 2     | **Investigate** | Sub-agents explore the codebase (task-explorer) and architecture (task-architect). Strictly sequential |
| 3     | **Synthesize**  | Apply 5 dimensions to findings, determine type (frontend/general), form clarifying questions           |
| 4     | **Write**       | Write the task file from examples (simple/complex), copyedit via sub-agent (Elements of Style)         |
| 5     | **Commit**      | Auto-commit the artifact: `TICKET docs(SLUG): add task definition`                                     |
| 6     | **Complete**    | Completion loop: run /sp:plan (recommended) / review via plannotator / finish                          |

## Output

File `docs/ai/<slug>/<slug>-task.md` with the following structure:

- **Header** — Slug, Ticket, Complexity (trivial/simple/medium/complex), Type (frontend/general)
- **Task** — one sentence: what exactly to do
- **Context** — 4 subsections: area architecture, files to change, patterns to reuse, tests
- **Requirements** — concrete, verifiable requirements
- **Constraints** — what not to change, approaches to avoid, risks from findings
- **Verification** — commands with expected results, edge cases
- **Materials** — links and file paths from input

## 5 Synthesize dimensions

| Dimension           | Check question                                                                |
| ------------------- | ----------------------------------------------------------------------------- |
| Intent Clarity      | Two different developers read the Task and arrive at the same implementation? |
| Scope Boundaries    | What's definitely in scope, and what's out?                                   |
| Context Anchoring   | The implementer knows exactly what's needed — no more, no less?               |
| Acceptance Criteria | The implementer can verify each criterion without running the whole project?  |
| Reuse Opportunities | Which existing components can be reused?                                      |

## Sub-agents

| Agent            | Model  | Role                                                                   |
| ---------------- | ------ | ---------------------------------------------------------------------- |
| `task-explorer`  | sonnet | Codebase exploration: files, patterns, tests, dependencies             |
| `task-architect` | sonnet | Architecture analysis: patterns, integration points, risks, trade-offs |

## Example

```
/sp:task https://github.com/org/repo/issues/112
```

Result: `docs/ai/112-password-reset-email/112-password-reset-email-task.md`

## Connections

```
/sp:task → /sp:plan → /sp:do → /sp:review
```

`/task` defines the task. `/plan` builds the implementation plan. `/do` executes the plan.
