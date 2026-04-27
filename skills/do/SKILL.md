---
name: do
description: >-
  Execute a task per plan. Triggered when the user writes "execute", "do",
  "run the plan", "implement", or passes a path to a plan file and asks to
  execute it.
---

# Execute task per plan

You are the orchestrator. You coordinate sub-agents.

Delegate each working phase to a sub-agent via the Agent tool:

- Implementation → `agents/task-executor.md`
- Task review → `agents/task-reviewer.md`
- Polish → `agents/code-polisher.md`
- Validate → `agents/validator.md`
- Document → `agents/doc-updater.md`
- Format → `agents/formatter.md`

Work from start to finish without stops or confirmations.

**Principle:** the developer kicks it off and walks away, returning on notification.

---

## Input

`$ARGUMENTS` — path to the plan file, e.g. `docs/ai/86-black-jack-page/86-black-jack-page-plan.md`

If there is no path — ask the user.

---

## Pipeline

7 stages. Each one is tracked in TodoWrite.

```
1. Parse        → read the plan, create todos
2. Execute      → dispatch sub-agents + spec review + quality review
3. Polish       → simplify and clean up code
4. Validate     → dispatch validator sub-agent
5. Document     → update documentation
6. Finalize     → format + report
7. Complete     → review / revdiff / finish
```

---

## Phase 1 — Parse

**1.** Read the plan file in full.

**2.** Extract:

- `SLUG` — from the path (`docs/ai/<slug>/`)
- `COMPLEXITY` — from the "Complexity" field
- `TASKS[]` — all tasks from the "Tasks" section with full text (What, How, Files, Context, Verify)
- `CONSTRAINTS` — from the plan header
- `VERIFICATION` — from the "Verification" section
- `EXECUTION_ORDER` — from the "Execution / Order" section (parallel groups, barriers, sequence)

