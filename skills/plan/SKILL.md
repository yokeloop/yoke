---
name: plan
description: >-
  Build an implementation plan from a task file. Triggered when the user writes
  "build a plan", "make a plan", "plan", "plan the implementation", "prepare a plan",
  or passes a path to a task file and asks to plan execution.
---

# Build an implementation plan

You are the orchestrator. Coordinate sub-agents and talk to the user.

Delegate plan design through the Agent tool:

- Plan architecture → `agents/plan-architect.md`

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
If any of Task, Context, or Requirements is missing, tell the user and stop.

**4.** Extract `TICKET_ID` from TASK_SLUG (per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`).

**Transition:** task file loaded, TICKET_ID determined → Phase 2.

---

### Phase 2 — Design

Goal: make architectural decisions and decompose the task into atomic, ordered tasks.

**Launch plan-architect through the Agent tool.** The agent is defined in `agents/plan-architect.md`.

Prompt to the agent:

```
Task: [TASK_TITLE]
Complexity: [TASK_COMPLEXITY]
Type: [TASK_TYPE]

Task file Context section:
[paste the full Context section from the task file]

Requirements:
[paste REQUIREMENTS]

Constraints:
[paste CONSTRAINTS]

Investigate the codebase, design the implementation, decompose into tasks,
build the file intersection matrix and DAG, recommend a routing mode, and
self-check before returning. Output the full plan plus the self-check verdict.

Surface IMPLEMENTATION QUESTIONS only when the answer is not in the code AND
the answer changes decomposition or architecture. Max 3.
```

**Interactive clarifications:**

If plan-architect produced IMPLEMENTATION QUESTIONS — ask the user
via AskUserQuestion, 1–4 at a time.

For each question:

- 2–4 answer options with explanations
- Recommended option first, labeled `(Recommended)`
- The user may pick "Other" for free-form input

After the answers — update design decisions and decomposition
with the chosen options. Fold the answers into the plan.

Skip this step when there are no questions.

**Routing rules** (the architect picks one; sanity-check the choice):

- **inline** — 1-2 tasks, no shared files, all sequential.
- **sub-agents** — 3+ tasks with parallel groups, single codebase. Default for medium / complex plans.
- **agent-team** — 2+ layers (frontend + backend + tests in separate tasks) with strong coordination. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; falls back to `sub-agents` if the flag is unset.

For the full 9-row decision matrix and edge cases, see `reference/routing-rules.md` — supplementary, optional.

**Record the architect's result:**

- `MODE` = inline | sub-agents | agent-team
- `PARALLEL` = true | false
- `PARALLEL_GROUPS` = which tasks can run in parallel (when parallel=true)
- `REASONING` = the architect's one-sentence explanation

The architect's self-check covers requirements coverage, dependency validity, and Verify concreteness. Trust it; re-dispatch only when the self-check fails.

**Transition:** plan ready → Phase 3.

---

### Phase 3 — Write

**1.** Write the file `docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md` using this format:

```markdown
# <Task title> — implementation plan

**Task:** <path to task file>
**Complexity:** <trivial | simple | medium | complex>
**Mode:** <inline | sub-agents | agent-team>
**Parallel:** <true | false>

## Design decisions

### DD-1: <What you're deciding>

**Decision:** <chosen option>
**Rationale:** <why, with a code reference>
**Alternative:** <rejected option — why not>

## Tasks

### Task 1: <title>

- **Files:** `src/path/file.ts` (create), `src/path/other.ts:45-60` (edit)
- **Depends on:** none
- **Scope:** S
- **What:** <1–2 sentences — what to do>
- **How:** <key implementation steps — concrete, not "add validation">
- **Context:** <files and lines for the agent to read>
- **Verify:** `<project test command>` — green

### Task N: Validation

- **Files:** —
- **Depends on:** all
- **Scope:** S
- **What:** Run full validation: lint, types, tests, build
- **Context:** —
- **Verify:** `<project lint> && <project type-check> && <project test> && <project build>` — all green

## Execution

- **Mode:** <inline | sub-agents | agent-team>
- **Parallel:** <true | false>
- **Reasoning:** <one sentence>
- **Order:**
  Group 1 (parallel): Task 1, Task 2
  ─── barrier ───
  Group 2 (sequential): Task 3 → Task 4

## Verification

<Criteria from the task file — unchanged>

## Materials

<From the task file — unchanged>
```

**Format rules:**

- The last task is always Validation. Run the full test suite, lint, type-check, build.
- Every task contains Verify — a concrete command or observable behavior.
- Context in a task — minimally sufficient. Concrete paths and lines, no "read the whole project".
- Design decisions numbered (DD-1, DD-2…) for referencing.
- Mode and Parallel — required header fields. `/yoke:do` reads them directly.
- Use commands from `.claude/yoke-context.md` Commands section, or auto-detect from project config files.

For the full template with annotations and barrier/parallel grammar, see `reference/plan-format.md` — supplementary, optional.

**Include in every plan file:**

- Every design decision with reasoning
- Every task with files, dependencies, scope
- Routing decision
- Execution order (DAG)
- Verification criteria from the task file

**2. Self-check the prose** — re-read the file. Edit inline if any sentence violates:

- Active voice — "the agent reads the file"
- Positive form — "Add tests" (not "Don't forget tests")
- Concrete language — files, lines, function names
- No needless words
- Imperative mood

**3. Auto-commit the artifact.**

Check: is `docs/ai/` in `.gitignore`? If yes — tell the user and skip the commit.

Otherwise commit per the convention in `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`:

```bash
git add docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md
git commit -m "TICKET docs(SLUG): add implementation plan"
```

Format: `TICKET docs(SLUG): add implementation plan` (NO colon after ticket).
Example: `#86 docs(86-black-jack-page): add implementation plan`.
Commit only the plan artifact, no other files.

**4.** Tell the user the file path.

**Transition →** Phase 4.

---

### Phase 4 — Complete

Report the plan file path and run the finishing loop.

Send a notification:
`bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill plan --phase Complete --slug "$TASK_SLUG" --title "Plan ready" --body "docs/ai/$TASK_SLUG/$TASK_SLUG-plan.md"`

**Offer next step:**

Offer 3 options through AskUserQuestion:

1. **Run /yoke:do (Recommended)** — auto-handoff to execution
2. **Review via revdiff** — interactive review of the plan file
3. **Finish** — exit

**Handle the choice (one-shot, no loop):**

- **Run /yoke:do:** call the Skill tool with `/yoke:do` and the argument `docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md`. Exit.
- **Review via revdiff:** call the Skill tool with `/revdiff` and the argument `--only docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md`. If the return is non-empty, apply the annotations to the plan file and overwrite. Then exit. (For another pass, the user invokes `/revdiff` manually.)
  If the plugin is missing — print `Install the revdiff plugin:` followed by `  /plugin marketplace add umputun/revdiff` and `  /plugin install revdiff@umputun-revdiff`, then exit.
- **Finish:** report the file path. Exit.

---

## Rules

- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
- Answer is in the code — decide and write the plan immediately.
- Each task is one atomic commit. Larger than "create file" + "add import", smaller than a full feature.
- Context isolation: each task contains only the files and context it needs.
- Routing — based on task count and file-intersection matrix.
- One task — one plan file, no sub-plans.
- Active voice. Concrete files and lines instead of abstractions.
