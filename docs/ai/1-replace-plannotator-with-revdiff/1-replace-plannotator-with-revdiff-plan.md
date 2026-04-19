# Replace plannotator with revdiff — implementation plan

**Task:** docs/ai/1-replace-plannotator-with-revdiff/1-replace-plannotator-with-revdiff-task.md
**Complexity:** medium
**Mode:** sub-agents
**Parallel:** true

## Design decisions

### DD-1: Missing-plugin detection — try-and-catch, not bash probe

**Decision:** Each Complete loop invokes `/revdiff` through the Skill tool; on failure the orchestrator prints the install hint and loops back to AskUserQuestion.
**Rationale:** Skill-tool errors surface as a tool result, so a pre-check would duplicate the runtime failure. The task constraint forbids bash invocation, and `skills/gp/SKILL.md:42` already uses a "print hint, exit" pattern we mirror with "print hint, loop back".
**Alternative:** Pre-flight probe via `command -v revdiff` or `claude plugin list` — violates the Skill-tool-only constraint and couples yoke to CLI internals.

### DD-2: Append-review-notes commit message

**Decision:** `#1 docs(1-replace-plannotator-with-revdiff): append review notes`.
**Rationale:** The commit appends documentation only (to `docs/ai/<SLUG>/<SLUG>-report.md`), matching the `docs` type in `skills/gca/reference/commit-convention.md`. The slug comes from the active task directory, per the convention's "Within yoke flow" rule.
**Alternative:** `chore` or `refactor` — wrong type; no behavior or code refactor happens.

### DD-3: `docs/do.md` — rename Stage 7 "Report" to "Complete", keep 7 stages

**Decision:** Fold the report-writing step and the 3-option loop into a single renamed Stage 7 cell.
**Rationale:** The pipeline diagram in `skills/do/SKILL.md:42-50` shows exactly 7 stages with "Complete" at stage 7. An 8th row would drift from SKILL.md.
**Alternative:** Add Stage 8 — diverges from the skill.

### DD-4: `docs/plan.md` — add Phase 7 and Phase 8, fix stale "only interaction point" sentence

**Decision:** Add rows for Phase 7 (Commit artifact) and Phase 8 (Complete), update the intro "6 sequential phases" → "8", and reword `docs/plan.md:17` "The only interaction point is Checkpoint" to reflect Phase 8 as a second interaction point.
**Rationale:** Without the reword, the intro contradicts the new Phase 8 row. The pre-existing Phase-5 "Checkpoint"-vs-"Review" label drift stays out of scope — it predates this task and the requirements skip it.
**Alternative:** Add only Phase 7/8 rows and leave the intro sentence alone — the plan file becomes factually wrong the moment the new row lands.

### DD-5: README placement — new section before `## References`

**Decision:** Insert the new `## Interactive review (revdiff)` heading directly before `## References` (current `README.md:274`).
**Rationale:** Task verification mandates this position; external links stay grouped together at the bottom.
**Alternative:** After `## Full cycle` or inside `## Skills` — splits the links and breaks the task verification criterion.

### DD-6: Task/plan-file annotation protocol — reuse existing wording verbatim

**Decision:** Keep the sentence "Apply the returned annotations, overwrite the file. Loop back to the start." from `skills/task/SKILL.md:272` and `skills/plan/SKILL.md:298` unchanged.
**Rationale:** revdiff's output contract (annotated markdown) matches plannotator's for this call shape. Only the skill name and argument form (`/revdiff --only <path>`) change; no new protocol needed.
**Alternative:** Introduce a new protocol — unnecessary churn; nothing in revdiff's contract demands it.

### DD-7: `skills/do/SKILL.md:82` TodoWrite label update is folded into Task 1

**Decision:** Update the TodoWrite template string `Complete: review / finish` → `Complete: review / revdiff / finish` inside the same commit as the Phase 7 rewrite.
**Rationale:** The string labels Phase 7's option shape. A second commit would fragment a single logical change across two commits.
**Alternative:** Separate commit — splits a tiny sibling edit for no reviewer benefit.

## Tasks

### Task 1: Swap plannotator → revdiff in `/task`, `/plan`, `/do` SKILL.md files