**3.** Extract `TICKET_ID` from the slug (per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`). Pass `TICKET_ID` and `SLUG` to every sub-agent for commits.

**4.** Find the task file: `docs/ai/<SLUG>/<SLUG>-task.md`

**5.** Create the todo list via TodoWrite:

```
[ ] Execute: Task 1 — <name>
[ ] Execute: Task 2 — <name>
...
[ ] Execute: Task N — Validation (from the plan)
[ ] Polish: simplify and clean up code
[ ] Validate: lint + types + tests
[ ] Documentation: update documentation
[ ] Finalize: format + report
[ ] Complete: review / revdiff / finish
```

**Transition:** plan loaded, todos created → Phase 2

---

## Phase 2 — Execute

Read `reference/status-protocol.md` — rules for status handling, review loop, parallel dispatch.

### Dispatch by Execution Order

Read the Order from the plan:

- **Parallel group** → dispatch all tasks in the group simultaneously via the Agent tool
- **Sequential** → dispatch one at a time
- **Barrier** → wait for all tasks in the group to finish

Without parallel groups, run sequentially.

### For each task

```
1. Build the prompt for the sub-agent:
   - Read agents/task-executor.md
   - Substitute: task.What, task.How, task.Files, task.Context, CONSTRAINTS, task.Verify
   - Construct COMMIT_MESSAGE in the format `TICKET type(SLUG): description`
     Example: `#86 feat(86-black-jack-page): add game page with basic layout`
     NO colon after the ticket. SLUG is required.
   - Pass the full task text, not the path to the plan file

2. Dispatch via the Agent tool
   - Wait for the result

3. Handle the status (per reference/status-protocol.md):
   - DONE / DONE_WITH_CONCERNS → run the Review Loop
   - NEEDS_CONTEXT → add context, re-dispatch
   - BLOCKED → evaluate, re-dispatch with a stronger model or record it

4. Review Loop (for DONE / DONE_WITH_CONCERNS):
   - Dispatch agents/task-reviewer.md
     - Pass: task requirements, implementer report, BASE_SHA, HEAD_SHA
     - The agent does spec compliance + code quality in one pass.
     - ✅ Approved → task complete
     - ❌ Critical/Important issues → implementer fixes → re-dispatch (max 3)
     - Minor only → record, do not block

5. Guarantee a commit:
   - Check `git status` for uncommitted changes
   - If any exist — commit per the convention in `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`
   - Record the commit hash for the report

6. Mark in TodoWrite: [x]
```

**On BLOCKED:** skip only tasks that depend on the blocked one. Run the rest.

On BLOCKED — send a notification:
`bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type ALERT --skill do --phase Execute --slug "$SLUG" --title "Task blocked" --body "<block reason and number of skipped tasks>"`

Save the changed/created files list for Phases 3-5.

**Transition:** tasks done (or BLOCKED) → Phase 3

**If there are zero changed files** (all tasks BLOCKED/SKIPPED):
skip Phases 3 (Polish) and 5 (Document).
Go to Phase 4 (Validate) — skip if there are no changes.
Then Phase 6 (Finalize) with status failed → Phase 7 (Complete).

---

## Phase 3 — Polish

Run a sub-agent via the Agent tool. Prompt — from `agents/code-polisher.md`.

Pass:

- List of files changed/created in Phase 2
- CONSTRAINTS from the plan

After completion:

- Commit per the convention in `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- Mark in TodoWrite: [x]

**Transition →** Phase 4.

---

## Phase 4 — Validate

Run a sub-agent via the Agent tool. Prompt — from `agents/validator.md`.

Pass:

- List of files changed in Phases 2-3
- SLUG for the commit convention
- TICKET_ID for the commit convention
- CONSTRAINTS from the plan

The sub-agent reads commands from package.json scripts, runs lint/type-check/test/build,
fixes failures (one attempt), commits fixes, and returns the result of each command.

Mark in TodoWrite: [x]

**Transition →** Phase 5.

---

## Phase 5 — Document

Run a sub-agent via the Agent tool. Prompt — from `agents/doc-updater.md`.

Pass:

- List of changed files
- SLUG and task title
- Requirements from the plan file

The sub-agent decides what to update:

- README — on API changes or new features
- CHANGELOG — when the file exists
- JSDoc/TSDoc — for new/changed exported functions

**Extend existing documentation.**

After completion:

- Commit per the convention in `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- Mark in TodoWrite: [x]

**Transition →** Phase 6.

---

## Phase 6 — Finalize

### 6a. Format

Run a sub-agent via the Agent tool. Prompt — from `agents/formatter.md`.

Pass:

- List of changed files
- SLUG for the commit convention
- TICKET_ID for the commit convention

The sub-agent picks the formatter, runs it on the files, commits.

Mark in TodoWrite: [x]

### 6b. Report

Write `docs/ai/<SLUG>/<SLUG>-report.md` directly via the Write tool using the Report template (see appendix at the end of this file).

Fill the template from data the orchestrator already holds: task statuses (DONE / DONE_WITH_CONCERNS / BLOCKED / SKIPPED), commit hashes, concerns text, blocked reasons, post-implementation statuses, validation command results, FILES_CHANGED list. Run `git log origin/main..HEAD --oneline` to collect commits.

After writing the report, auto-commit it. Check `docs/ai/` against `.gitignore`. If ignored — skip.

Otherwise commit per the convention in `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`:

```bash
git add docs/ai/<SLUG>/<SLUG>-report.md
git commit -m "TICKET docs(SLUG): add execution report"
```

Format: `TICKET docs(SLUG): add execution report` (NO colon after ticket).
Example: `#86 docs(86-black-jack-page): add execution report`.

### 6c. Notification

Print a summary: `<SLUG> done (N/M tasks)` or `<SLUG> done with issues (N/M tasks, K blocked)`.
Path to the report file.

Send a notification:
`bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill do --phase Complete --slug "$SLUG" --title "<SLUG> done (N/M tasks)" --body "docs/ai/$SLUG/$SLUG-report.md"`

**Transition →** Phase 7.

---

## Phase 7 — Complete

Report the path to the report file and offer 3 options via AskUserQuestion:

1. **Run /yoke:review (Recommended)** — automatic transition to code review
2. **Review via revdiff** — interactive annotation of the /do diff
3. **Finish** — exit

**Handling the choice:**

- **Run /yoke:review:** invoke the Skill tool with `/yoke:review` and argument `<SLUG>`
- **Review via revdiff:** After revdiff closes, continue with the following steps:
  1. Resolve the default base via the cascade `git symbolic-ref refs/remotes/origin/HEAD` → `origin/main` → `origin/master` → fallback `main` (see `skills/gp/agents/git-pre-checker.md:43-54`). Call the Skill tool with `/revdiff` and the argument `<default-base>...HEAD`.
  2. If the Skill return is empty, skip this entire step. Otherwise:
     - If the annotations describe code changes, apply those code changes inline (orchestrator edits — do not dispatch a sub-agent). If the annotations are prose-only, skip the code-edit step.
     - Append the full annotation text to `docs/ai/<SLUG>/<SLUG>-report.md`: if a `## Review notes` heading already exists in the file, append under the existing heading; otherwise create the heading and append under it.
     - Check `.gitignore` for `docs/ai/` (same as Phase 6b). If ignored, skip the auto-commit. Otherwise, run `git add docs/ai/<SLUG>/<SLUG>-report.md && git commit -m "TICKET docs(SLUG): append review notes"` (per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`).
  3. Return to the "Offer 3 options" step above.
     If the plugin is missing — print `Install the revdiff plugin:` followed by `  /plugin marketplace add umputun/revdiff` and `  /plugin install revdiff@umputun-revdiff`, then return to the "Offer 3 options" step above.
- **Finish:** report the path to the report file

---

## Rules

- **No stops.** Run end to end without confirmations between steps.
- **Commits by convention.** Format and ticket ID — from `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- **Current directory.** Worktrees and branch management are not allowed.
- **Context isolation.** A sub-agent receives the full text of its task, not the whole plan.
- **Review after each task.** Spec compliance → code quality. Mandatory.
- **TodoWrite.** Mark each step immediately upon completion.
- **On BLOCKED — keep going.** Stop only the dependent branch.
- **CLI output.** Run commands with long output (formatter, lint, build, test) with `2>&1 | tail -20`.
- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.

---

## Report template

```markdown
# Report: <slug>

**Plan:** <path to the plan file>
**Mode:** <inline | sub-agents>
**Status:** ✅ complete | ⚠️ partial | ❌ failed

## Tasks

| #   | Task   | Status                | Commit    | Concerns          |
| --- | ------ | --------------------- | --------- | ----------------- |
| 1   | <name> | ✅ DONE               | `abc1234` | —                 |
| 2   | <name> | ⚠️ DONE_WITH_CONCERNS | `def5678` | see below         |
| 3   | <name> | ❌ BLOCKED            | —         | see below         |
| 4   | <name> | ⏭️ SKIPPED            | —         | depends on Task 3 |

## Post-implementation

| Step          | Status  | Commit    |
| ------------- | ------- | --------- |
| Validate      | ✅ pass | —         |
| Documentation | ✅ done | `ccc3333` |
| Format        | ✅ done | `ddd4444` |

## Concerns

### Task 2: <name>

<concerns text>

## Blocked

### Task 3: <name>

**Reason:** <reason>
**Impact:** Task 4 skipped (depends on Task 3)

## Validation

<lint command> ✅
<type-check command> ✅ (or N/A)
<test command> ✅ (<N> passed, 0 failed)
<build command> ✅ (or N/A)

## Changes summary

| File              | Action   | Description |
| ----------------- | -------- | ----------- |
| src/path/file.ts  | created  | <what>      |
| src/path/other.ts | modified | <what>      |

## Commits

- `abc1234` <message>
- `def5678` <message>
```

**Status derivation:**

- All DONE → `✅ complete`
- Some BLOCKED or SKIPPED, majority DONE → `⚠️ partial`
- Majority BLOCKED → `❌ failed`

Concerns and Blocked sections appear only when matching tasks exist. Commits in chronological order, including post-implementation. For the full template with extended commentary, see `reference/report-format.md` — supplementary, optional.
