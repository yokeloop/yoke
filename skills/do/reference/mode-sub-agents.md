# Mode: sub-agents

The heavy pipeline for executing a **single issue or task** end to end. The router (`skills/do/SKILL.md`) delegates here when it picks sub-agents mode.

You are the orchestrator. You coordinate sub-agents through the Agent tool and talk to the user at most once — at the cold-start confirmation gate.

**Flow:**

```
0. Resolve input → read flow map (finish.md §1) + derive SLUG + TICKET_ID (back-compat: existing plan → skip Plan)
1. Plan         → investigate + architect → write <slug>-plan.md
2. Confirm      → cold start only: AskUserQuestion confirm / adjust / cancel
   Worktree     → enter per finish.md §2 (after Confirm on cold start; else right after Phase 0, before code)
3. Execute      → task-executor per task + review loop, one commit per task
4. Validate     → validator + formatter in parallel
5. Document     → opt-in (--update-docs or update_docs: true)
6. Finalize     → write <slug>-report.md (finish block appended in Finish)
7. Finish       → finish.md §3-§7: per-repo PR(s) + ticket comment + run-level notify
```

Track every phase in TodoWrite.

**Status semantics, review loop, and parallel dispatch live in `reference/status-protocol.md`. Read it before Execute; do not duplicate its rules here.**

---

## Phase 0 — Resolve input & slug

Accept a single input from the router: an issue URL, a `<slug>`, a `*-task.md` path, or a `*-plan.md` path.

**Read the flow map (`reference/finish.md` §1).** Run the flow-map read once at the project root. It yields the linked repos, their finish policies, the tracker, and the commit language. Hold it for the worktree entry, Execute dispatch, and the finish.

**1.** Derive `SLUG` and `TICKET_ID` per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.

- Issue URL → fetch the issue, build the slug from its number + title.
- `<slug>` → use directly.
- `*-task.md` or `*-plan.md` path → take the slug from the `.yoke/ai/<slug>/` directory in the path.

**2. Back-compat — existing plan file.** If the input is an existing `*-plan.md` path:

- **Skip the Plan phase entirely.** A handed-in plan is already agreed, so the confirmation pause is skipped too.
- Read the file. Extract `MODE` from `**Mode:**`, `PARALLEL` from `**Parallel:**`, the tasks, the execution order, and the verification section.
- If `**Mode:**` is `agent-team`, the caller wanted team execution — **team mode is handled by `mode-team.md`**, not here. Hand back to the router rather than running the team pipeline in this body.
- Otherwise enter the worktree now (see below), then jump straight to **Phase 3 — Execute**.

**3.** When the input is not an existing plan, continue to Phase 1.

**Worktree entry (`reference/finish.md` §2).** Isolate before any code change. The ordering follows the pause: on **cold start** (Phase 2 will fire) enter the worktree **after** the plan is confirmed, so an abandoned pause leaves no stray worktree; when the pause is skipped (a `grill` / `grill-docs` session already agreed the plan, or a `*-plan.md` was handed in) enter it here, right after input resolution. Do not restate the ladder — finish.md §2 owns the default-branch / feature-branch / multi-repo cases.

Pass `SLUG` and `TICKET_ID` to every sub-agent for commits.

**Transition:** input resolved → Phase 1 (or worktree + Execute on back-compat).

---

## Phase 1 — Plan (absorbed from task/plan)

Build the plan file before touching code. Two sub-agents, in sequence.

**1. Investigate.** Dispatch `agents/task-investigator.md` to map the change area: entry points (`path:line`), patterns to reuse, tests in the area, integration risks, reusable building blocks.

Prompt with the resolved input (issue body / task text), the title, and any constraints. Collect the investigator's report.

**2. Architect.** Dispatch `agents/plan-architect.md` to design the implementation, decompose into atomic tasks, build the file-intersection matrix and DAG, recommend the routing mode, and self-check.

Pass:

```
Task: <title>
Complexity: <if known>
Type: frontend | general

Investigation report:
<paste the task-investigator output>

Requirements:
<requirements from the input>

Constraints:
<constraints>

Investigate, design, decompose, build the DAG, recommend parallel/sequential,
and self-check before returning. Output the full plan plus the self-check verdict.
Surface IMPLEMENTATION QUESTIONS only when the answer is not in the code AND it
changes decomposition or architecture. Max 3.
```

**Interactive clarifications:** if plan-architect raises IMPLEMENTATION QUESTIONS, fold them into the confirmation gate in Phase 2 — do **not** add a separate pause here. (Recommended-first options, 1–4 at a time.)

**Auto-detect parallel/sequential.** Trust the architect's routing call, which reuses the complexity × file-intersection logic: tasks with no shared files and no `depends_on` run in parallel groups; shared files or dependencies force sequence. Record `PARALLEL` and `PARALLEL_GROUPS`.

**3. Write the plan file** to `.yoke/ai/<SLUG>/<SLUG>-plan.md` using the plan-file format in `reference/plan-format.md`:

