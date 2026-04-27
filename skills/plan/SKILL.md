---
name: plan
description: >-
  Build an implementation plan from a task file. Triggered when the user writes
  "build a plan", "make a plan", "plan", "plan the implementation", "prepare a plan",
  or passes a path to a task file and asks to plan execution.
---

# Build an implementation plan

You are the orchestrator. Coordinate sub-agents and talk to the user.

Delegate codebase investigation and design through the Agent tool:

- Exploration → `agents/plan-explorer.md`
- Design → `agents/plan-designer.md`
- Plan review → `agents/plan-reviewer.md`

The output is a plan file that `/yoke:do` can execute autonomously.

---

## Input

`$ARGUMENTS` — path to a task file, for example `docs/ai/86-black-jack-page/86-black-jack-page-task.md`

If the path is missing — request it from the user.

---

## Phases

### Phase 1 — Load

**1.** Read the task file in full.

**2.** Extract:

- `TASK_TITLE` — title
- `TASK_SLUG` — from the `Slug` field in the task file
- `TASK_COMPLEXITY` — from the `Complexity` field
- `TASK_TYPE` — frontend / general (if not stated — infer from content)
- `REQUIREMENTS` — list of requirements
- `CONSTRAINTS` — constraints
- `VERIFICATION` — verification criteria
- `MATERIALS` — links and paths

**3.** Check that Task, Context, and Requirements sections are present.
If Task, Context, or Requirements is missing — tell the user and stop.

