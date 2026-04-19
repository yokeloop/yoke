# Code Review: 1-replace-plannotator-with-revdiff

## Summary

### Context and goal

Swap the external `/plannotator-annotate` integration for the `/revdiff` Claude Code plugin across `/task`, `/plan`, and `/do`. Expand `/do` Phase 7 from 2 options to 3, align README and `docs/*` with the new flow, and hard-remove every `plannotator` reference from the plugin surface.

### Key code areas for review

1. **`skills/task/SKILL.md:266, 272`** — Phase 6 Complete loop swap + install-hint fallback.
2. **`skills/plan/SKILL.md:292, 298`** — Phase 8 Complete loop swap + install-hint fallback.
3. **`skills/do/SKILL.md:49, 82`** — pipeline overview label + TodoWrite template label.
4. **`skills/do/SKILL.md:279-291`** — Phase 7 expanded to 3 options with append-review-notes flow, gitignore-aware auto-commit, and AskUserQuestion re-presentation on loop.
5. **`docs/task.md:25`** — Phase 6 row cell update.
6. **`docs/plan.md:17, 27-28`** — intro rewording ("8 sequential phases") + 2 new rows.
7. **`docs/do.md:18, 28`** — Pipeline intro carve-out for Stage 7 confirmation + Stage 7 rename to Complete.
8. **`README.md:274-323`** — new `## Interactive review (revdiff)` section with install, terminals, usage, fold-back behavior, upstream link.

### Complex decisions

1. **Try-and-catch missing-plugin handling** (`skills/{task,plan,do}/SKILL.md` Complete loops)
   Invoke `/revdiff` via the Skill tool; on failure print the install hint and re-present the options. Trade-off: no pre-check, so the user sees the hint only after picking the option. Mirrors `skills/gp/SKILL.md:42`'s "print hint, exit" pattern.

2. **3-option `/do` Phase 7** (`skills/do/SKILL.md:279-291`)
   Closes the gap between the pipeline overview (line 49) and the Phase 7 body. revdiff complements `/yoke:review` (interactive annotation vs automated analysis), not replaces it.

3. **Default-base cascade for `/do` revdiff target** (`skills/do/SKILL.md:290`)
   Reuses the `skills/gp/agents/git-pre-checker.md:43-54` cascade instead of hard-coding `origin/main`.

4. **`## Review notes` heading semantics** (`skills/do/SKILL.md:290`)
   Explicit append-under-existing-heading behavior on repeat invocations; avoids duplicate headings.

### Questions for the reviewer

1. revdiff's terminal-requirement check (tmux/Zellij/kitty/etc.) is delegated entirely to revdiff's startup error. Should yoke surface the requirement anywhere besides README?
2. No version pin on the external revdiff plugin. Does yoke need a minimum-version check?
3. `/do` Phase 7 install-hint fallback path does not currently notify Telegram. Every other Complete-phase path does. Intentional?

### Risks and impact

- No code paths broken — markdown-only edits to skill instructions.
- External dependency surface area grows: yoke references the `umputun/revdiff` plugin. The install-hint fallback shields against missing-plugin crashes; there's no version pin.
- Phase 7 auto-commit runs inside a loop; gitignore check mirrors Phase 6c, so ignored-`docs/ai/` repos remain safe.

### Tests and manual checks

**Auto-tests:** none (markdown-only plugin, no tests in the repo).

**Manual scenarios:**

1. `/yoke:task <desc>` → Phase 6 pick "Review via revdiff" → revdiff opens → annotate → quit → annotations fold back and AskUserQuestion re-appears.
2. `/yoke:plan <task-path>` → Phase 8 pick "Review via revdiff" → same outcome for the plan file.
3. `/yoke:do <plan-path>` → Phase 7 pick "Review via revdiff" → annotations append under `## Review notes` (existing or new heading) in the report file → auto-commit `#1 docs(1-replace-plannotator-with-revdiff): append review notes` → 3 options re-present.
4. Negative: uninstall the revdiff plugin → pick "Review via revdiff" → install hint prints → 3 options re-present without crashing.
5. Gitignore negative: add `docs/ai/` to `.gitignore` locally → Phase 7 revdiff path → skips the auto-commit, updates the file only.

### Out of scope

- `docs/plan.md` Phase 5 "Checkpoint" vs "Review" label drift — predates this task.
- Skills outside `/task`, `/plan`, `/do` — `/fix`, `/review`, `/explore`, `/gca`, `/gp`, `/pr`, `/gst`, `/hi`, `/bootstrap` do not emit interactive-review artifacts in this scope.
- Binary-install paths (`brew`, `deb`, `rpm`, `AUR`) — plugin-only install per product decision; README links upstream.
- `CLAUDE.md` — no plannotator reference exists, so no edit needed.

## Commits

