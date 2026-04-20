# Code Review: 11-revdiff-flow-after-close

## Summary

### Context and goal

Fix a silent-exit bug in the "Review via revdiff" branch of the Complete-phase loop in `/task`, `/plan`, and `/do`. The prior bullet placed the `/revdiff` Skill call as the syntactically last action, causing the model to treat it as terminal and skip the post-close obligations (check annotations → apply/execute → re-present `AskUserQuestion`). This PR restructures each bullet so the continuation obligation appears before the Skill call, with numbered steps guiding the model through call → apply → loop-back, and adds an explicit empty-return skip branch.

### Key code areas for review

1. **`skills/task/SKILL.md:272`** — Phase 6 "Review via revdiff" bullet rewritten as 4-step inline sequence.
2. **`skills/plan/SKILL.md:298`** — Phase 8 "Review via revdiff" bullet rewritten with the same template.
3. **`skills/do/SKILL.md:290`** — Phase 7 "Review via revdiff" bullet rewritten; step 2 carries a nested sub-list preserving every PR #1 semantic (base cascade, `## Review notes` append, `.gitignore` check, auto-commit, install-hint fallback).
4. **`skills/do/SKILL.md:292`** — step 2 leads with the empty-return skip clause for unambiguous scope (review fix).

### Complex decisions

1. **Inline numbered steps, no shared reference doc** (all three bullets)
   A shared `lib/revdiff-protocol.md` would have reintroduced the root-cause bug at the reference site. Each bullet differs in args and /do has unique sub-steps, so factoring out saves no meaningful duplication.

2. **Continuation obligation stated BEFORE the Skill call** (`skills/task/SKILL.md:272`, `skills/plan/SKILL.md:298`, `skills/do/SKILL.md:290`)
   The literal phrase `After revdiff closes, continue with the following steps:` opens each bullet. This is the core root-cause fix — the prior PR #1 (`1e18e1b`) clarified the loop-back wording but kept the Skill call last, so the bug persisted. Announcing continuation up front makes post-close steps an explicit obligation.

3. **Byte-identical loop-back phrase across all three files** (`Return to the "Offer 3 options" step above.`)
   Matches `/fix` Phase 7's destination-naming pattern (`skills/fix/SKILL.md:248`). Byte-identical phrasing enables grep-based consistency checks and removes the ambiguity of the prior "Loop back to the start" wording.

4. **Empty-return skip leads /do step 2** (`skills/do/SKILL.md:292`)
   Originally written as "If the Skill return is non-empty: ... [sub-bullets] ... If the Skill return is empty, skip this entire step." Prettier re-indented the skip clause as a nested continuation of the last sub-bullet, making the scope ambiguous. Restructured to lead step 2 with "If the Skill return is empty, skip this entire step. Otherwise:" — prettier-safe and structurally unambiguous.

### Questions for the reviewer

1. The verification-spec defect (case-sensitive grep vs capitalized "Return" at sentence-start, lowercase "return" mid-sentence) was handled by switching Task 4 to a case-insensitive grep. Worth updating the plan template to recommend case-insensitive grep for prose-embedded phrases?
2. `/task` and `/plan` install-hint fallbacks still sit at 5-space indent (continuation of step 3 in the markdown AST). Text self-identification is sufficient, but is there value in a /do-style restructure for consistency?
3. No version pin on the external revdiff plugin — still open from PR #1 review question 2.

### Risks and impact

- No code paths broken — markdown-only edits to skill instructions.
- External dependency surface area unchanged — revdiff plugin install-hint fallback preserved verbatim from PR #1.
- PR #1 `/do` Phase 7 semantics (cascade reference, `## Review notes` heading, gitignore check, auto-commit) are preserved and verified by Task 4 greps.

### Tests and manual checks

**Auto-tests:** none (markdown-only plugin, no tests in the repo).

**Manual scenarios** (per plan Verification section):

1. `/yoke:task <ticket>` → Phase 6 pick "Review via revdiff" → annotate → quit → task file overwritten → `AskUserQuestion` re-appears.
2. `/yoke:task` → Phase 6 pick "Review via revdiff" → quit without annotating → task file unchanged → `AskUserQuestion` re-appears.
3. `/yoke:plan <task-path>` → Phase 8 same outcomes for the plan file.
4. `/yoke:do <plan-path>` → Phase 7 pick "Review via revdiff" → annotate code regions → quit → code changes implemented inline → annotations appended under `## Review notes` → auto-commit `#11 docs(...): append review notes` → `AskUserQuestion` re-appears.
5. `/yoke:do` → Phase 7 pick "Review via revdiff" → quit without annotating → no code change, no report append, no commit → `AskUserQuestion` re-appears.
6. Negative — uninstall revdiff → pick "Review via revdiff" → install hint prints → `AskUserQuestion` re-appears without crash.
7. Loop termination — loop "Review via revdiff" twice, then pick **Finish** → loop exits.
8. Gitignore negative — add `docs/ai/` to `.gitignore` → `/yoke:do` Phase 7 revdiff with annotations → report updated, auto-commit skipped, `AskUserQuestion` re-appears.