- **Files:** `skills/task/SKILL.md` (L266, L272 + install-hint addition), `skills/plan/SKILL.md` (L292, L298 + install-hint addition), `skills/do/SKILL.md` (L49 pipeline-overview, L82 TodoWrite label, L279-289 Phase 7 rewrite)
- **Depends on:** none
- **Scope:** M
- **What:** Replace every "Review via plannotator" / `/plannotator-annotate` reference with "Review via revdiff" / `/revdiff`. Expand `/do` Phase 7 from 2 to 3 options. Add a literal 2-line install hint to every revdiff branch.
- **How:**
  - `skills/task/SKILL.md:266` — option label → `2. **Review via revdiff** — interactive review of the task file`.
  - `skills/task/SKILL.md:272` — handler → "call the Skill tool with `/revdiff` and the argument `--only docs/ai/<task-slug>/<task-slug>-task.md`. Apply the returned annotations, overwrite the file. Loop back to the start. If the plugin is missing — print `Install the revdiff plugin:\n  /plugin marketplace add umputun/revdiff\n  /plugin install revdiff@umputun-revdiff` and loop back to the start."
  - `skills/plan/SKILL.md:292, 298` — same two edits, with plan path `docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md`.
  - `skills/do/SKILL.md:49` — `7. Complete     → review / plannotator / finish` → `7. Complete     → review / revdiff / finish`.
  - `skills/do/SKILL.md:82` — TodoWrite line `[ ] Complete: review / finish` → `[ ] Complete: review / revdiff / finish`.
  - `skills/do/SKILL.md:279-289` — rewrite Phase 7: expand from 2 options to 3 (`Run /yoke:review (Recommended)` / `Review via revdiff` / `Finish`). The new middle option invokes `/revdiff <default-base>...HEAD`, where `<default-base>` resolves via the cascade `git symbolic-ref refs/remotes/origin/HEAD` → `origin/main` → `origin/master` → fallback `main` (mirrors `skills/gp/agents/git-pre-checker.md:43-54`). Append returned annotations to `docs/ai/<SLUG>/<SLUG>-report.md` under a new `## Review notes` heading. Auto-commit with `git add docs/ai/<SLUG>/<SLUG>-report.md && git commit -m "TICKET docs(SLUG): append review notes"` (per `skills/gca/reference/commit-convention.md`). Loop back. Install-hint fallback matches `/task` and `/plan`.
  - Leave `skills/do/SKILL.md:273` notify block untouched — Phase 6d STAGE_COMPLETE stays intact; the new Phase 7 loop runs after it.
- **Context:**
  - `skills/task/SKILL.md:254-273` (current Phase 6)
  - `skills/plan/SKILL.md:280-299` (current Phase 8)
  - `skills/do/SKILL.md:42-50, 73-83, 267-289` (pipeline header, TodoWrite template, Phase 6d and Phase 7)
  - `skills/gp/SKILL.md:38-45` (install-hint pattern)
  - `skills/gp/agents/git-pre-checker.md:40-54` (default-base cascade)
  - `skills/gca/reference/commit-convention.md` (commit format)
- **Verify:**
  - `grep -rn plannotator skills/task skills/plan skills/do` → zero matches.
  - `grep -n "Review via revdiff" skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` → one match per file.
  - `grep -n "append review notes" skills/do/SKILL.md` → at least one match (DD-2 commit wording).
  - `grep -n "Install the revdiff plugin" skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` → one match per file.
  - `grep -n "review / revdiff / finish" skills/do/SKILL.md` → one match at L49, one at L82.
  - `head -1 skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` → first line is `---` in each (YAML frontmatter intact).

### Task 2: Update phase/pipeline tables in `docs/task.md`, `docs/plan.md`, `docs/do.md`

