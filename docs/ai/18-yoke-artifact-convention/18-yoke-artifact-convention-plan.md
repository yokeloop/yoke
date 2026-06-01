# S1 — `.yoke/` artifact convention + path migration — implementation plan

**Task:** docs/ai/18-yoke-artifact-convention/18-yoke-artifact-convention-task.md
**Complexity:** complex
**Mode:** sub-agents
**Parallel:** true

## Design decisions

### DD-1: Glossary collapse is a prose edit, not a file move

**Decision:** Treat the single-`.yoke/context.md` migration as pure prose/doc editing — retire the `CONTEXT-MAP.md` multi-context branch in `skills/grill-docs/SKILL.md` and `CONTEXT-FORMAT.md`, rewrite them for one glossary file.
**Rationale:** No root `CONTEXT.md` or `CONTEXT-MAP.md` files exist in the repo — they are referenced only as a convention inside skill prose. Confirmed by the architect reading the tree.
**Alternative:** `git mv` a physical glossary file — rejected: there is nothing to move.

### DD-2: Path edits are literal replace-in-place across disjoint file sets

**Decision:** Each skill/cluster owns a disjoint set of files; migrate `docs/ai/`→`.yoke/ai/`, `docs/adr/`→`.yoke/adr/`, `CONTEXT.md`→`.yoke/context.md` in place per cluster.
**Rationale:** Paths are hard-coded literal strings with no shared variable (`skills/explore/agents/explore-log-writer.md:37` `EXPLORATION_LOG="docs/ai/..."`); `lib/notify.sh` already models the `.yoke/`-relative form. Disjoint files → safe parallel fan-out.
**Alternative:** Introduce a shared path variable/manifest — rejected by ADR 0004 (fixed paths, no parsing).

### DD-3: `/sync-docs` runs last among doc tasks (hard barrier)

**Decision:** Edit SKILL.md `description` fields and the hand-edited README/CLAUDE sections first; run `/yoke:sync-docs` afterward to regenerate the sentinel-managed catalog rows and MDX.
**Rationale:** README rows 61/65/68 and CLAUDE rows 71/75/78 sit inside `<!-- yoke:skills:start -->` markers and are generated from each SKILL.md `description` (confirmed: README 50–73, CLAUDE 62–83). Hand-editing them is overwritten; running `/sync-docs` before the description edits regenerates stale text.
**Alternative:** Hand-edit the rows — rejected by constraint and by the sentinel mechanism.

### DD-4: Simplify the gitignore probe only in in-scope skills

**Decision:** Replace the `Check docs/ai against .gitignore` probe with the single "is `.yoke/` ignored?" escape-hatch in `review`, `plan`, `task`. Leave `do`'s identical probes (`skills/do/SKILL.md:222,261`) untouched.
**Rationale:** `do` is deferred to S3; touching it violates the constraint. The probes are independent per file, so simplifying only in-scope ones is safe.
**Alternative:** Strip all probes repo-wide — rejected: out of scope for `do`/`bootstrap`.

### DD-5: Changing `commit-convention.md:99` is forward-correct despite `do` reading it

**Decision:** Update the illustrative `docs/ai/` slug-derivation example at `skills/gca/reference/commit-convention.md:99` to `.yoke/ai/`, even though out-of-scope `do` reads this file.
**Rationale:** Line 99 is an illustrative example for slug derivation, not executable logic; `do` continues to function with its own literal paths until its slice. No runtime coupling.
**Alternative:** Leave the example stale — rejected: leaves an in-scope reference file half-migrated and would fail the verification grep.

## Tasks

### Task 1: ADR move + `.gitignore` narrow + sync-spec

