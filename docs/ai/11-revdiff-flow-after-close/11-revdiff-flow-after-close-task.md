# Fix revdiff flow after close — execute annotations and re-present AskUserQuestion

**Slug:** 11-revdiff-flow-after-close
**Ticket:** https://github.com/yokeloop/yoke/issues/11
**Complexity:** simple
**Type:** general

## Task

Rewrite the "Review via revdiff" branch in `skills/task/SKILL.md:272`, `skills/plan/SKILL.md:298`, and `skills/do/SKILL.md:290` so post-close obligations (check annotations → apply/execute → re-present AskUserQuestion) appear before the `/revdiff` Skill call, not after it, and so the loop runs until the user picks **Finish**.

## Context

### Area architecture

Each of the three skills ends in a Complete phase that runs a finishing loop:

- `/yoke:task` Phase 6 (`skills/task/SKILL.md:254-273`) under a `**Loop:**` heading.
- `/yoke:plan` Phase 8 (`skills/plan/SKILL.md:280-299`) under a `**Loop:**` heading.
- `/yoke:do` Phase 7 (`skills/do/SKILL.md:279-291`) with no `**Loop:**` heading — a flat 3-option list followed by a `Handling the choice:` block.

Each loop offers 3 options via `AskUserQuestion`:

1. Run the next skill (recommended).
2. **Review via revdiff**.
3. Finish.

Today the **Review via revdiff** branch packs every post-close step into one dense prose bullet, with the `/revdiff` Skill tool call appearing syntactically before the continuation instruction ("Loop back to the start" / "Re-present the 3 options"). The model reads the Skill tool call as the bullet's terminal action and exits, so:

- It skips the check for revdiff annotations.
- It skips applying annotations to the artifact file (`/task`, `/plan`) and skips implementing the code changes they describe (`/do`).
- It skips re-presenting `AskUserQuestion`.