| Hash      | Description                                                                           |
| --------- | ------------------------------------------------------------------------------------- |
| `eca97fe` | `#1 docs(1-replace-plannotator-with-revdiff): add task definition`                    |
| `7e5416e` | `#1 docs(1-replace-plannotator-with-revdiff): add implementation plan`                |
| `4341fea` | `#1 feat(1-replace-plannotator-with-revdiff): swap plannotator for revdiff in Complete loops` |
| `996b71d` | `#1 docs(1-replace-plannotator-with-revdiff): document revdiff integration`           |
| `e25e123` | `#1 docs(1-replace-plannotator-with-revdiff): update phase tables for revdiff`        |
| `b5a4dd4` | `#1 style(1-replace-plannotator-with-revdiff): apply prettier to docs/do.md`          |
| `bef82f3` | `#1 docs(1-replace-plannotator-with-revdiff): add execution report`                   |
| `1e18e1b` | `#1 fix(1-replace-plannotator-with-revdiff): apply code-review fixes`                 |

## Changed Files

| File                                                              | +/-      | Description                                                     |
| ----------------------------------------------------------------- | -------- | --------------------------------------------------------------- |
| `README.md`                                                       | +48/-4   | Removed plannotator link; added Interactive review section      |
| `docs/ai/1-replace-plannotator-with-revdiff/*-task.md`            | +120/-0  | Task definition artifact                                        |
| `docs/ai/1-replace-plannotator-with-revdiff/*-plan.md`            | +202/-0  | Implementation plan artifact                                    |
| `docs/ai/1-replace-plannotator-with-revdiff/*-report.md`          | +64/-0   | Execution report artifact                                       |
| `docs/do.md`                                                      | +11/-11  | Stage 7 renamed to Complete; pipeline intro carve-out           |
| `docs/plan.md`                                                    | +3/-1    | Phase 7/8 rows added; intro rewording                           |
| `docs/task.md`                                                    | +1/-1    | Phase 6 row swap                                                |
| `skills/do/SKILL.md`                                              | +5/-5    | Pipeline overview + TodoWrite + Phase 7 revdiff option          |
| `skills/plan/SKILL.md`                                            | +2/-2    | Phase 8 Complete loop swap                                      |
| `skills/task/SKILL.md`                                            | +2/-2    | Phase 6 Complete loop swap                                      |

## Issues Found

| Severity  | Score | Category      | File:line                          | Description                                                                              |
| --------- | ----- | ------------- | ---------------------------------- | ---------------------------------------------------------------------------------------- |
| Important | 50    | bugs          | `skills/do/SKILL.md:290`           | Repeat revdiff invocations would append a duplicate `## Review notes` heading            |
| Minor     | 45    | documentation | `docs/do.md:18`                    | "No confirmations between steps" contradicts new Stage 7 Complete loop                   |
| Minor     | 35    | bugs          | `skills/do/SKILL.md:281, 290`      | "Loop back" wording ambiguous — re-present options vs re-run Phase 7 including report print |
| Minor     | 30    | bugs          | `skills/do/SKILL.md:290`           | Phase 7 auto-commit missing the Phase 6c `docs/ai/` gitignore check                      |
| Minor     | 25    | documentation | `README.md:313-317`                | README did not explain the `<base>` resolution cascade                                   |
| Minor     | 20    | documentation | `skills/do/SKILL.md:290`           | Reference `skills/gp/agents/git-pre-checker.md:40-54` — cascade actually starts at line 43 |

## Fixed Issues

| Issue                                                       | Commit    | Description                                                                                        |
| ----------------------------------------------------------- | --------- | -------------------------------------------------------------------------------------------------- |
| Duplicate `## Review notes` heading on repeat invocation    | `1e18e1b` | Skill instruction now appends under existing heading if present, otherwise creates it              |
| `docs/do.md:18` "No confirmations between steps" drift      | `1e18e1b` | Reworded to "Stages 1–6 run without confirmations; Stage 7 has a Complete loop with an AskUserQuestion" |
| Ambiguous "Loop back" wording                               | `1e18e1b` | Changed to "Re-present the 3 options via AskUserQuestion (skip the report-path re-print)"          |
| Missing gitignore check on Phase 7 auto-commit              | `1e18e1b` | Added "Check `.gitignore` for `docs/ai/` (same as Phase 6c) — if ignored, skip the auto-commit"    |
| README missing `<base>` cascade explanation                 | `1e18e1b` | Added `<base>` resolution note to the `/do` bullet                                                 |
| Line-reference drift `40-54` → `43-54`                      | `1e18e1b` | Updated the reference in `skills/do/SKILL.md:290`                                                  |

## Skipped Issues

**All found issues were fixed.**

## Recommendations

- Before merging, run the 4 manual smoke scenarios listed above — especially the negative "plugin missing" case, since install-hint behavior was never exercised end to end.
- Consider a follow-up ticket for `/do` Phase 7 install-hint path notification (question 3 in Summary) — currently the fallback path does not notify Telegram while every other Complete-phase path does.
- Consider a follow-up ticket to pin the revdiff plugin version or add a minimum-version check (question 2 in Summary).
