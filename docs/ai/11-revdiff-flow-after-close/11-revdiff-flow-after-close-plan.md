# Fix revdiff flow after close — implementation plan

**Task:** docs/ai/11-revdiff-flow-after-close/11-revdiff-flow-after-close-task.md
**Complexity:** simple
**Mode:** sub-agents
**Parallel:** true

## Design decisions

### DD-1: Inline per skill, no shared reference doc

**Decision:** Rewrite the "Review via revdiff" bullet inline in each of the three SKILL.md files. Skip `lib/revdiff-protocol.md` and any per-skill `reference/revdiff-protocol.md`.
**Rationale:** A shared doc would reintroduce the root cause — the model reads "call /revdiff" as the terminal action whenever the reference site repeats the same positional bug. The architect confirmed this (`docs/ai/11-revdiff-flow-after-close/11-revdiff-flow-after-close-task.md`, Patterns section) and the user accepted it at /task time. Each bullet already differs in args and semantics; factoring out saves no real duplication.
**Alternative:** Shared `lib/revdiff-protocol.md` referenced from each bullet. Rejected — indirection at best, recreated bug at worst.

### DD-2: /do applies annotations inline in the orchestrator — no new agent dispatch

**Decision:** When `/do` Phase 7 picks "Review via revdiff" and revdiff returns non-empty annotations, the /do orchestrator reads the annotations, applies any described code changes directly, then appends the annotation text to the report. No Agent tool call spawned for annotation application.
**Rationale:** Matches the existing inline report-append pattern that `/do` Phase 7 already runs (`skills/do/SKILL.md:290` today — the orchestrator appends without dispatch). Annotation scope is small; dispatching a fresh agent adds latency and context-copy overhead. The user confirmed this at /task time.
**Alternative:** Dispatch `skills/do/agents/task-executor.md` with the annotation text as a fresh task. Rejected — heavier, loses the conversational context of the revdiff session.

### DD-3: Detect "annotations returned" via empty-vs-non-empty Skill return

**Decision:** Treat the `/revdiff` Skill tool return as text. Non-empty return means annotations arrived → apply/execute. Empty return means the user quit without annotating → skip apply.
**Rationale:** Simple, forward-compatible, and decouples the SKILL.md from revdiff's internal schema. The `README.md:319-321` Interactive review section already describes revdiff's behavior as "returns structured annotations on quit" without pinning format. The user confirmed this at /task time.
**Alternative:** Pin a JSON schema in the SKILL.md. Rejected — couples yoke to a specific revdiff version and adds failure modes as revdiff evolves.

### DD-4: Loop-back phrasing — byte-identical string across all three files

**Decision:** Each rewritten bullet ends with the exact phrase: `Return to the "Offer 3 options" step above.` The same phrase appears in the install-hint fallback branch of each bullet.
**Rationale:** Matches `/fix` Phase 7's destination-naming pattern (`skills/fix/SKILL.md:248`: "go back to Phase 1 (SLUG is preserved)"), which names where to go. Byte-identical phrasing across all three files lets a Task 4 grep verify consistency and removes the ambiguity of the current "Loop back to the start" that the prior PR #1 failed to resolve (`docs/ai/1-replace-plannotator-with-revdiff/1-replace-plannotator-with-revdiff-review.md:99`).
**Alternative:** Per-skill phrasings (e.g. "re-present the AskUserQuestion", "restart the loop"). Rejected — grep cannot enforce consistency; reintroduces ambiguity.

### DD-5: Continuation obligation stated BEFORE the Skill call