- **Files:** `docs/adr/0001-*.md`..`0005-*.md` (git mv → `.yoke/adr/`), `.gitignore` (edit line 2), `skills/sync-docs/reference/sync-spec.md:93` (edit)
- **Depends on:** none
- **Scope:** S
- **What:** Move the five ADR files into `.yoke/adr/`, narrow the blanket `.yoke/` ignore to two scratch paths, and fix the sync-spec assertion.
- **How:** `git mv docs/adr/000{1,2,3,4,5}-*.md .yoke/adr/` (create `.yoke/adr/` first); remove the now-empty `docs/adr/`. In `.gitignore`, replace the `.yoke/` blanket entry with exactly `.yoke/sync-docs-tmp/` and `.yoke/notify-pending.json`. In `sync-spec.md:93`, change "`.yoke/` is gitignored" → "`.yoke/sync-docs-tmp/` is gitignored". Do NOT rewrite ADR 0004's body prose.
- **Context:** `.gitignore`, `skills/sync-docs/reference/sync-spec.md:90-95`, `docs/adr/`
- **Verify:** `ls .yoke/adr/` shows 0001–0005; `test ! -d docs/adr || ls docs/adr` empty; `git check-ignore .yoke/ai` exits non-zero (not ignored)

### Task 2: grill-docs glossary collapse

- **Files:** `skills/grill-docs/SKILL.md` (description + body), `skills/grill-docs/reference/domain-docs.md`, `.../ADR-FORMAT.md`, `.../CONTEXT-FORMAT.md`
- **Depends on:** none
- **Scope:** M
- **What:** Migrate grill-docs to `.yoke/context.md` + `.yoke/adr/` and retire the multi-context (`CONTEXT-MAP.md` + per-context) branch in favor of one glossary file.
- **How:** `SKILL.md` description (lines 5,6,10) and body (39,47,51–60,63,69,83,85,87,105,106): `CONTEXT.md`→`.yoke/context.md`, `docs/adr/`→`.yoke/adr/`; delete the `CONTEXT-MAP.md`/per-context branch (47,51–60), collapse to one `.yoke/context.md`. `domain-docs.md:7,8,9,15`: drop the `CONTEXT-MAP.md` bullet, point to single `.yoke/context.md` + `.yoke/adr/`. `ADR-FORMAT.md:3,5,27`: `docs/adr/`→`.yoke/adr/`. `CONTEXT-FORMAT.md:1,37,46–48,59–61`: retire multi-context section, document a single `.yoke/context.md`.
- **Context:** `skills/grill-docs/SKILL.md`, `skills/grill-docs/reference/{domain-docs,ADR-FORMAT,CONTEXT-FORMAT}.md`
- **Verify:** `grep -rn "CONTEXT-MAP\|docs/adr\|\bCONTEXT\.md" skills/grill-docs/` → no matches

### Task 3: grill prose

- **Files:** `skills/grill/SKILL.md:8,51`
- **Depends on:** none
- **Scope:** S
- **What:** Update grill's glossary-name references to `.yoke/context.md`.
- **How:** Lines 8 (description) and 51: `CONTEXT.md`→`.yoke/context.md`.
- **Context:** `skills/grill/SKILL.md:1-12,45-55`
- **Verify:** `grep -n "CONTEXT.md" skills/grill/SKILL.md` → no matches

### Task 4: prd + issues

- **Files:** `skills/prd/SKILL.md`, `skills/issues/SKILL.md`, `skills/issues/reference/github-issues.md`
- **Depends on:** none
- **Scope:** M
- **What:** Migrate prd and issues artifact paths and domain-doc reads to `.yoke/`.
- **How:** `prd/SKILL.md`: description line 5 (`docs/ai`→`.yoke/ai`); body 17 (`CONTEXT.md`/`CONTEXT-MAP.md`→`.yoke/context.md`, `docs/adr/`→`.yoke/adr/`), 23,25,28 (`docs/ai/<slug>/`→`.yoke/ai/<slug>/`, incl. the `mkdir -p`). `issues/SKILL.md`: description line 6, body 23,69. `github-issues.md:10,14`: `docs/ai/`→`.yoke/ai/`.
- **Context:** `skills/prd/SKILL.md`, `skills/issues/SKILL.md`, `skills/issues/reference/github-issues.md`
- **Verify:** `grep -rn "docs/ai\|docs/adr\|CONTEXT-MAP\|\bCONTEXT\.md" skills/prd skills/issues` → no matches

