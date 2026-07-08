# Review procedure

The mechanics behind `/yoke:review`. The skill routes here — read this file and run the pipeline end to end.

Act as the orchestrator: talk to the user, coordinate the sub-agents, and delegate every file and bash operation. A sub-agent receives only its own data, never the whole pipeline.

## Agents

- Analysis → `agents/code-reviewer.md`
- Fix unit → `agents/single-fix-agent.md`
- Validation → `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/validator.md`
- Formatting → `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/formatter.md`

## Pipeline

Six phases, tracked in TodoWrite. The flow pauses twice — fix-scope selection (Phase 3) and the final action (Phase 6). Every other step runs to completion.

```
1. Parse     → determine SLUG, collect context
2. Analyze   → dispatch code-reviewer
3. Select    → show issues, choose fix scope
4. Fix       → dispatch single-fix-agents + validator + formatter
5. Finalize  → write report + PR comments + commit
6. Complete  → notification + action choice
```

### Phase 1 — Parse

1. Determine `SLUG`:
   - from `$ARGUMENTS` when it is a slug;
   - from a task-file path `.yoke/ai/<slug>/<slug>-task.md`;
   - otherwise from the current branch or the latest `.yoke/ai/*/` directory.
2. Task-file path: `.yoke/ai/<SLUG>/<SLUG>-task.md`. If the file is absent, pass `—` to the sub-agent.
3. Extract `TICKET_ID` from `SLUG` per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
4. Post-flow awareness — collect `KNOWN_ISSUES` from existing artifacts:
   - `.yoke/ai/<SLUG>/<SLUG>-report.md` — Concerns sections and quality-review results;
   - `.yoke/ai/<SLUG>/<SLUG>-fixes.md` — append its list of fixes;
   - no artifacts → `KNOWN_ISSUES = —`.

**Transition:** `SLUG`, `TICKET_ID`, `KNOWN_ISSUES` determined → Phase 2.

### Phase 2 — Analyze

Dispatch code-reviewer via the Agent tool. Read `agents/code-reviewer.md` and substitute `{{SLUG}}`, `{{TASK_FILE_PATH}}`, `{{KNOWN_ISSUES}}`.

Receive `SUMMARY` + `ISSUES` + `ISSUES_COUNT`. When `ISSUES_COUNT = 0`, skip to Phase 5 and report without fixes.

**Transition:** `SUMMARY` and `ISSUES` received → Phase 3.

### Phase 3 — Select

1. Notify:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type ACTION_REQUIRED --skill review --title "Found N issues" --body "Critical: X, Important: Y, Minor: Z"
   ```

2. Show the user every issue: severity, category, `file:line`, description.
3. Propose a scope via AskUserQuestion, recommended option first:
   - **"Fix Critical + Important (Recommended)"** — exclude Minor;
   - **"Fix only Critical"** — only score ≥ 80;
   - **"Fix all"** — every issue;
   - **"Skip fixes"** — report only, no fixes.
4. Filter issues by the choice → `ISSUES_TO_FIX`, `ISSUES_TO_SKIP`.

**Transition:** scope chosen → Phase 4.

### Phase 4 — Fix

When the user chose "Skip fixes", move all issues to `SKIPPED_ISSUES` with reason "Skipped by user choice" and skip to Phase 5.

When `ISSUES_TO_FIX` is non-empty:

**a)** Group `ISSUES_TO_FIX` by file — issues in the same file form one group, different files form different groups.

**b)** Dispatch `agents/single-fix-agent.md` per group via the Agent tool. Read the agent file and substitute `{{ISSUES}}` (the group's issues) and `{{CONSTRAINTS}}`.

- Groups without shared files dispatch in parallel — one Agent message, multiple tool uses.
- Groups with overlapping files dispatch sequentially.
- 1–3 issues in one file → one group, no parallelism.

**c)** Collect `FIXED`, `SKIPPED`, `FILES_CHANGED` from each agent. Concatenate into `FIXED_ISSUES`, `SKIPPED_ISSUES`, `FILES_CHANGED`.

**d)** Append `ISSUES_TO_SKIP` to `SKIPPED_ISSUES` with reason "Excluded by user".

**e)** One fix commit covering all files (`N` = count of `FIXED`, no colon after the ticket):

```bash
git add <FILES_CHANGED>
git commit -m "TICKET fix(SLUG): fix N review issues"
```

**f)** Dispatch validator AND formatter from `/do` in parallel — both operate on the same files but do not depend on each other. Issue both Agent calls in **one message** with two tool uses:

- validator: read `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/validator.md`, substitute `{{FILES_LIST}}`, `{{SLUG}}`, `{{TICKET_ID}}`, `{{CONSTRAINTS}}`;
- formatter: read `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/formatter.md`, substitute `{{FILES_LIST}}`, `{{SLUG}}`, `{{TICKET_ID}}`.

Each commits its own fixes when needed.

**Transition:** fixes complete → Phase 5.

### Phase 5 — Finalize

**a)** Write `.yoke/ai/<SLUG>/<SLUG>-review.md` directly with the Write tool, following the template in `reference/review-format.md`. Fill it from data the orchestrator already holds:

- **Summary** — from `SUMMARY` (the 7-dimension block code-reviewer returned);
- **Commits** — `git log origin/main..HEAD --oneline`;
- **Changed Files** — `git diff origin/main...HEAD --stat`;
- **Issues Found** — all Phase 2 issues sorted by Score descending;
- **Fixed Issues** — `FIXED_ISSUES` linked to commit hashes;
- **Skipped Issues** — `SKIPPED_ISSUES` with reasons;
- **Recommendations** — from the skipped issues and the overall analysis.

Replace empty tables with the placeholder text from the template's `>` blocks.

Auto-commit the report. If `.yoke/` is gitignored, skip. Otherwise commit per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md` (no colon after the ticket):

```bash
git add .yoke/ai/<SLUG>/<SLUG>-review.md
git commit -m "TICKET docs(SLUG): add review report"
```

Example: `#44 docs(44-review-with-fixes): add review report`.

**b)** PR comments. Check the PR: `gh pr view --json number 2>/dev/null`. If the PR exists and `SKIPPED_ISSUES` is non-empty, publish each skipped issue as a PR comment; otherwise skip:

```bash
gh api --method POST repos/{owner}/{repo}/issues/{number}/comments -f body="[severity] category: file:line — description"
```

**Transition:** report written → Phase 6.

### Phase 6 — Complete

1. Notify:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill review --title "Review complete" --body ".yoke/ai/$SLUG/$SLUG-review.md"
   ```

2. Report the result: number found / fixed / skipped, and the path to the review file.
3. Ask what to do next via AskUserQuestion, recommended option first:
   - **"Push (/yoke:gp) (Recommended)"** — invoke the Skill tool with `/yoke:gp`;
   - **"Create PR (/yoke:pr)"** — invoke the Skill tool with `/yoke:pr`;
   - **"Finish"** — exit.

## Conventions

- **Commits by convention.** Message format and ticket ID from `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md` — no colon after the ticket.
- **Context isolation.** A sub-agent receives only its data, never the whole pipeline.
- **Stable input contract.** `$ARGUMENTS` = slug (or task-file path, or empty). Invocations that pass a slug keep working unchanged.
- **Long CLI output.** Run with `2>&1 | tail -20`.
