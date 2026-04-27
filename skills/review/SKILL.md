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
- Fix unit → `agents/single-fix-agent.md`
- Validation → `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/validator.md`
- Formatting → `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/formatter.md`

Run continuously. The flow pauses twice: at fix-scope selection and at the final action.

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
4. Fix       → dispatch single-fix-agents + validator + formatter
5. Finalize  → write report inline + PR comments + commit
6. Complete  → notification + action choice
```

---

### Phase 1 — Parse

**1.** Determine `SLUG`:

- From `$ARGUMENTS` (if slug)
- From path to task-file: `docs/ai/<slug>/<slug>-task.md`
- From the current branch or the latest `docs/ai/*/` directory

**2.** Path to task-file: `docs/ai/<SLUG>/<SLUG>-task.md`.
If the file is absent, pass `—` to the sub-agent.

**3.** Extract `TICKET_ID` from SLUG (per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`).

**4.** Post-flow awareness — check artifacts:

- `docs/ai/<SLUG>/<SLUG>-report.md` — collect KNOWN_ISSUES from Concerns sections and quality review results
- `docs/ai/<SLUG>/<SLUG>-fixes.md` — append the list of fixes to KNOWN_ISSUES
- If no artifacts exist, set KNOWN_ISSUES = `—`

**Transition:** SLUG, TICKET_ID, KNOWN_ISSUES determined → Phase 2.

---

### Phase 2 — Analyze

Dispatch code-reviewer via the Agent tool. Read `agents/code-reviewer.md`, substitute {{SLUG}}, {{TASK_FILE_PATH}}, {{KNOWN_ISSUES}}.

Receive SUMMARY + ISSUES + ISSUES_COUNT.

When ISSUES_COUNT = 0, skip to Phase 5 and report without fixes.

**Transition:** SUMMARY and ISSUES received → Phase 3.

---

### Phase 3 — Select

**1.** Send notification:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type ACTION_REQUIRED --skill review --phase Select --slug "$SLUG" --title "Found N issues" --body "Critical: X, Important: Y, Minor: Z"
```

**2.** Show the user all issues: severity, category, file:line, description.

**3.** Via AskUserQuestion propose a scope:

- **"Fix Critical + Important (Recommended)"** — exclude Minor
- **"Fix only Critical"** — only score >= 80
- **"Fix all"** — all issues
- **"Skip fixes"** — report only, no fixes

**4.** Filter issues by choice → ISSUES_TO_FIX, ISSUES_TO_SKIP.

**Transition:** scope chosen → Phase 4.

---

### Phase 4 — Fix

When the user chose "Skip fixes", move all issues to SKIPPED_ISSUES with reason "Skipped by user choice" and skip to Phase 5.

If ISSUES_TO_FIX is non-empty:

**a)** Group ISSUES_TO_FIX by file. Issues in the same file = one group; issues in different files = different groups.

**b)** Dispatch `agents/single-fix-agent.md` per group via the Agent tool. Read the agent file, substitute {{ISSUES}} (the group's issues) and {{CONSTRAINTS}}.

- Groups without shared files dispatch in parallel (single Agent message with multiple tool uses).
- Groups with overlapping files dispatch sequentially.
- 1-3 issues in one file → dispatch as one group, no parallelism needed.

**c)** Collect FIXED, SKIPPED, FILES_CHANGED from each agent. Concatenate into FIXED_ISSUES, SKIPPED_ISSUES, FILES_CHANGED.

**d)** Append issues from ISSUES_TO_SKIP to SKIPPED_ISSUES (reason "Excluded by user").

**e)** Single fix commit covering all files:

```bash
git add <FILES_CHANGED>
git commit -m "TICKET fix(SLUG): fix N review issues"
```

Format: `TICKET fix(SLUG): fix N review issues` (NO colon after ticket). N = count of FIXED.

**f)** Dispatch validator AND formatter from /do in parallel — both operate on the same files but do not depend on each other's output. Issue both Agent calls in **one message** with two tool uses:

- validator: read `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/validator.md`, substitute {{FILES_LIST}}, {{SLUG}}, {{TICKET_ID}}, {{CONSTRAINTS}}.
- formatter: read `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/formatter.md`, substitute {{FILES_LIST}}, {{SLUG}}, {{TICKET_ID}}.

Each commits its own fixes when needed.

**Transition:** fixes complete → Phase 5.

---

### Phase 5 — Finalize

**a)** Write `docs/ai/<SLUG>/<SLUG>-review.md` directly via the Write tool using the Review template (see appendix at the end of this file).

Fill the template from data the orchestrator already holds:

- **Summary** — from SUMMARY (the 7-dimension block code-reviewer returned)
- **Commits** — `git log origin/main..HEAD --oneline`
- **Changed Files** — `git diff origin/main...HEAD --stat`
- **Issues Found** — ALL_ISSUES (Phase 2 output) sorted by Score descending
- **Fixed Issues** — FIXED_ISSUES linked to commit hashes
- **Skipped Issues** — SKIPPED_ISSUES with reasons
- **Recommendations** — based on skipped issues and the overall analysis

Replace empty tables with the placeholder text from the template's `>` blocks (e.g., "Code is clean.").

After writing the report, auto-commit it. Check `docs/ai/` against `.gitignore`. If ignored — skip.

Otherwise commit per the convention in `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`:

```bash
git add docs/ai/<SLUG>/<SLUG>-review.md
git commit -m "TICKET docs(SLUG): add review report"
```

Format: `TICKET docs(SLUG): add review report` (NO colon after ticket).
Example: `#44 docs(44-review-with-fixes): add review report`.

**b)** PR comments:

Check PR: `gh pr view --json number 2>/dev/null`

If the PR exists and SKIPPED_ISSUES is non-empty, publish each issue as a PR comment:

```bash
gh api --method POST repos/{owner}/{repo}/issues/{number}/comments -f body="[severity] category: file:line — description"
```

Otherwise skip.

**Transition:** report written → Phase 6.

---

### Phase 6 — Complete

**1.** Notification:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill review --phase Complete --slug "$SLUG" --title "Review complete" --body "docs/ai/$SLUG/$SLUG-review.md"
```

**2.** Report the result: number found / fixed / skipped, path to the review file.

**3.** AskUserQuestion — what next:

- **"Push (/yoke:gp) (Recommended)"** — invoke the Skill tool with `/yoke:gp`
- **"Create PR (/yoke:pr)"** — invoke the Skill tool with `/yoke:pr`
- **"Finish"** — exit

---

## Rules

- **Continuous work.** Pause only at scope selection (Phase 3) and the final action (Phase 6).
- **Delegation.** Delegate file operations and bash to sub-agents.
- **Commits by convention.** Format and ticket ID from `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- **Context isolation.** A sub-agent receives only its data, not the whole pipeline.
- **Backward compatibility.** $ARGUMENTS = SLUG. Invocation from /do and /fix unchanged.
- **Long CLI output.** Run with `2>&1 | tail -20`.
- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.

---

## Review template

```markdown
# Code Review: <SLUG>

## Summary

### Context and goal

<1-3 sentences: what was done and why>

### Key code areas for review

1. **`src/path/file.ts:fn()`** — <why it matters>

### Complex decisions

1. **<What>** (`src/path/file.ts:42`) — <trade-off>

### Questions for the reviewer

1. <Concrete question>

### Risks and impact

- <Risk>: <what to watch out for>

### Tests and manual checks

**Auto-tests:**

- <what should be covered>

**Manual scenarios:**

1. <Step> → <expected result>

### Out of scope

- <what the PR intentionally excludes>

## Commits

| Hash    | Description     |
| ------- | --------------- |
| abc1234 | feat(slug): ... |

## Changed Files

| File             | +/-     | Description    |
| ---------------- | ------- | -------------- |
| src/path/file.ts | +42/-10 | <what changed> |

## Issues Found

| Severity | Score | Category | File:line            | Description            |
| -------- | ----- | -------- | -------------------- | ---------------------- |
| Critical | 90    | security | src/auth/login.ts:42 | SQL injection in query |

> No issues — replace the table with: **Code is clean.**

## Fixed Issues

| Issue                        | Commit    | Description         |
| ---------------------------- | --------- | ------------------- |
| SQL injection in login.ts:42 | `def5678` | Parameterized query |

> No fixes — replace the table with: **All issues fixed.**

## Skipped Issues

| Issue         | Reason                     |
| ------------- | -------------------------- |
| Unused import | Stylistic, out of PR scope |

> No skipped — replace the table with: **All found issues were fixed.**

## Recommendations

- <Recommendation for PR review>
```

**Format rules:**

- Summary covers 7 dimensions: context and goal, key areas, complex decisions, questions for the reviewer, risks, tests, out of scope.
- Issues Found sorted by Score descending. Severity: Critical (80-100) / Important (50-79) / Minor (0-49).
- Fixed Issues and Skipped Issues appear when Issues Found has entries.
- Replace empty tables with the placeholder text from the `>` blocks above.

For the full template with extended commentary, see `reference/review-format.md` — supplementary, optional.