### Task 5: review (paths + probe simplification)

- **Files:** `skills/review/SKILL.md`, `skills/review/agents/code-reviewer.md:36`
- **Depends on:** none
- **Scope:** M
- **What:** Migrate review's paths and replace its gitignore probe with the single `.yoke/` escape-hatch.
- **How:** `SKILL.md` 29,53,54,56,63,64,146,165,193: `docs/ai`→`.yoke/ai`. Line 160: replace `Check docs/ai against .gitignore` with "If `.yoke/` is gitignored, skip the commit."; keep the commit block (165–167) otherwise. `code-reviewer.md:36`: `docs/ai/<slug>/`→`.yoke/ai/<slug>/`.
- **Context:** `skills/review/SKILL.md:25-70,140-170,190-195`, `skills/review/agents/code-reviewer.md:30-40`
- **Verify:** `grep -n "docs/ai" skills/review/SKILL.md skills/review/agents/code-reviewer.md` → no matches; `grep -n "gitignore" skills/review/SKILL.md` references `.yoke/` only

### Task 6: gca (paths in SKILL + reference)

- **Files:** `skills/gca/SKILL.md:26,47,69`, `skills/gca/reference/commit-convention.md:99`, `skills/gca/reference/staging-strategy.md:20`
- **Depends on:** none
- **Scope:** S
- **What:** Migrate gca's staging patterns and convention examples to `.yoke/ai/`.
- **How:** Replace `docs/ai/**`→`.yoke/ai/**` and `docs/ai/<SLUG>/`→`.yoke/ai/<SLUG>/` at the cited lines (per DD-5, the commit-convention example is safe to change).
- **Context:** `skills/gca/SKILL.md:24-70`, `skills/gca/reference/{commit-convention.md:95-102,staging-strategy.md:18-22}`
- **Verify:** `grep -rn "docs/ai" skills/gca/` → no matches

### Task 7: plan (SKILL + examples + probe simplification)

- **Files:** `skills/plan/SKILL.md`, `skills/plan/examples/*.md`
- **Depends on:** none
- **Scope:** M
- **What:** Migrate plan's paths and replace its gitignore probe with the single `.yoke/` escape-hatch.
- **How:** `SKILL.md` 23,124,216,235,247,248: `docs/ai`→`.yoke/ai`; line 211: simplify probe to "is `.yoke/` ignored?". `examples/{simple-plan,complex-plan}.md`: replace `docs/ai/` path strings.
- **Context:** `skills/plan/SKILL.md:20-25,120-128,205-250`, `skills/plan/examples/*.md`
- **Verify:** `grep -rn "docs/ai" skills/plan/` → no matches

### Task 8: task (SKILL + examples + probe simplification)

- **Files:** `skills/task/SKILL.md`, `skills/task/examples/*.md`
- **Depends on:** none
- **Scope:** M
- **What:** Migrate task's paths and replace its gitignore probe with the single `.yoke/` escape-hatch.
- **How:** `SKILL.md` 134,136,202,219,231,232: `docs/ai`→`.yoke/ai`; line 197: simplify probe. `examples/{simple-task,complex-task}.md`: replace `docs/ai/` path strings.
- **Context:** `skills/task/SKILL.md:130-140,190-235`, `skills/task/examples/*.md`
- **Verify:** `grep -rn "docs/ai" skills/task/` → no matches

### Task 9: explore + fix (SKILL + agents + reference)

