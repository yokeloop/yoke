---
name: review
description: >-
  Finds problems in code, fixes them and produces a report.
  Used when the user writes "review", "code review", "find issues",
  "find bugs", "check code", "code analysis", "prepare a report",
  "what's wrong with the code".
---

# Review

Review the code for a task, fix the problems worth fixing, and leave behind a report a human reviewer can act on. A standalone utility — run it whenever code needs a second pass, not only inside a larger flow.

The orchestrator drives the run: it talks to the user, dispatches sub-agents for analysis and for fixes, and pauses only twice — to choose which findings to fix, and to choose what happens next. Every other step runs to completion without asking.

---

## Input

`$ARGUMENTS` — a task-slug or a path to a task-file. With no argument, determine the slug from the current branch or the latest `.yoke/ai/*/` directory. This input contract is stable, so callers that pass a slug keep working.

---

## Procedure

The full pipeline — scope resolution, the code-reviewer dispatch, finding classification, the fix loop, validation, and report assembly — lives in `reference/review-procedure.md`. Read that file and execute it end to end. The report follows the template in `reference/review-format.md`.

---

## Rules

- **Standalone utility.** Review runs on its own; it never assumes a larger flow around it.
- **Fix, then report.** Findings the user accepts are fixed and committed; everything found — fixed or skipped — lands in the report.
- **Report location.** Write the report to `.yoke/ai/<slug>/<slug>-review.md`.
- **Every fork is one question.** For any decision — fix scope, next action — ask a single AskUserQuestion with the recommended option listed first.
- **Delegate the work.** File edits, bash, and analysis go to sub-agents; each receives only its own data.
- **Read the git memory.** Pull decision context from the affected files' commit history per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/history-reading.md` — a finding that contradicts a `Constraint:` or re-proposes a `Rejected:` approach must cite the commit it argues with.
- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