**4.** Extract `TICKET_ID` from TASK_SLUG (per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`).

**Transition:** task file loaded, TICKET_ID determined → Phase 2.

---

### Phase 2 — Explore

Goal: determine _how_ to implement the task. The task file describes _what_ and _where_.
plan-explorer looks for _how_: which files to create, which patterns to reuse,
which integration points to touch.

**Launch plan-explorer through the Agent tool:**

Prompt to the agent:

```
Based on the task file: [paste TASK_TITLE and the full Context section from the task file]

Requirements:
[paste REQUIREMENTS]

Constraints:
[paste CONSTRAINTS]

Investigate the codebase with an implementation focus:

1. For each requirement — which files must be created or changed?
   Path + what exactly to change/add.
2. Implementation patterns: find 1–2 similar implementations in the project.
   For each: path, structure, what to reuse.
3. Shared state and dependencies: which files will several requirements touch?
   Build an intersection matrix.
4. Order: what must be ready before what? Are there natural phases?
5. Estimated scope: for each change block — rough size (S/M/L).

At the end — the essential file list for the design phase.
```

**Transition:** findings received → Phase 3.

---

### Phase 3 — Design

Goal: make architectural decisions and decompose the task into tasks.

**Launch plan-designer through the Agent tool:**

Prompt to the agent:

```
Task: [TASK_TITLE]
Complexity: [TASK_COMPLEXITY]

plan-explorer findings:
[paste findings in full]

Requirements from the task file:
[paste REQUIREMENTS]

Constraints from the task file:
[paste CONSTRAINTS]

Design the implementation plan:

1. DESIGN DECISIONS — for each non-obvious choice:
   - What you are deciding (one sentence)
   - Chosen option + why
   - Rejected option + why not
   Decide from codebase patterns.
   If the answer is in the code — use it, don't ask the user.

2. DECOMPOSITION — split into tasks:
   - Each task: title, files, depends_on, estimated scope (S/M/L)
   - A task = atomic commit. One concern, testable in isolation.
   - Granularity: 2–10 minutes of agent work per task.

3. FILE INTERSECTION MATRIX — for each task pair:
   - Any shared files? Which?
   - If yes — mark as a sequential dependency.

4. EXECUTION ORDER — ordering:
   - Which tasks can run in parallel (no shared files, no depends_on)?
   - Which are strictly sequential?
   - Sketch a text DAG.

5. IMPLEMENTATION QUESTIONS — from 3 to 5. About HOW only:
   architecture, patterns, implementation trade-offs.
   Exclude questions already answered in the task file.

   Good: "Which pattern — Strategy or Template Method?"
   Bad: "What fields does the form need?" (that's scope → task)
```

**Interactive clarifications:**

If plan-designer produced IMPLEMENTATION QUESTIONS — ask the user
via AskUserQuestion, 1–4 at a time.

For each question:

- 2–4 answer options with explanations
- Recommended option first, labeled `(Recommended)`
- The user may pick "Other" for free-form input

After the answers — update design decisions and decomposition
with the chosen options. Fold the answers into the plan.

If there are no questions — skip this step.

**Transition:** design decisions + decomposition + DAG ready, questions resolved → Phase 4.

---

### Phase 4 — Route

Pick the execution strategy via the table in `reference/routing-rules.md`.

**Inputs for routing:**

- `TASK_COMPLEXITY` from the task file
- Task count from decomposition
- File intersection matrix from architect
- Presence of cross-layer tasks (frontend + backend + tests in separate tasks)

**Record the result:**

- `MODE` = inline | sub-agents | agent-team
- `PARALLEL` = true | false
- `PARALLEL_GROUPS` = which tasks can run in parallel (when parallel=true)
- `REASONING` = one sentence explaining the mode

**Before writing — check consistency:**

- [ ] Every requirement covered by at least one task
- [ ] Every depends_on references an existing task
- [ ] No circular dependencies
- [ ] The last task is Validation
- [ ] Verification criteria from the task file are reflected in task-level Verify

**Transition:** routing decided, plan consistent → Phase 5.

---

### Phase 5 — Review

Launch a subagent to review the plan.

**Launch plan-reviewer through the Agent tool:**

Pass:

- Design decisions
- Decomposition (all tasks with What, How, Files, Context, Verify)
- Execution order
- Requirements and Constraints from the task file

The agent is defined in `agents/plan-reviewer.md`.

**Handle the result:**

- Approved → Phase 6 (Write)
- Issues → fix them, re-dispatch (max 5 iterations)
- 5 iterations without approval → write the plan as is, add unresolved issues as a separate section

**Transition:** plan passed review → Phase 6.

---

### Phase 6 — Write

**1.** Read `reference/plan-format.md` — the output file format.

**2.** Write the file `docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md` using the format from plan-format.md. Include:

- Every design decision with reasoning
- Every task with files, dependencies, scope
- Routing decision
- Execution order (DAG)
- Verification criteria from the task file

**3. Self-check the prose** — re-read the file. Edit inline if any sentence violates:

- Active voice — "the agent reads the file"
- Positive form — "Add tests" (not "Don't forget tests")
- Concrete language — files, lines, function names
- No needless words
- Imperative mood

**4. Auto-commit the artifact.**

Check: is `docs/ai/` in `.gitignore`? If yes — tell the user and skip the commit.

Otherwise commit per the convention in `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`:

```bash
git add docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md
git commit -m "TICKET docs(SLUG): add implementation plan"
```

Format: `TICKET docs(SLUG): add implementation plan` (NO colon after ticket).
Example: `#86 docs(86-black-jack-page): add implementation plan`.
Commit only the plan artifact, no other files.

**5.** Tell the user the file path.

**Transition →** Phase 7.

---

### Phase 7 — Complete

Report the plan file path and run the finishing loop.

Send a notification:
`bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill plan --phase Complete --slug "$TASK_SLUG" --title "Plan ready" --body "docs/ai/$TASK_SLUG/$TASK_SLUG-plan.md"`

**Loop:**

Offer 3 options through AskUserQuestion:

1. **Run /yoke:do (Recommended)** — auto-handoff to execution
2. **Review via revdiff** — interactive review of the plan file
3. **Finish** — exit

**Handle the choice:**

- **Run /yoke:do:** call the Skill tool with `/yoke:do` and the argument `docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md`. Exit the loop.
- **Review via revdiff:** After revdiff closes, continue with the following steps:
  1. Call the Skill tool with `/revdiff` and the argument `--only docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md`.
  2. If the Skill return is non-empty, apply the returned annotations to the plan file and overwrite `docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md`. If the return is empty, skip this step.
  3. Return to the "Offer 3 options" step above.
     If the plugin is missing — print `Install the revdiff plugin:` followed by `  /plugin marketplace add umputun/revdiff` and `  /plugin install revdiff@umputun-revdiff`, then return to the "Offer 3 options" step above.
- **Finish:** report the file path. Exit the loop.

---

## Rules

- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
- Answer is in the code — decide and write the plan immediately.
- Each task is one atomic commit. Larger than "create file" + "add import", smaller than a full feature.
- Context isolation: each task contains only the files and context it needs.
- Routing — based on task count and file-intersection matrix.
- One task — one plan file, no sub-plans.
- Active voice. Concrete files and lines instead of abstractions.