- **Files:** `docs/task.md` (L25), `docs/plan.md` (L17 intro, L17-26 phases table), `docs/do.md` (L28)
- **Depends on:** none
- **Scope:** M
- **What:** Rewrite the three doc tables to match the new skill flows. Extend `docs/plan.md` with Phase 7 and Phase 8 rows. Rename `docs/do.md` Stage 7 to "Complete". Replace `plannotator` with `revdiff` in `docs/task.md`.
- **How:**
  - `docs/task.md:25` — replace "review via plannotator" with "review via revdiff" in the Phase 6 cell. Keep pipe alignment.
  - `docs/plan.md:17` — change `"6 sequential phases"` to `"8 sequential phases"` and reword `"The only interaction point is Checkpoint."` to `"Interaction points: Checkpoint (Phase 5) and Complete (Phase 8)."` (DD-4).
  - `docs/plan.md:19-26` — append two table rows:
    - `| 7     | **Commit**     | Auto-commit the artifact: TICKET docs(SLUG): add implementation plan |`
    - `| 8     | **Complete**   | Completion loop: run /yoke:do (recommended) / review via revdiff / finish |`
  - `docs/do.md:28` — rename Stage 7 label from `**Report**` to `**Complete**` and fold both steps into the cell: `Write the report file, format code, send notification; then completion loop: /yoke:review (recommended) / review via revdiff / finish`.
- **Context:**
  - `docs/task.md:17-25` (existing phase table for column shape)
  - `docs/plan.md:17-26` (existing phase table + intro sentence to reword)
  - `docs/do.md:19-28` (existing pipeline table)
- **Verify:**
  - `grep -rn plannotator docs/` → zero matches.
  - `grep -n "revdiff" docs/task.md docs/plan.md docs/do.md` → at least one match per file.
  - `grep -n "8 sequential phases" docs/plan.md` → one match at L17.
  - `grep -nE "^\| 7 +\| \*\*Commit\*\*" docs/plan.md` → one match.
  - `grep -nE "^\| 8 +\| \*\*Complete\*\*" docs/plan.md` → one match.
  - `grep -nE "^\| 7 +\| \*\*Complete\*\*" docs/do.md` → one match.

### Task 3: Update `README.md` — remove plannotator link, add Interactive review section

- **Files:** `README.md` (delete L278, insert new section before L274)
- **Depends on:** none
- **Scope:** M
- **What:** Delete the `https://plannotator.ai/` bullet under `## References`. Insert a new `## Interactive review (revdiff)` section directly before `## References`.
- **How:**
  - Delete `README.md:278` (`- https://plannotator.ai/`).
  - Insert a new section before `## References` (before current L274) with:
    - One-sentence opening describing revdiff's role in yoke.
    - Install subsection: fenced `text` block with the two commands (`/plugin marketplace add umputun/revdiff` then `/plugin install revdiff@umputun-revdiff`).
    - Terminal requirements: bulleted list — tmux, Zellij, kitty, wezterm, Kaku, cmux, ghostty (macOS), iTerm2 (macOS), Emacs vterm — with a short sentence requiring one of these; otherwise the plugin exits with an error.
    - Usage per yoke integration point — three bullets with fenced examples: `/revdiff --only docs/ai/<slug>/<slug>-task.md` (from `/yoke:task` Phase 6), `/revdiff --only docs/ai/<slug>/<slug>-plan.md` (from `/yoke:plan` Phase 8), `/revdiff <base>...HEAD` (from `/yoke:do` Phase 7).
    - Fold-back behavior: one short paragraph — markdown artifacts get annotations applied in place (file overwritten); `/do` code review annotations append to `docs/ai/<slug>/<slug>-report.md`.
    - Upstream link: `See https://github.com/umputun/revdiff (MIT) for binary install paths and deeper documentation.`
  - Skip brew / deb / rpm / AUR / raw binaries.
- **Context:**
  - `README.md:258-283` (current Development + References sections, for style reference)
  - `docs/ai/1-replace-plannotator-with-revdiff/1-replace-plannotator-with-revdiff-task.md` Requirement 11 (full content spec)
- **Verify:**
  - `grep -n plannotator README.md` → zero matches.
  - `grep -n "## Interactive review (revdiff)" README.md` → one match.
  - `grep -n "## References" README.md` → one match, with line number greater than the "Interactive review" heading.
  - `grep -nE "brew install|dpkg|rpm|paru|AUR" README.md` → zero matches (constraint: no binary install details).
  - `grep -n "https://github.com/umputun/revdiff" README.md` → at least one match.

### Task 4: Validation