**Decision:** Each rewritten bullet opens with the literal phrase `After revdiff closes, continue with the following steps:` (or an equivalent, grep-discoverable) right before the numbered step list, with the /revdiff Skill call sitting as a middle step — not the last action.
**Rationale:** Root-cause fix (see the task file's Context section). The prior PR #1 fix (`1e18e1b`) sharpened wording but kept the Skill call last in the bullet, so the model kept reading the tool call as terminal. Announcing continuation up front makes the post-close steps an explicit obligation.
**Alternative:** Leave the announcement implicit; rely on numbered-step structure alone. Rejected — numbered steps alone failed to fix the bug during testing of PR #1's clarified wording.

### DD-6: Three independent commits, one per skill file

**Decision:** Tasks 1, 2, and 3 each produce a separate commit for their SKILL.md file. Task 4 (Validation) produces no commit.
**Rationale:** Each skill's change reverts independently; `git bisect` across the three skills stays precise; the commit log reads one bullet rewrite per commit.
**Alternative:** One combined commit for all three files. Rejected — loses revert granularity and complicates diff review (3 nearly identical structural changes in one diff).

## Tasks

### Task 1: Rewrite `skills/task/SKILL.md` "Review via revdiff" bullet

- **Files:** `skills/task/SKILL.md:272` (edit)
- **Depends on:** none
- **Scope:** S
- **What:** Replace the single-line "Review via revdiff" bullet at line 272 with a 4-step inline structure that states the continuation obligation before the `/revdiff` Skill call, handles empty vs non-empty return, and loops back using the canonical phrase.
- **How:**
  1. Read `skills/task/SKILL.md:260-273` for the surrounding Phase 6 Complete loop context.
  2. Replace the entire line at position 272 (the bullet `- **Review via revdiff:** call the Skill tool with /revdiff and the argument --only docs/ai/<task-slug>/<task-slug>-task.md. Apply the returned annotations, overwrite the file. Loop back to the start. If the plugin is missing — print ... then loop back to the start.`) with the new bullet:
     ```
     - **Review via revdiff:** After revdiff closes, continue with the following steps:
       1. Call the Skill tool with `/revdiff` and the argument `--only docs/ai/<task-slug>/<task-slug>-task.md`.
       2. If the Skill return is non-empty, apply the returned annotations to the task file and overwrite `docs/ai/<task-slug>/<task-slug>-task.md`. If the return is empty, skip this step.
       3. Return to the "Offer 3 options" step above.
       If the plugin is missing — print `Install the revdiff plugin:` followed by `  /plugin marketplace add umputun/revdiff` and `  /plugin install revdiff@umputun-revdiff`, then return to the "Offer 3 options" step above.
     ```
  3. Leave every other line untouched. Verify via `git diff --stat` that only `skills/task/SKILL.md` changed.
  4. Commit: `#11 fix(11-revdiff-flow-after-close): restructure task revdiff bullet to execute annotations after close` (per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`).
- **Context:** `skills/task/SKILL.md:254-273` (surrounding Phase 6 Complete loop), `skills/fix/SKILL.md:246-250` (destination-naming reference pattern), `docs/ai/11-revdiff-flow-after-close/11-revdiff-flow-after-close-task.md` (Requirement 1, Constraints).
- **Verify:** `head -1 skills/task/SKILL.md` → `---`; `grep -n "After revdiff closes, continue with the following steps:" skills/task/SKILL.md` → one match at the new bullet; `grep -n "Return to the \"Offer 3 options\" step above." skills/task/SKILL.md` → at least two matches (main path + install-hint fallback); `git diff --stat HEAD~1 HEAD` → only `skills/task/SKILL.md` touched.

### Task 2: Rewrite `skills/plan/SKILL.md` "Review via revdiff" bullet

- **Files:** `skills/plan/SKILL.md:298` (edit)
- **Depends on:** none
- **Scope:** S
- **What:** Replace the single-line "Review via revdiff" bullet at line 298 with the same 4-step inline structure as Task 1, swapping in plan-file args.
- **How:**
  1. Read `skills/plan/SKILL.md:287-299` for the surrounding Phase 8 Complete loop context.
  2. Replace the entire bullet at line 298 with:
     ```
     - **Review via revdiff:** After revdiff closes, continue with the following steps:
       1. Call the Skill tool with `/revdiff` and the argument `--only docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md`.
       2. If the Skill return is non-empty, apply the returned annotations to the plan file and overwrite `docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md`. If the return is empty, skip this step.
       3. Return to the "Offer 3 options" step above.
       If the plugin is missing — print `Install the revdiff plugin:` followed by `  /plugin marketplace add umputun/revdiff` and `  /plugin install revdiff@umputun-revdiff`, then return to the "Offer 3 options" step above.
     ```
  3. Leave every other line untouched. Verify via `git diff --stat`.
  4. Commit: `#11 fix(11-revdiff-flow-after-close): restructure plan revdiff bullet to execute annotations after close`.
- **Context:** `skills/plan/SKILL.md:280-299` (surrounding Phase 8 Complete loop), `docs/ai/11-revdiff-flow-after-close/11-revdiff-flow-after-close-task.md` (Requirement 2, Constraints).
- **Verify:** `head -1 skills/plan/SKILL.md` → `---`; `grep -n "After revdiff closes, continue with the following steps:" skills/plan/SKILL.md` → one match; `grep -n "Return to the \"Offer 3 options\" step above." skills/plan/SKILL.md` → at least two matches; `git diff --stat HEAD~1 HEAD` → only `skills/plan/SKILL.md` touched.

### Task 3: Rewrite `skills/do/SKILL.md` "Review via revdiff" bullet

- **Files:** `skills/do/SKILL.md:290` (edit)
- **Depends on:** none
- **Scope:** M
- **What:** Replace the dense prose bullet at line 290 with the 4-step skeleton. Step 2 (annotation handling) carries a nested sub-list that preserves every semantic from PR #1: base-resolution cascade, inline orchestrator code edits for annotations describing code changes (skip for prose-only annotations), report append under `## Review notes`, `.gitignore` check, auto-commit. Install-hint fallback preserved with canonical loop-back phrasing.
- **How:**
  1. Read `skills/do/SKILL.md:279-291` for the surrounding Phase 7 Complete section.
  2. Replace the entire bullet at line 290 with:
     ```
     - **Review via revdiff:** After revdiff closes, continue with the following steps:
       1. Resolve the default base via the cascade `git symbolic-ref refs/remotes/origin/HEAD` → `origin/main` → `origin/master` → fallback `main` (see `skills/gp/agents/git-pre-checker.md:43-54`). Call the Skill tool with `/revdiff` and the argument `<default-base>...HEAD`.
       2. If the Skill return is non-empty:
          - If the annotations describe code changes, apply those code changes inline (orchestrator edits — do not dispatch a sub-agent). If the annotations are prose-only, skip the code-edit step.
          - Append the full annotation text to `docs/ai/<SLUG>/<SLUG>-report.md`: if a `## Review notes` heading already exists in the file, append under the existing heading; otherwise create the heading and append under it.
          - Check `.gitignore` for `docs/ai/` (same as Phase 6c). If ignored, skip the auto-commit. Otherwise, run `git add docs/ai/<SLUG>/<SLUG>-report.md && git commit -m "TICKET docs(SLUG): append review notes"` (per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`).
          If the Skill return is empty, skip this entire step.
       3. Return to the "Offer 3 options" step above.
       If the plugin is missing — print `Install the revdiff plugin:` followed by `  /plugin marketplace add umputun/revdiff` and `  /plugin install revdiff@umputun-revdiff`, then return to the "Offer 3 options" step above.
     ```
  3. Leave every other line untouched. Verify via `git diff --stat`.
  4. Commit: `#11 fix(11-revdiff-flow-after-close): restructure do revdiff bullet to execute annotations after close`.
- **Context:** `skills/do/SKILL.md:275-291` (surrounding Phase 7 Complete + Phase 6c gitignore pattern), `skills/gp/agents/git-pre-checker.md:43-54` (default-base cascade), `docs/ai/11-revdiff-flow-after-close/11-revdiff-flow-after-close-task.md` (Requirement 3, Constraints).
- **Verify:** `head -1 skills/do/SKILL.md` → `---`; `grep -n "After revdiff closes, continue with the following steps:" skills/do/SKILL.md` → one match; `grep -n "Return to the \"Offer 3 options\" step above." skills/do/SKILL.md` → at least two matches; `grep -n "append review notes" skills/do/SKILL.md` → one match (commit-message string preserved); `grep -n "skills/gp/agents/git-pre-checker.md:43-54" skills/do/SKILL.md` → one match (cascade reference preserved); `git diff --stat HEAD~1 HEAD` → only `skills/do/SKILL.md` touched.

### Task 4: Validation

- **Files:** none modified
- **Depends on:** Task 1, Task 2, Task 3
- **Scope:** S
- **What:** Run the full post-edit validation suite. Confirm all three rewrites parse cleanly, stay byte-consistent on the shared phrases, preserve PR #1 semantics, and pass repo-level format checks.
- **How:**
  1. JSON parse: `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"`.
  2. YAML frontmatter preserved: `head -1 skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` — each file's first line must read `---`.
  3. Continuation obligation placed before the Skill call in all three files: `grep -n "After revdiff closes, continue with the following steps:" skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` — exactly 3 matches, one per file. Each match's line number must fall strictly below the line number of the first `/revdiff` Skill call reference in the same bullet.
  4. Loop-back phrase byte-identical across all three files: `grep -cn "Return to the \"Offer 3 options\" step above." skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` — each file shows ≥ 2 matches (main path + install-hint fallback).
  5. Empty-return skip branch present in all three files: `grep -c "If the Skill return is empty" skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` — each file shows ≥ 1 match (phrasing may read "If the return is empty" for task/plan or "If the Skill return is empty" for do; accept either variant).
  6. `/do` Phase 7 semantics from PR #1 intact: `grep -n "append review notes" skills/do/SKILL.md` — 1 match (commit message preserved); `grep -n "## Review notes" skills/do/SKILL.md` — ≥ 1 match (heading semantics preserved); `grep -n "skills/gp/agents/git-pre-checker.md:43-54" skills/do/SKILL.md` — 1 match (cascade reference preserved).
  7. Prettier format check: `pnpm run format:check` — no new failures on the three edited files.
- **Context:** none (pure verification).
- **Verify:** every command in steps 1–7 exits 0 with the expected outputs above; `pnpm run format:check` reports no new failures.

## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** The three independent single-file bullet rewrites share no files or state; a final validation barrier checks cross-file byte consistency on the pre-agreed phrases.
- **Order:**
  Group 1 (parallel): Task 1, Task 2, Task 3
  ─── barrier ───
  Group 2 (sequential): Task 4

## Verification

- **Manual — `/yoke:task` with annotations:** run `/yoke:task <ticket>` → reach Phase 6 Complete → pick "Review via revdiff" → add annotations in revdiff → quit → task file overwritten with annotations applied → `AskUserQuestion` with 3 options reappears.
- **Manual — `/yoke:task` without annotations:** same as above, but quit revdiff without adding annotations → task file unchanged → `AskUserQuestion` with 3 options reappears.
- **Manual — `/yoke:plan` with annotations:** run `/yoke:plan <task-path>` → reach Phase 8 Complete → pick "Review via revdiff" → annotate → quit → plan file overwritten with annotations → `AskUserQuestion` reappears.
- **Manual — `/yoke:plan` without annotations:** same, quit without annotating → plan file unchanged → `AskUserQuestion` reappears.
- **Manual — `/yoke:do` with annotations:** run `/yoke:do <plan-path>` → reach Phase 7 Complete → pick "Review via revdiff" → annotate code regions → quit → code changes described in annotations land in the affected files → annotation text appended under `## Review notes` in `docs/ai/<SLUG>/<SLUG>-report.md` → (if `docs/ai/` stays out of `.gitignore`) auto-commit `TICKET docs(SLUG): append review notes` created → `AskUserQuestion` reappears.
- **Manual — `/yoke:do` without annotations:** same, quit without annotating → no code changes, no report append, no commit → `AskUserQuestion` reappears.
- **Manual — revdiff plugin missing:** in any of the three skills, pick "Review via revdiff" when `/revdiff` is not installed → install-hint prints → `AskUserQuestion` reappears.
- **Manual — loop termination:** loop through "Review via revdiff" at least twice, then pick **Finish** → loop exits and the skill reports the file path.
- **Manual — `docs/ai/` gitignored (`/yoke:do` only):** add `docs/ai/` to local `.gitignore` → `/yoke:do` Phase 7 revdiff path with annotations → report file updated, auto-commit skipped, `AskUserQuestion` reappears.
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"` → `OK`.
- `head -1 skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` → each file starts with `---`.
- `pnpm run format:check` → no new failures.

## Materials

- [GitHub Issue #11](https://github.com/yokeloop/yoke/issues/11)
- `skills/task/SKILL.md:272` — task bullet
- `skills/plan/SKILL.md:298` — plan bullet
- `skills/do/SKILL.md:290` — do bullet
- `skills/fix/SKILL.md:246-250` — destination-naming loop pattern
- `skills/gp/agents/git-pre-checker.md:43-54` — default-base cascade used by `/do`
- `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md` — commit-message convention
- `docs/ai/1-replace-plannotator-with-revdiff/1-replace-plannotator-with-revdiff-review.md` — prior PR review (scope at :60-63, prior attempted fix at :99)
- `README.md:274-323` — Interactive review (revdiff) section (read-only reference)