- **Files:** `skills/explore/SKILL.md`, `skills/explore/agents/explore-log-writer.md`, `skills/fix/SKILL.md`, `skills/fix/agents/fix-context-collector.md`, `skills/fix/agents/fix-log-writer.md`, `skills/fix/reference/fix-log-format.md`
- **Depends on:** none
- **Scope:** M
- **What:** Migrate explore and fix path strings, including the `EXPLORATION_LOG=` shell var and `ls -td docs/ai/*/`.
- **How:** `explore/SKILL.md:134,139`; `explore-log-writer.md:37,46,77` (incl. `EXPLORATION_LOG="docs/ai/{{SLUG}}/..."`→`.yoke/ai/`). `fix/SKILL.md:227`; `fix-context-collector.md:44,45,75,92,93,94` (incl. `ls -td docs/ai/*/`→`.yoke/ai/*/`); `fix-log-writer.md:53,62,74,86`; `fix-log-format.md:12`.
- **Context:** explore + fix trees
- **Verify:** `grep -rn "docs/ai" skills/explore skills/fix` → no matches

### Task 10: help + handoff prose

- **Files:** `skills/help/SKILL.md`, `skills/handoff/SKILL.md`
- **Depends on:** none
- **Scope:** M
- **What:** Fix /help prose so it reports `.yoke/` locations, and add a note to handoff that artifacts live under `.yoke/`.
- **How:** `help/SKILL.md` 16,28,31,38,41,48,91,102,121,123,133,143: `docs/ai`/`docs/adr`/`CONTEXT.md`→`.yoke/` equivalents. `handoff/SKILL.md`: add one sentence that referenced artifacts now live under `.yoke/` (no path strings to change — handoff writes to OS temp).
- **Context:** `skills/help/SKILL.md`, `skills/handoff/SKILL.md`
- **Verify:** `grep -n "docs/ai\|docs/adr\|\bCONTEXT\.md" skills/help/SKILL.md` → no matches

### Task 11: lib/pr-collect.sh

- **Files:** `lib/pr-collect.sh:50,51,53`
- **Depends on:** none
- **Scope:** S
- **What:** Update /pr artifact discovery to resolve `.yoke/ai/`.
- **How:** Lines 50,51,53: `docs/ai/$SLUG/...`→`.yoke/ai/$SLUG/...`, `ls -td docs/ai/*/`→`ls -td .yoke/ai/*/`.
- **Context:** `lib/pr-collect.sh:45-55`, `lib/notify.sh` (reference for `.yoke/`-relative paths)
- **Verify:** `grep -n "docs/ai" lib/pr-collect.sh` → no matches; `bash -n lib/pr-collect.sh` → ok

### Task 12: README + CLAUDE hand-edited sections + new convention doc

- **Files:** `README.md` (186,188,262,267,278 + new section), `CLAUDE.md` (103 + new section)
- **Depends on:** none
- **Scope:** M
- **What:** Migrate the hand-edited (non-sentinel) path references and document the `.yoke/` convention in both files.
- **How:** README — lines 186,188 (Structure tree comments), 262,267,278 (revdiff paths): `docs/ai`→`.yoke/ai`, `CONTEXT.md`/`docs/adr/` updated; add a `.yoke/` convention subsection (under "## Structure" or before "## Full cycle") describing `.yoke/ai/<slug>/`, `.yoke/context.md`, `.yoke/adr/`, `.yoke/journal.md`, and the two gitignored scratch paths. CLAUDE — line 103 (`CONTEXT.md`→`.yoke/context.md`); add a `.yoke/` convention subsection under "## Conventions". Do NOT touch sentinel rows (README 61/65/68, CLAUDE 71/75/78) or the journal bullet (CLAUDE:93).
- **Context:** `README.md:50-73,180-190,255-280`, `CLAUDE.md:51-83,100-105`
- **Verify:** `grep -n "docs/ai\|docs/adr" README.md CLAUDE.md` → matches only inside sentinel rows (regenerated by Task 13)

### Task 13: run /sync-docs (regenerate sentinel rows + MDX)

