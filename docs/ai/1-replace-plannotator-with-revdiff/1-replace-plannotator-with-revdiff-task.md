# Replace plannotator with revdiff for interactive review of yoke artifacts

**Slug:** 1-replace-plannotator-with-revdiff
**Ticket:** https://github.com/yokeloop/yoke/issues/1
**Complexity:** medium
**Type:** general

## Task

Replace every `/plannotator-*` call in yoke skill Complete loops with `/revdiff` — file review for `/task` and `/plan`, ref-diff review for `/do` — and align README and `docs/` accordingly.

## Context

### Area architecture

Each of the three artifact-producing skills ends with a Complete-phase loop that uses AskUserQuestion to pick a follow-up. The existing loop shape:

```
notify.sh STAGE_COMPLETE  →  AskUserQuestion  →  dispatch via Skill tool  →  (apply result)  →  loop
```

- `/task` Phase 6 reviews the task markdown file.
- `/plan` Phase 8 reviews the plan markdown file.
- `/do` Phase 7 currently offers 2 options (`/yoke:review` / finish); the pipeline overview on line 49 already advertises a 3-option shape (`review / plannotator / finish`) that Phase 7 never rendered.

revdiff ships as a separate Claude Code plugin (https://github.com/umputun/revdiff). Install path:

```
/plugin marketplace add umputun/revdiff
/plugin install revdiff@umputun-revdiff
```

The plugin exposes a `/revdiff` slash command that launches revdiff in a terminal overlay (tmux popup, Zellij floating, kitty overlay, wezterm split, cmux split, ghostty/iTerm2 split, Emacs vterm) and returns structured annotations on quit. yoke invokes it through the Skill tool, not bash — identical to the current `/plannotator-annotate` call.

### Files to change

- `skills/task/SKILL.md:263-273` — replace "Review via plannotator" with "Review via revdiff"; invocation becomes the Skill tool with `/revdiff --only <task-file>`.
- `skills/plan/SKILL.md:287-299` — same change for the plan file.
- `skills/do/SKILL.md:49` — update the pipeline overview (`review / revdiff / finish`) to match the new Phase 7 shape.
- `skills/do/SKILL.md:279-289` — expand Phase 7 from 2 options to 3, add "Review via revdiff" with target `<default-base>...HEAD` (resolve base via the cascade `origin/HEAD` → `origin/main` → `origin/master`, same as `skills/gp/agents/git-pre-checker.md:43-54`); fold revdiff annotations into `docs/ai/<SLUG>/<SLUG>-report.md` under a new `## Review notes` section.
- `docs/task.md:25` — replace "review via plannotator" in the Phase 6 row with "review via revdiff".
- `docs/plan.md:17-26` — extend the phases table to cover Phase 7 (Commit artifact) and Phase 8 (Complete with the new revdiff option).
- `docs/do.md:19-28` — extend the pipeline table to cover Phase 7 (Complete with `/yoke:review` / revdiff / finish) alongside the existing Stage 7 (Report) row, or rename Stage 7 to Complete and document both the report step and the Complete loop.
- `README.md:278` — remove the `https://plannotator.ai/` line from References.
- `README.md` — add a new "Interactive review (revdiff)" section covering plugin install, terminal requirements, usage at each integration point, annotation fold-back behavior, and the upstream link. Skip binary-install detail — link upstream.

### Patterns to reuse

- **Complete-loop shape** — keep it identical to the existing `/task` Phase 6 and `/plan` Phase 8 loops: notify.sh STAGE_COMPLETE → AskUserQuestion (3 options, Recommended first) → dispatch → loop. Swap only the middle option's label and handler.
- **Skill-tool dispatch wording** — `skills/task/SKILL.md:271` ("call the Skill tool with `/yoke:plan` and the argument ...") is the canonical phrasing. Mirror it for `/revdiff`.
- **External-dependency missing message** — `skills/gp/SKILL.md:42` (`GH_AUTH = not_installed → "Install gh CLI: https://cli.github.com"`). Adopt the same on-failure pattern: print the two `/plugin` install commands and loop back to the Complete AskUserQuestion.
- **Annotation fold-back** — the existing plannotator wording (`skills/task/SKILL.md:272`: "Apply the returned annotations, overwrite the file. Loop back to the start.") carries over verbatim for the markdown file cases. For `/do`, append annotations to the report file instead of applying them to source code.
- **`/do` report append pattern** — Phase 6b already writes `docs/ai/<SLUG>/<SLUG>-report.md`. Appending a `## Review notes` section follows the same artifact-append convention as `/fix`'s `fix-log-writer` (`skills/fix/agents/fix-log-writer.md`), which appends to an existing log.

### Tests

The repo contains no automated tests (markdown-only plugin). Verify manually: run each skill end-to-end, pick the revdiff option, confirm annotations fold back correctly. The ticket's AC includes a `/yoke:task <desc> → pick revdiff → annotate → annotations folded back` smoke test.

## Requirements

1. Replace "Review via plannotator" with "Review via revdiff" in `skills/task/SKILL.md` Phase 6 Complete loop; invocation = Skill tool with `/revdiff --only docs/ai/<task-slug>/<task-slug>-task.md`; apply returned annotations to the task file, overwrite, loop back.
2. Replace "Review via plannotator" with "Review via revdiff" in `skills/plan/SKILL.md` Phase 8 Complete loop; invocation = Skill tool with `/revdiff --only docs/ai/<TASK_SLUG>/<TASK_SLUG>-plan.md`; apply returned annotations to the plan file, overwrite, loop back.
3. Expand `skills/do/SKILL.md` Phase 7 from 2 options to 3: add "Review via revdiff" between `/yoke:review` and Finish; invocation = Skill tool with `/revdiff <default-base>...HEAD` where `<default-base>` resolves via the `git-pre-checker` default-branch cascade (`git symbolic-ref refs/remotes/origin/HEAD` → `origin/main` → `origin/master` → fallback `main`); append returned annotations to `docs/ai/<SLUG>/<SLUG>-report.md` under a new `## Review notes` section, commit the update with `TICKET docs(SLUG): append review notes`; loop back.
4. Update `skills/do/SKILL.md:49` pipeline-overview comment to read `7. Complete → review / revdiff / finish` (matches actual Phase 7 options).
5. On missing revdiff plugin (Skill-tool invocation fails): print `Install the revdiff plugin:\n  /plugin marketplace add umputun/revdiff\n  /plugin install revdiff@umputun-revdiff`, then loop back to the same Complete-phase AskUserQuestion. Applies identically to `/task`, `/plan`, and `/do`.
6. Remove every `/plannotator-annotate` and `/plannotator-review` reference from `skills/**/SKILL.md`. No fallback option, no legacy entry. Confirm via `grep -r plannotator skills/`.
7. Update `docs/task.md:25` Phase 6 row to read `Completion loop: run /yoke:plan (recommended) / review via revdiff / finish`.
8. Extend `docs/plan.md` phases table with Phase 7 (Commit artifact — `TICKET docs(SLUG): add implementation plan`) and Phase 8 (Complete — `run /yoke:do (recommended) / review via revdiff / finish`).
9. Extend `docs/do.md` pipeline table to document Phase 7 Complete (`/yoke:review (recommended) / revdiff / finish`) alongside the existing Report stage — either as a separate row or by renaming Stage 7 to Complete and folding both the report step and the Complete loop into its description.
10. Remove `https://plannotator.ai/` from `README.md:278` References.
11. Add a new `## Interactive review (revdiff)` section to `README.md` covering:
    - One-sentence description of revdiff's role in yoke.
    - Plugin install: `/plugin marketplace add umputun/revdiff` + `/plugin install revdiff@umputun-revdiff`.
    - Terminal requirements: tmux, Zellij, kitty, wezterm, Kaku, cmux, ghostty (macOS), iTerm2 (macOS), Emacs vterm — "one of these is required; the plugin exits with an error otherwise".
    - Usage per yoke integration point:
      - Task file review — `/revdiff --only docs/ai/<slug>/<slug>-task.md` invoked from `/yoke:task` Phase 6.
      - Plan file review — `/revdiff --only docs/ai/<slug>/<slug>-plan.md` invoked from `/yoke:plan` Phase 8.
      - `/do` code review — `/revdiff <default-base>...HEAD` invoked from `/yoke:do` Phase 7.
    - Annotation fold-back behavior: markdown artifacts get annotations applied in place (file overwritten); `/do` code review annotations append to the report file.
    - Upstream link: https://github.com/umputun/revdiff (MIT).

## Constraints

- Do not invoke revdiff via bash (`bash revdiff ...`) — the chosen integration is the Claude Code plugin, dispatched via the Skill tool. We considered and rejected bash invocation because Claude Code's Bash tool has no PTY.
- Do not install revdiff as a yoke dependency or bundle it in `.claude-plugin/plugin.json` — the user installs the revdiff plugin separately via `/plugin install`. yoke only references `/revdiff`.
- Do not add brew / deb / rpm / AUR / raw-binary install paths to `README.md` — the chosen install path is plugin-only; binary details stay upstream at https://github.com/umputun/revdiff.
- Do not keep any plannotator fallback. Hard-remove every `/plannotator-annotate` and `/plannotator-review` reference. Users who still want plannotator can invoke it manually — nothing in this repo depends on it.
- Do not alter the Complete-loop structure (notify.sh → AskUserQuestion → dispatch → loop) — swap only the middle option. This keeps the flow identical in shape across `/task`, `/plan`, and `/do`.
- Do not touch `CLAUDE.md` — it mentions no plannotator.
- Do not touch skills other than `task`, `plan`, `do`. `/fix`, `/review`, and `/explore` emit no interactive-review artifacts in the ticket scope and stay out of scope.
- Do not remove the existing `/yoke:review` option from `/do` Phase 7 — revdiff complements it (human-eyed annotations), not replaces it.
- Do not break the existing Phase 5 commit convention (`TICKET docs(SLUG): ...`) — the new "append review notes" commit must follow the same convention from `skills/gca/reference/commit-convention.md`.

## Verification

- `grep -rn plannotator skills/ docs/ README.md CLAUDE.md` returns zero matches after the change.
- `grep -rn "/revdiff" skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` returns at least one match per file, in the Complete phase.
- `head -1 skills/task/SKILL.md skills/plan/SKILL.md skills/do/SKILL.md` still prints `---` (YAML frontmatter intact).
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"` prints `OK`.
- Manual smoke: `/yoke:task <short description>` → at Phase 6 Complete pick "Review via revdiff" → revdiff opens in the current terminal's overlay → add an annotation → quit with `q` → the annotation folds into the task file → AskUserQuestion re-appears. Equivalent smoke for `/yoke:plan` on a plan file, and for `/yoke:do` on a plan that produces ≥1 commit.
- Negative case: uninstall the revdiff plugin, pick "Review via revdiff" → the orchestrator prints the two `/plugin` install commands and the Complete AskUserQuestion re-appears without crashing.
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
- `skills/do/SKILL.md:49, 279-289` — current `/do` pipeline overview and Phase 7
- `skills/gp/SKILL.md:42` — reference pattern for the missing-CLI install hint
- `skills/gp/agents/git-pre-checker.md:43-54` — default-branch cascade for `<base>` resolution
- `skills/gca/reference/commit-convention.md` — commit format for docs(SLUG) updates
- `docs/task.md:25`, `docs/plan.md:17-26`, `docs/do.md:19-28` — docs to extend
- `README.md:278` — plannotator References line to remove