### Out of scope

- `/fix`, `/review`, `/explore`, `/gca`, `/gp`, `/pr`, `/gst`, `/hi`, `/bootstrap` — no revdiff branch, explicitly excluded per Task constraints.
- `docs/task.md`, `docs/plan.md`, `docs/do.md`, `README.md` — wording remains accurate after the restructure.
- Historical artifacts under `docs/ai/1-replace-plannotator-with-revdiff/` — untouched.
- Shared revdiff-protocol reference doc — explicitly rejected in DD-1.
- Revdiff return-format schema — explicitly rejected in DD-3 (empty-vs-non-empty detection only).

## Commits

| Hash      | Description                                                                                            |
| --------- | ------------------------------------------------------------------------------------------------------ |
| `d34616f` | `#11 docs(11-revdiff-flow-after-close): add task definition`                                           |
| `215f54c` | `#11 docs(11-revdiff-flow-after-close): add implementation plan`                                       |
| `9d52739` | `#11 fix(11-revdiff-flow-after-close): restructure task revdiff bullet to execute annotations after close` |
| `d4eaa4e` | `#11 fix(11-revdiff-flow-after-close): restructure plan revdiff bullet to execute annotations after close` |
| `ce99939` | `#11 fix(11-revdiff-flow-after-close): restructure do revdiff bullet to execute annotations after close`   |
| `19a9d21` | `#11 style(11-revdiff-flow-after-close): apply prettier to revdiff bullets`                            |
| `186e49d` | `#11 docs(11-revdiff-flow-after-close): add execution report`                                          |
| `e34ff9d` | `#11 fix(11-revdiff-flow-after-close): lead do step 2 with empty-return skip for unambiguous scope`    |

## Changed Files

| File                                                             | +/-     | Description                                                                              |
| ---------------------------------------------------------------- | ------- | ---------------------------------------------------------------------------------------- |
| `skills/task/SKILL.md`                                           | +5/-1   | Phase 6 "Review via revdiff" bullet restructured to 4-step inline form                   |
| `skills/plan/SKILL.md`                                           | +5/-1   | Phase 8 "Review via revdiff" bullet restructured to 4-step inline form                   |
| `skills/do/SKILL.md`                                             | +8/-1   | Phase 7 "Review via revdiff" bullet restructured; step 2 leads with empty-return skip    |
| `docs/ai/11-revdiff-flow-after-close/*-task.md`                  | +109/-0 | Task definition artifact                                                                 |
| `docs/ai/11-revdiff-flow-after-close/*-plan.md`                  | +167/-0 | Implementation plan artifact                                                             |
| `docs/ai/11-revdiff-flow-after-close/*-report.md`                | +64/-0  | Execution report artifact                                                                |

## Issues Found

| Severity  | Score | Category              | File:line                | Description                                                                                                     |
| --------- | ----- | --------------------- | ------------------------ | --------------------------------------------------------------------------------------------------------------- |
| Important | 82    | bug (instruction)     | `skills/do/SKILL.md:296` | Empty-return skip clause sits at 7-space indent (continuation of gitignore sub-bullet); scope ambiguous vs step 2 |

## Fixed Issues

| Issue                                                 | Commit    | Description                                                                                  |
| ----------------------------------------------------- | --------- | -------------------------------------------------------------------------------------------- |
| Empty-return skip scope ambiguous (`do/SKILL.md:296`) | `e34ff9d` | Restructured step 2 to open with the empty-return skip; prettier-safe and unambiguous |

## Skipped Issues

**All found issues were fixed.**

## Recommendations

- Before merging, run manual scenarios 1–8 above — especially 4 (/do with annotations, the only path exercising both inline code edits and auto-commit) and 6 (plugin-missing fallback).
- The two pre-existing concerns from the execution report — the case-sensitive grep verification-spec defect and the prettier re-indentation of `/task` and `/plan` install-hint fallbacks — are accepted. Neither blocks the core fix. Consider a follow-up ticket to (a) add a plan-template guidance note on case-insensitive grep for prose-embedded phrases and (b) apply the same step-2-style restructure to `/task` and `/plan` for visual consistency.
- PR #1 follow-up items remain open: Telegram notification on `/do` Phase 7 install-hint path (question 3 of PR #1 review) and revdiff plugin version pinning (question 2 of PR #1 review).