- `**Mode:**` and `**Parallel:**` header fields (required — Execute reads them).
- `## Design decisions` — numbered DD-1, DD-2…, each with Decision / Rationale (code reference) / Alternative.
- `## Tasks` — each with **Files**, **Depends on**, **Scope**, **What**, **How**, **Context**, **Verify**. The last task is always Validation (depends on: all).
- `## Execution` — Mode, Parallel, Reasoning, and the **Order** (parallel groups, barriers, sequence).
- `## Verification` — criteria from the input, unchanged.

Self-check the prose: active voice, imperative mood, concrete files and lines, no needless words.

Auto-commit the plan artifact with the escape-hatch — check: is `.yoke/` in `.gitignore`? If yes, tell the user and skip the commit. Otherwise `git add .yoke/ai/<SLUG>/<SLUG>-plan.md` and commit `TICKET docs(SLUG): add implementation plan` (NO colon after the ticket).

**Transition:** plan written → Phase 2.

---

## Phase 2 — Confirm (cold-start pause)

The confirmation gate, and the run's only pause. It fires **on cold start only** — a bare ticket with no prior discussion.

**Skip the pause when the plan is already agreed:**

- the session already holds a `grill` / `grill-docs` session for this task, or
- the user handed in an approved plan (a `*-plan.md` input — Phase 0 already skips planning for it).

When skipped, the worktree was entered in Phase 0; go straight to Phase 3.

**On cold start, pause before any code change.** Summarize for the user:

- Task title and SLUG.
- Detected `MODE` and `PARALLEL` with the architect's one-sentence reasoning.
- The task list and execution order (parallel groups / barriers).
- Any IMPLEMENTATION QUESTIONS from the architect.

Ask via **AskUserQuestion**:

1. **Confirm and execute (Recommended)** — proceed with the plan as written.
2. **Adjust** — capture the user's changes (mode, parallelism, task edits, answers to open questions), update `.yoke/ai/<SLUG>/<SLUG>-plan.md`, re-commit the artifact, and re-present.
3. **Cancel** — stop. Leave the plan file in place; make no code changes.

This guard catches a wrong auto-detected mode. After the user confirms, enter the worktree per `reference/finish.md` §2 — **not before**, so a cancelled pause leaves no stray worktree.

**Transition:** user confirms (or pause skipped) → worktree → Phase 3.

---

## Phase 3 — Execute

Read `reference/status-protocol.md` — status handling, review loop, parallel dispatch.

**Multi-repo.** When the flow map (Phase 0) lists more than one repo, each task carries the repo it touches; dispatch it against that repo's checkout, and the finish loops every touched repo per `reference/finish.md` §4.

### Dispatch by execution order

Read the Order from the plan:

- **Parallel group** → dispatch all task executors in the group simultaneously via the Agent tool (single message, multiple tool uses). After the executor wave returns, dispatch their task-reviewers in parallel for the same set.
- **Sequential** → dispatch one at a time in dependency order.
- **Barrier** → wait for all tasks in the group to finish before the next group.

Without parallel groups, dispatch sequentially.

### For each task

```
1. Build the prompt for the sub-agent:
   - Read agents/task-executor.md
   - Substitute: task.What, task.How, task.Files, task.Context, CONSTRAINTS, task.Verify
   - Construct COMMIT_MESSAGE in the format `TICKET type(SLUG): description`
     Example: `#86 feat(86-black-jack-page): add game page with basic layout`
     NO colon after the ticket. SLUG is required.
   - Pass the full task text, not the path to the plan file

2. Dispatch agents/task-executor.md via the Agent tool. Wait for the result.

3. Handle the status (per reference/status-protocol.md):
   - DONE / DONE_WITH_CONCERNS → run the Review Loop
   - NEEDS_CONTEXT → add context, re-dispatch
   - BLOCKED → evaluate, re-dispatch with a stronger model or record it

4. Review Loop (for DONE / DONE_WITH_CONCERNS):
   - Dispatch agents/task-reviewer.md
     - Pass: task requirements, implementer report, BASE_SHA, HEAD_SHA
     - One pass covers spec compliance and code quality.
     - ✅ Approved → task complete
     - ❌ Critical/Important issues → implementer fixes → re-dispatch (max 2 iterations)
     - Minor only → record, do not block

5. Guarantee a commit:
   - Check `git status` for uncommitted changes
   - If any exist — commit per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`
   - Record the commit hash for the report

6. Mark in TodoWrite: [x]
```

**On BLOCKED:** skip only the tasks that depend on the blocked one; run the rest. Send a notification:
`bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type ALERT --skill do --title "Task blocked" --body "<block reason and number of skipped tasks>"`

Save the list of changed and created files for Phases 4–6.

**When zero files changed** (all tasks BLOCKED/SKIPPED): skip Phase 5 (Document); run Phase 4 only if changes exist; then Finalize with status failed → Finish (skip the push/PR when nothing changed).

