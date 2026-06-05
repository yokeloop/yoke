---
name: do
description: >-
  Executes a task per plan. Triggered when the user writes "execute", "do",
  "run the plan", "implement", or passes a path to a plan file and asks to
  execute it.
---

# Execute task per plan

Act as the orchestrator. Detect the input shape, pick a mode, and run that
mode's procedure from its reference file. Each mode runs start to finish without
stops or confirmations beyond the single plan-confirmation pause that the
sub-agents and team modes define.

**Principle:** the developer starts the run and returns on notification.

---

## Input

`$ARGUMENTS` — one of:

- **empty** — no input; work from the current conversation (inline)
- **a plain task description** — chat text, no ticket (inline)
- **a single issue URL**, a bare `<slug>`, or a `*-task.md` path (sub-agents)
- **a `*-plan.md` path** — a pre-built plan (sub-agents, back-compat)
- **a PRD issue that has GitHub sub-issues** (team)

Optional flag `--update-docs` enables the documentation step. Without it, /do
skips docs unless the plan's frontmatter sets `update_docs: true`.

---

## Router

Detect the mode from `$ARGUMENTS`. First match wins:

1. **`$ARGUMENTS` is a path ending `-plan.md`** → **sub-agents** mode. A plan
   already exists, so skip planning. Read the file's `**Mode:**` header for
   back-compat — an `agent-team` header maps to **team** mode instead. Then read
   and follow `reference/mode-sub-agents.md` (or `reference/mode-team.md` when
   the header says `agent-team`).
2. **`$ARGUMENTS` is a single issue URL, a bare `<slug>`, or a `*-task.md`
   path** → **sub-agents** mode (investigate → plan → pause → execute). Read and
   follow `reference/mode-sub-agents.md`.
3. **`$ARGUMENTS` points at a PRD issue that HAS sub-issues** (detect via
   `gh api`) → **team** mode. Read and follow `reference/mode-team.md`.
4. **empty / a plain chat description / no ticket** → **inline** mode. Read and
   follow `reference/mode-inline.md`.

Each mode's full procedure lives in its reference file. Read only the one this
ladder selects, then execute it.

---

## Modes

| Mode           | Input                                            | Behavior                                                                                                                          |
| -------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| **inline**     | empty / plain chat description                   | Brief plan in chat, execute in-session, no pause, no plan file.                                                                   |
| **sub-agents** | issue URL / `<slug>` / `*-task.md` / `*-plan.md` | Write a full `.yoke/ai/<slug>/<slug>-plan.md`, pause for confirmation, then executor → reviewer → validator + formatter → report. |
| **team**       | PRD issue with sub-issues                        | Detect PRD sub-issues, write a plan, pause, then dispatch sub-agents per sub-issue.                                               |

---

## Rules

These apply to every mode run:

- **No stops within a run.** Beyond the single plan-confirmation pause the
  sub-agents and team modes define, run end to end without confirmations between
  steps.
- **Commits by convention.** Format and ticket ID — from
  `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- **Context isolation.** A sub-agent receives only its own task text, not the
  whole plan.
- **Review after each task.** Spec compliance → code quality. Mandatory.
- **CLI output.** Run commands with long output (formatter, lint, build, test)
  with `2>&1 | tail -20`.
- Language: match the ticket/input language, or follow the project-level
  definition in CLAUDE.md / AGENTS.md.

---

## Report template

```markdown
# Report: <slug>

**Plan:** <path to the plan file>
**Mode:** <inline | sub-agents | team>
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

Render Concerns and Blocked sections only when matching tasks exist. Commits in chronological order, including post-implementation. For the full template with extended commentary, see `reference/report-format.md` — supplementary, optional.