The root cause is syntactic position, not missing content. The previous PR (#1) tried to clarify loop-back wording (`bef82f3` → `1e18e1b`) but left the Skill call last in the bullet, so the bug persisted.

### Files to change

- `skills/task/SKILL.md:272` — rewrite the "Review via revdiff" bullet (inline numbered steps).
- `skills/plan/SKILL.md:298` — rewrite the "Review via revdiff" bullet (inline numbered steps).
- `skills/do/SKILL.md:290` — rewrite the "Review via revdiff" bullet (inline numbered steps, with a `/do`-specific sub-list for base cascade, report append, gitignore check, and auto-commit).

### Patterns to reuse

- Inline numbered steps under a bullet — the minimal, self-contained fix (the architect's pick over a shared reference doc, which would reintroduce the same "last-action-is-tool-call" bug at the reference site).
- `/fix` Phase 7 "go back to Phase 1 (SLUG is preserved)" (`skills/fix/SKILL.md:248`) — the canonical destination-naming pattern. Adopt the phrasing "Return to the 'Offer 3 options' step above" for the loop-back step.
- Empty-vs-non-empty return detection — treat the `/revdiff` Skill return as text; a non-empty return means annotations are present and must be applied, an empty return means the user quit without annotating and the apply step is skipped.
- Existing `/do` Phase 7 semantics from PR #1 — default-base cascade (`skills/gp/agents/git-pre-checker.md:43-54`), append under `## Review notes`, `.gitignore` check mirroring Phase 6c, auto-commit `TICKET docs(SLUG): append review notes`, install-hint fallback. Keep every semantic intact; only restructure the ordering.
- `/do` code-change execution — the orchestrator applies code changes from annotations inline (no new agent dispatch), mirroring `/do`'s existing orchestrator-driven report-append pattern.

### Tests

The repository has no automated tests (markdown-only plugin, confirmed in `docs/ai/1-replace-plannotator-with-revdiff/1-replace-plannotator-with-revdiff-review.md:48`). Verification is manual per-skill run plus the existing markdown/JSON validators.

## Requirements

1. Rewrite the "Review via revdiff" bullet in `skills/task/SKILL.md:272` so it lists post-close steps before calling `/revdiff`. Required steps, in order: (a) announce continuation; (b) call the Skill tool with `/revdiff` and `--only docs/ai/<task-slug>/<task-slug>-task.md`; (c) if the Skill return is non-empty, apply the returned annotations to the task file and overwrite it; if empty, skip this step; (d) return to the "Offer 3 options" step above. Preserve the install-hint fallback (print `/plugin marketplace add umputun/revdiff` and `/plugin install revdiff@umputun-revdiff`), and after printing, return to the "Offer 3 options" step above.
2. Apply the same 4-step structure to `skills/plan/SKILL.md:298`, substituting `--only docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md` and "apply to the plan file" for the task-file wording.
3. Rewrite the "Review via revdiff" bullet in `skills/do/SKILL.md:290` with the same 4-step structure. Step (b) calls `/revdiff` with `<base>...HEAD`, where `<base>` resolves via the existing cascade `git symbolic-ref refs/remotes/origin/HEAD` → `origin/main` → `origin/master` → `main` (`skills/gp/agents/git-pre-checker.md:43-54`). Step (c) — when the Skill return is non-empty — does two things: (c1) the orchestrator applies code changes described in the annotations inline (no agent dispatch); (c2) appends the annotation text to `docs/ai/<SLUG>/<SLUG>-report.md` under an existing `## Review notes` heading, or creates the heading and appends under it; then checks whether `docs/ai/` is in `.gitignore` (same check as Phase 6c) and, if not ignored, runs `git add docs/ai/<SLUG>/<SLUG>-report.md && git commit -m "TICKET docs(SLUG): append review notes"` per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`. Step (d) returns to the "Offer 3 options" step above. Preserve the install-hint fallback as in requirement 1.
4. In all three rewrites, state the continuation obligation explicitly before the Skill call so the model reads the `/revdiff` dispatch as a middle step, not the terminal action. Use the phrasing "After revdiff closes, continue with the following steps:" (or equivalent) before step (a).
5. Use identical loop-back phrasing in all three files: "Return to the 'Offer 3 options' step above."
6. The loop must run until the user picks **Finish** (or the next-skill option). Every non-Finish branch — including the install-hint fallback and the empty-annotations case — returns to the "Offer 3 options" step above.

## Constraints

- Edit only the "Review via revdiff" bullet in each of the three SKILL.md files. Do not restructure surrounding Phase Complete text, the 3-option `AskUserQuestion` list itself, or the other two branches (Run next skill, Finish).
- Do not create a shared reference doc (`lib/revdiff-protocol.md` or `skills/*/reference/revdiff-protocol.md`). Per architect analysis, indirection would reintroduce the "last-action-is-tool-call" bug at the reference site. Per user confirmation, the fix stays inline per skill.
- Do not edit `docs/task.md:25`, `docs/plan.md:17,27-28`, `docs/do.md:18,28`, or the `README.md:274-323` Interactive review section. Their current wording ("revdiff → loop", "annotation fold-back") stays accurate after this change.
- Do not touch `/fix`, `/review`, `/explore`, `/gca`, `/gp`, `/pr`, `/gst`, `/hi`, or `/bootstrap` — they have no `/revdiff` branch and sit explicitly out of scope (confirmed in `docs/ai/1-replace-plannotator-with-revdiff/1-replace-plannotator-with-revdiff-review.md:60-63`).
- Do not touch historical artifacts under `docs/ai/1-replace-plannotator-with-revdiff/`.
- Do not change `/do` Phase 7's default-base cascade, the `## Review notes` heading semantics, the `.gitignore` check, the commit-message format, or the install-hint fallback. Keep every semantic from PR #1 intact — this task only restructures ordering and makes obligations explicit.
- Do not hoist `/do`'s sub-steps (base cascade, report append, gitignore check, auto-commit) to top-level numbering. Keep them nested under step (c) so the visual hierarchy signals "these belong to one of three choices", not "these are distinct Phase steps".
- Do not introduce new agent dispatches for `/do` annotation application — the orchestrator edits inline (per user confirmation), mirroring the existing append-to-report flow.
- Do not add a revdiff return-format schema to the SKILL.md or README. Detection is "non-empty return = annotations present, empty return = skip apply" (per user confirmation), without pinning revdiff's internal schema.
- Do not skip the Telegram notification paths or alter their wording. This change needs no new `notify.sh` call.

## Verification

- **Manual — `/yoke:task` with annotations:** run `/yoke:task <ticket>` → reach Phase 6 Complete → pick "Review via revdiff" → add annotations in revdiff → quit → task file is overwritten with annotations applied → `AskUserQuestion` with 3 options re-appears.
- **Manual — `/yoke:task` without annotations:** same as above, but quit revdiff without adding annotations → task file unchanged → `AskUserQuestion` with 3 options re-appears.
- **Manual — `/yoke:plan` with annotations:** run `/yoke:plan <task-path>` → reach Phase 8 Complete → pick "Review via revdiff" → annotate → quit → plan file overwritten with annotations → `AskUserQuestion` re-appears.
- **Manual — `/yoke:plan` without annotations:** same, quit without annotating → plan file unchanged → `AskUserQuestion` re-appears.
- **Manual — `/yoke:do` with annotations:** run `/yoke:do <plan-path>` → reach Phase 7 Complete → pick "Review via revdiff" → annotate code regions → quit → code changes described in annotations land in the affected files → annotation text appended under `## Review notes` in `docs/ai/<SLUG>/<SLUG>-report.md` → (if `docs/ai/` not in `.gitignore`) auto-commit `TICKET docs(SLUG): append review notes` created → `AskUserQuestion` re-appears.
- **Manual — `/yoke:do` without annotations:** same as above, quit without annotating → no code changes, no report append, no commit → `AskUserQuestion` re-appears.
- **Manual — revdiff plugin missing:** in any of the three skills, pick "Review via revdiff" when `/revdiff` is not installed → install-hint prints (`/plugin marketplace add umputun/revdiff` and `/plugin install revdiff@umputun-revdiff`) → `AskUserQuestion` re-appears.
- **Manual — loop termination:** in any of the three skills, loop through "Review via revdiff" at least twice, then pick **Finish** → loop exits and the skill reports the file path.
- **Manual — `docs/ai/` gitignored (`/yoke:do` only):** add `docs/ai/` to local `.gitignore` → `/yoke:do` Phase 7 revdiff path with annotations → report file updates, auto-commit is skipped, `AskUserQuestion` re-appears.
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"` → `OK`.
- `head -1 skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` → each starts with `---` (YAML frontmatter preserved).
- `pnpm run format:check` → no new failures.

### Edge cases

- revdiff returns no annotations (user quit without commenting) — skip the apply/execute step, but still re-present `AskUserQuestion`.
- revdiff plugin not installed — print the install-hint and re-present `AskUserQuestion`.
- `/do` annotations describe both code changes and prose notes — handle both: apply code edits inline, append the full annotation text to the report under `## Review notes`.
- Repeat `/do` revdiff invocations — annotations append under the existing `## Review notes` heading, with no duplicate heading (behavior preserved from PR #1's `1e18e1b` fix).
- User picks "Review via revdiff" three times in a row — re-present the loop each time, no silent exits.

## Materials

- [GitHub Issue #11](https://github.com/yokeloop/yoke/issues/11)
- `skills/task/SKILL.md` — task skill (Phase 6 Complete loop, line 272)
- `skills/plan/SKILL.md` — plan skill (Phase 8 Complete loop, line 298)
- `skills/do/SKILL.md` — do skill (Phase 7 Complete, line 290)
- `skills/fix/SKILL.md` — fix skill (Phase 7 — reference for the destination-naming loop pattern, lines 246-250)
- `skills/gp/agents/git-pre-checker.md` — default-base cascade used by `/do` Phase 7 (lines 43-54)
- `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md` — commit-message convention
- `docs/ai/1-replace-plannotator-with-revdiff/1-replace-plannotator-with-revdiff-review.md` — prior PR review report (scope exclusions at lines 60-63, prior loop-back fix attempt at line 99)
- `README.md:274-323` — Interactive review (revdiff) section (read-only reference)
