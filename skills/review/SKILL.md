---
name: review
description: >-
  Finds problems in code, fixes them and produces a report.
  Used when the user writes "review", "code review",
  "find issues", "find bugs", "check code", "code analysis",
  "prepare a report", "what's wrong with the code", or after /do to analyze changes.
---

# Code review with automatic fixing

You are the orchestrator. You communicate with the user and coordinate sub-agents.

Agents:

- Analysis → `agents/code-reviewer.md`
- Fixes → `agents/issue-fixer.md` (→ `agents/single-fix-agent.md`)
- Report → `agents/review-report-writer.md`
- Validation → `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/validator.md`
- Formatting → `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/formatter.md`

Work continuously. Two pauses: fix scope selection and final action.

---

## Input

`$ARGUMENTS` — task-slug or path to task-file.

No argument — determine slug from the current branch or the latest `docs/ai/*/` directory.

---

## Pipeline

6 phases. Track each in TodoWrite.

```
1. Parse     → determine SLUG, collect context
2. Analyze   → dispatch code-reviewer
3. Select    → show issues, choose fix scope
4. Fix       → dispatch issue-fixer + validator + formatter
5. Finalize  → dispatch report-writer + PR comments + commit
6. Complete  → notification + action choice
```

---

### Phase 1 — Parse

**1.** Determine `SLUG`:

- From `$ARGUMENTS` (if slug)
- From path to task-file: `docs/ai/<slug>/<slug>-task.md`
- From the current branch or the latest `docs/ai/*/` directory

**2.** Path to task-file: `docs/ai/<SLUG>/<SLUG>-task.md`.
If file is absent — pass `—` to sub-agent.

**3.** Extract `TICKET_ID` from SLUG (per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`).

**4.** Post-flow awareness — check artifacts:

- `docs/ai/<SLUG>/<SLUG>-report.md` — collect KNOWN_ISSUES from Concerns sections and quality review results
- `docs/ai/<SLUG>/<SLUG>-fixes.md` — append the list of fixes to KNOWN_ISSUES
- No artifacts — KNOWN_ISSUES = `—`

**Transition:** SLUG, TICKET_ID, KNOWN_ISSUES determined → Phase 2.

---

### Phase 2 — Analyze

Dispatch code-reviewer via the Agent tool. Read `agents/code-reviewer.md`, substitute {{SLUG}}, {{TASK_FILE_PATH}}, {{KNOWN_ISSUES}}.

Receive SUMMARY + ISSUES + ISSUES_COUNT.

If ISSUES_COUNT = 0 → skip Phases 3-4, move to Phase 5 (report without fixes).

**Transition:** SUMMARY and ISSUES received → Phase 3.

---

### Phase 3 — Select

**1.** Send notification:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type ACTION_REQUIRED --skill review --phase Select --slug "$SLUG" --title "Found N issues" --body "Critical: X, Important: Y, Minor: Z"
```

**2.** Show the user all issues (briefly: severity, category, file:line, description).

**3.** Via AskUserQuestion propose a scope:

- **"Fix Critical + Important (Recommended)"** — exclude Minor
- **"Fix only Critical"** — only score >= 80
- **"Fix all"** — all issues
- **"Skip fixes"** — report only, no fixes

**4.** Filter issues by choice → ISSUES_TO_FIX, ISSUES_TO_SKIP.

**Transition:** scope chosen → Phase 4.

---

### Phase 4 — Fix

If ISSUES_TO_FIX contains issues:

**a)** Dispatch issue-fixer via the Agent tool. Read `agents/issue-fixer.md`, substitute {{ISSUES_TO_FIX}}, {{SLUG}}, {{TICKET_ID}}, {{CONSTRAINTS}}.
Issue-fixer itself dispatches parallel single-fix-agents.

**b)** Receive FIXED_ISSUES, SKIPPED_ISSUES, FILES_CHANGED.

**c)** Append issues from ISSUES_TO_SKIP to SKIPPED_ISSUES (reason "Excluded by user").

**d)** Dispatch validator from /do:
Read `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/validator.md`, substitute {{FILES_LIST}}, {{SLUG}}, {{TICKET_ID}}, {{CONSTRAINTS}}.

**e)** Dispatch formatter from /do:
Read `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/formatter.md`, substitute {{FILES_LIST}}, {{SLUG}}, {{TICKET_ID}}.

If the user chose "Skip fixes" — all issues go to SKIPPED_ISSUES, reason "Skipped by user choice".

**Transition:** fixes complete → Phase 5.

---

### Phase 5 — Finalize

**a)** Dispatch review-report-writer via the Agent tool. Read `agents/review-report-writer.md`, substitute {{SLUG}}, {{SUMMARY}}, {{ALL_ISSUES}} (full list from Phase 2), {{FIXED_ISSUES}}, {{SKIPPED_ISSUES}}, {{COMMIT_HASHES}}.

**b)** PR comments:

Check PR: `gh pr view --json number 2>/dev/null`

PR exists and SKIPPED_ISSUES is non-empty — publish each issue as a PR comment:

```bash
gh api --method POST repos/{owner}/{repo}/issues/{number}/comments -f body="[severity] category: file:line — description"
```

No PR — skip.

**c)** Commit report artifact:

Make sure `.gitignore` allows `docs/ai/`. If it does:

```bash
git add docs/ai/<SLUG>/<SLUG>-review.md
git commit -m "TICKET docs(SLUG): add review report"
```

Example: `#44 docs(44-review-with-fixes): add review report`

**Transition:** report written → Phase 6.

---

### Phase 6 — Complete

**1.** Notification:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill review --phase Complete --slug "$SLUG" --title "Review complete" --body "docs/ai/$SLUG/$SLUG-review.md"
```

**2.** Report the result: number found / fixed / skipped, path to the review file.

**3.** AskUserQuestion — what next:

- **"Push (/sp:gp) (Recommended)"** — invoke the Skill tool with `/sp:gp`
- **"Create PR (/sp:pr)"** — invoke the Skill tool with `/sp:pr`
- **"Finish"** — exit

---

## Rules

- **Continuous work.** Pauses: scope selection (Phase 3) and final action (Phase 6).
- **Delegation.** Delegate file operations and bash to sub-agents.
- **Commits by convention.** Format and ticket ID from `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- **Context isolation.** A sub-agent receives only its data, not the whole pipeline.
- **Backward compatibility.** $ARGUMENTS = SLUG. Invocation from /do and /fix unchanged.
- **Long CLI output.** Run with `2>&1 | tail -20`.
- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
