# Routing Rules

Rules for picking the execution strategy in Phase 3 (Route).

---

## Decision table

Apply top to bottom — first match wins.

| #   | Complexity | Tasks | File intersections  | Cross-layer | → Mode       | → Parallel |
| --- | ---------- | ----- | ------------------- | ----------- | ------------ | ---------- |
| 1   | trivial    | 1-2   | —                   | —           | `inline`     | false      |
| 2   | simple     | 1-2   | none                | no          | `inline`     | false      |
| 3   | simple     | 2-3   | none                | no          | `sub-agents` | true       |
| 4   | medium     | 3+    | none between groups | no          | `sub-agents` | true       |
| 5   | medium     | 3+    | some                | no          | `sub-agents` | mixed\*    |
| 6   | medium     | 3+    | any                 | yes         | `agent-team` | true       |
| 7   | complex    | any   | none between groups | no          | `sub-agents` | true       |
| 8   | complex    | any   | any                 | yes         | `agent-team` | true       |
| 9   | complex    | any   | heavy               | any         | `agent-team` | false      |

\*mixed = parallel groups where there are no intersections, sequential between groups that share files.

---

## Definitions

**File intersection** — two tasks modify the same file.

- `none` = no task pair shares files
- `some` = intersections exist, but independent groups can be carved out
- `heavy` = most tasks share files

**Cross-layer** — the plan contains tasks from different layers:

- frontend (React, Vue, CSS, components)
- backend (API, services, DB)
- infrastructure (config, CI, deploy)
- tests (a standalone test task, not tests bundled into a feature task)

2+ layers _and 2+ tasks in each_ → cross-layer = yes.
One backend task + one test task → cross-layer = no (tests alongside a feature are normal).

---

## Mode: inline

Sequential execution in the current thread without sub-agents.

**When:** simple tasks, 1–3 files, one module.
**Upside:** minimal overhead, full context in one window.
**Risk:** session blocked.

---

## Mode: sub-agents

Each task launches a dedicated sub-agent via the Task tool.
When parallel=true, parallel tasks start simultaneously.

**When:** 3+ tasks, independent groups exist, single codebase.
**Upside:** parallelism, context isolation, every agent focused.
**Risk:** merge conflicts on parallel edits of shared files.

For sub-agents:

- `isolation: worktree` when parallel=true
- `isolation: none` when parallel=false (sequential)

---

## Mode: agent-team

A full agent team coordinated via TeamCreate.
Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

**When:** cross-layer tasks, coordination between parts is required.
**Upside:** agents talk to each other, share findings.
**Risk:** high token cost, coordination overhead.

Team structure:

- **Lead** — coordinator (the current session)
- **Teammates** — one per layer (frontend, backend, tests)
- Shared task list for coordination

**Fallback:** agent-team unavailable (no feature flag) → degrade to sub-agents.

---

## Parallel groups

When mode=sub-agents and parallel=true, define the groups:

```
Group 1 (parallel): Task 1, Task 2    # no shared files
Group 2 (parallel): Task 3, Task 4    # no shared files
─── barrier ───
Group 3 (sequential): Task 5          # depends on Group 1 + 2
```

Barrier = the next group starts after every task in the current one finishes.

---

## How to record routing in the plan file

```markdown
## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** 5 tasks, 2 parallel groups with no intersections, all in one codebase
- **Order:**
  Group 1 (parallel): Task 1, Task 2
  Group 2 (sequential): Task 3 → Task 4
  Group 3 (sequential): Task 5
```