- **Files:** —
- **Depends on:** Task 1, Task 2, Task 3
- **Scope:** S
- **What:** Confirm the codebase-wide state matches every acceptance criterion from the task file.
- **How:** Run the commands below against the finished tree. On any failure, surface it to the orchestrator rather than patching silently.
- **Context:** — (read-only)
- **Verify:**
  - `grep -R plannotator . --exclude-dir=.git --exclude-dir=docs/ai` → zero matches (the task artifacts in `docs/ai/` contain the word and are excluded).
  - `grep -rn "/revdiff" skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` → ≥1 match in each file.
  - `grep -n "Install the revdiff plugin" skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` → one match per file.
  - `head -1 skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md docs/task.md docs/plan.md docs/do.md` → first line `---` on skills, `# ...` on docs (no broken frontmatter).
  - `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"` → prints `OK`.
  - `pnpm run format:check` → passes.

## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** 4 tasks, 3 with disjoint files (skills vs docs vs README), validation after barrier — routing-rules row 4 (medium, 3+ tasks, no intersections, no cross-layer).
- **Order:**
  ```
  Group 1 (parallel):
    Task 1: Skills swap
    Task 2: Docs tables
    Task 3: README
  ─── barrier ───
  Group 2 (sequential):
    Task 4: Validation
  ```

## Resolved questions

- **Missing-plugin handling** — try-and-catch, print install hint, loop back (DD-1, Req 5).
- **Plannotator removal** — hard-remove from `skills/`; no fallback; the external skill stays invokable manually (user's choice during Synthesize).
- **`/do` Phase 7 shape** — 3 options (review / revdiff / finish) to match the pipeline overview at L49 and TodoWrite label at L82 (user's choice; DD-3 / DD-7).
- **`/do` revdiff target** — `<default-base>...HEAD` resolved via the `git-pre-checker` cascade (user's choice; Req 3).
- **Docs scope** — `docs/plan.md` and `docs/do.md` expand in this task (user's choice; Task 2).
- **README install path** — plugin-only install; upstream link for binaries (user's choice; Task 3).
- **TTY integration** — moot: revdiff ships as a Claude Code plugin invoked via the Skill tool, not as a bash subprocess (user's clarification).

## Verification

- `grep -rn plannotator skills/ docs/ README.md CLAUDE.md` — zero matches after the change.
- `grep -rn "/revdiff" skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` — at least one match per file in the Complete phase.
- `head -1 skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` — prints `---` (YAML frontmatter intact).
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"` — prints `OK`.
- Manual smoke: `/yoke:task <short description>` → pick "Review via revdiff" at Phase 6 → revdiff opens → annotate → quit with `q` → annotations fold into the task file → AskUserQuestion re-appears. Equivalent smoke for `/yoke:plan` and for `/yoke:do` on a plan that produces ≥1 commit.
- Negative case: uninstall the revdiff plugin, pick "Review via revdiff" → the two `/plugin` install commands print and the Complete AskUserQuestion re-appears without crashing.
- `README.md` renders a new `## Interactive review (revdiff)` section above `## References`; References no longer contains `plannotator.ai`.
- `docs/plan.md` phases table has rows for Phase 7 (Commit artifact) and Phase 8 (Complete).
- `docs/do.md` pipeline table describes Phase 7 Complete with the three-option loop.
- `pnpm run format:check` passes on all changed markdown.

## Materials

- https://github.com/yokeloop/yoke/issues/1 — ticket
- https://github.com/umputun/revdiff — revdiff upstream (MIT)
- `/plugin marketplace add umputun/revdiff` — revdiff plugin marketplace
- `/plugin install revdiff@umputun-revdiff` — revdiff plugin install
- `skills/task/SKILL.md:254-273` — current `/task` Phase 6 Complete loop
- `skills/plan/SKILL.md:280-299` — current `/plan` Phase 8 Complete loop
- `skills/do/SKILL.md:49, 82, 279-289` — current `/do` pipeline overview, TodoWrite label, Phase 7
- `skills/gp/SKILL.md:38-45` — reference pattern for missing-CLI install hint
- `skills/gp/agents/git-pre-checker.md:40-54` — default-branch cascade for `<base>` resolution
- `skills/gca/reference/commit-convention.md` — commit format for docs(SLUG) updates
- `docs/task.md:17-25`, `docs/plan.md:17-26`, `docs/do.md:19-28` — docs tables to extend
- `README.md:258-283` — Development + References sections (style reference + insertion point)