**Transition:** tasks done (or BLOCKED) → Phase 4.

---

## Phase 4 — Validate (validator + formatter in parallel)

Dispatch `agents/validator.md` AND `agents/formatter.md` via the Agent tool in a **single message** with two tool uses — they share files but do not depend on each other's output. Each commits its own fixes.

### 4a. Validator

Prompt — from `agents/validator.md`. Pass: files changed in Phase 3, SLUG, TICKET_ID, CONSTRAINTS from the plan. The sub-agent reads commands from project config, runs lint/type-check/test/build, fixes failures (one attempt), commits, returns each command's result.

### 4b. Formatter

Prompt — from `agents/formatter.md`. Pass: files changed in Phase 3, SLUG, TICKET_ID. The sub-agent picks the formatter, runs it on the files, commits.

After both return, mark Validate and Format in TodoWrite: [x] [x].

**Transition →** Phase 5.

---

## Phase 5 — Document (opt-in)

**Skip this phase when `UPDATE_DOCS=false`** (the default). Set `UPDATE_DOCS=true` only when `--update-docs` is in the input OR the plan's frontmatter sets `update_docs: true`. When skipped, mark Documentation as skipped in TodoWrite and proceed to Phase 6.

When `UPDATE_DOCS=true`, dispatch `agents/doc-updater.md`. Pass: changed files, SLUG and task title, requirements from the plan. The sub-agent decides what to update (README on API changes / new features, CHANGELOG when present, JSDoc/TSDoc for new exported functions). **Extend existing documentation.**

After completion, commit per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md` and mark in TodoWrite: [x].

**Transition →** Phase 6.

---

## Phase 6 — Finalize the report

Write `.yoke/ai/<SLUG>/<SLUG>-report.md` directly via the Write tool using the **Report template** from `reference/report-format.md`.

Fill it from data the orchestrator already holds: task statuses (DONE / DONE_WITH_CONCERNS / BLOCKED / SKIPPED), commit hashes, concerns text, blocked reasons, post-implementation statuses, validation command results, FILES_CHANGED. Run `git log origin/main..HEAD --oneline` to collect commits.

The finish block — the per-repo PR table from `reference/finish.md` §7 — is appended to this report during the finish (Phase 7), once the PR URLs exist. **No notification fires here:** the single run-level notify belongs to the finish (finish.md §7).

**Auto-commit the report with the escape-hatch:** Check: is `.yoke/` in `.gitignore`? If yes — tell the user and skip the commit. Otherwise `git add .yoke/ai/<SLUG>/<SLUG>-report.md` and commit `TICKET docs(SLUG): add execution report` (NO colon after the ticket). Example: `#86 docs(86-black-jack-page): add execution report`.

**Transition →** Phase 7.

---

## Phase 7 — Finish (drive to PR)

Execute the finish contract, `reference/finish.md` §3-§7, then exit — no AskUserQuestion. The run is fire-and-return: the developer returns on the notification and decides on GitHub.

- **Per-repo finish (§3).** For each touched repo, follow its `finish` policy from the flow map: `pr` → commit remaining run artifacts, push the branch, create/update the PR via the pr skill's mechanics; `direct-push` → push to the default branch, publish, bump consumers.
- **Multi-repo order (§4).** Libraries (`direct-push`) first, then apps; aggregate every PR URL and published version.
- **Ticket comment (§5).** When the tracker ≠ `none`, post one short comment (what was done + PR links) to the task's ticket.
- **Report finish block (§7).** Append the per-repo PR table to `.yoke/ai/<SLUG>/<SLUG>-report.md` and commit it.
- **Run-level notify (§7).** Send the single STAGE_COMPLETE notification with the PR URL(s) as the payload.
- **Print the PR link(s)** and stop. Do not suggest review / gca / gp — the run ends at the PR. Do not auto-invoke another skill and do not call AskUserQuestion.

`do` never merges — the sole exception is the straight-to-main override in `reference/finish.md` §6.

---

## Rules

- **At most one pause.** The Phase 2 confirmation, and only on cold start. Every other phase runs without stops.
- **Commits by convention.** Format and ticket ID — from `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- **Worktree, not the current directory.** Isolate before any code change per `reference/finish.md` §2; one worktree per touched repo.
- **Never merge.** The run finishes at the PR; the sole exception is the straight-to-main override in `reference/finish.md` §6.
- **Context isolation.** A sub-agent receives only its own task text, not the whole plan.
- **Review after each task.** Mandatory, per `reference/status-protocol.md`.
- **TodoWrite.** Mark each step immediately upon completion.
- **On BLOCKED, keep going.** Stop only the dependent branch.
- **All artifacts under `.yoke/ai/`.** Plan and report both live in `.yoke/ai/<SLUG>/`.
- **CLI output.** Run long-output commands (formatter, lint, build, test) with `2>&1 | tail -20`.
- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