- **Files:** `README.md` (sentinel block), `CLAUDE.md` (sentinel block), `site/src/content/docs/skills/*.mdx`
- **Depends on:** Task 2, Task 3, Task 4, Task 12
- **Scope:** S
- **What:** Regenerate the catalog rows and per-skill MDX from the edited SKILL.md descriptions.
- **How:** Invoke `/yoke:sync-docs`. It rewrites only the byte-range between `<!-- yoke:skills:start -->` markers and the MDX pages, leaving Task 12's hand edits intact.
- **Context:** `skills/sync-docs/SKILL.md`, the sentinel blocks in README/CLAUDE
- **Verify:** `/yoke:sync-docs --check` → no drift

### Task 14: Validation

- **Files:** —
- **Depends on:** all
- **Scope:** S
- **What:** Run the full grep guard, gitignore checks, format check, and JSON/YAML validators.
- **Context:** —
- **Verify:** `grep -rn "docs/ai\|docs/adr\|CONTEXT-MAP\|\bCONTEXT\.md" skills/ lib/ README.md CLAUDE.md | grep -v "skills/do/\|skills/bootstrap/\|\.claude/"` → no in-scope hits; `git check-ignore .yoke/ai` non-zero AND `git check-ignore .yoke/sync-docs-tmp/x .yoke/notify-pending.json` zero; `ls .yoke/adr/` shows 0001–0005 and `docs/adr/` gone; `pnpm run format:check` passes; `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"` → OK; `head -1 skills/*/SKILL.md commands/*.md` → all `---`

## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** Tasks 1–12 touch disjoint file sets so they fan out concurrently; Task 13 (`/sync-docs`) is a barrier consuming the edited descriptions and following the README/CLAUDE prose edits, then Task 14 gates on everything.
- **Order:**
  Group 1 (parallel): Task 1, Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8, Task 9, Task 10, Task 11, Task 12
  ─── barrier ───
  Group 2 (sequential): Task 13 → Task 14

## Verification

- `grep -rn "docs/ai" skills/ lib/ README.md CLAUDE.md` → only matches inside `skills/do/`, `skills/bootstrap/`, and `.claude/commands/` (the deferred slices); no match in any migrated skill, `lib/pr-collect.sh`, README, or CLAUDE.md.
- `grep -rn "docs/adr" skills/ README.md CLAUDE.md` → no matches except inside the moved ADR 0004's historical prose.
- `grep -rn "CONTEXT-MAP\|root CONTEXT.md\|\`CONTEXT.md\`" skills/grill-docs/` → no live glossary references to the root or the map split.
- `ls .yoke/adr/` → shows `0001`–`0005`; `ls docs/adr/` → empty or absent.
- `cat .gitignore` → ignores `.yoke/sync-docs-tmp/` and `.yoke/notify-pending.json` only, not all of `.yoke`.
- Run `/yoke:prd`, `/yoke:plan`, `/yoke:task`, `/yoke:review` on a sample slug → each artifact lands at `.yoke/ai/<slug>/...` and gets committed.
- Run `/yoke:grill-docs` → glossary written to `.yoke/context.md`, ADR to `.yoke/adr/`.
- `bash lib/pr-collect.sh` (or invoke `/pr`) on a slug with `.yoke/ai/<slug>/` artifacts → discovers and collects them.
- `/help` output names `.yoke/` paths, not `docs/ai`/`CONTEXT.md`.
- `pnpm run format:check` → passes; JSON/YAML validators in CLAUDE.md → `OK`.
- `/yoke:sync-docs --check` → no drift after catalog regeneration.

## Materials

- [Issue #18 — S1 .yoke/ artifact convention](https://github.com/yokeloop/yoke/issues/18)
- [Epic #17 — yoke 2.0 Global Refactor](https://github.com/yokeloop/yoke/issues/17)
- `docs/adr/0004-yoke-artifact-root.md` — source-of-truth convention
- `lib/pr-collect.sh` — `/pr` artifact discovery (lines 50–53)
- `lib/notify.sh` — reference for `.yoke/`-relative shell paths
- `skills/grill-docs/reference/{domain-docs,ADR-FORMAT,CONTEXT-FORMAT}.md` — glossary/ADR consumer rules
- `.gitignore` (line 2) — current full `.yoke` ignore to narrow
