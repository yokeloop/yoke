# Update documentation

**Slug:** 8-update-documentation
**Ticket:** https://github.com/yokeloop/yoke/issues/8
**Complexity:** simple
**Type:** general

## Task

Restructure `README.md`, replace `yoke.png` with a mermaid pipeline diagram, and rename the `/hi` skill to `/help` so the entry-point doc reads as a how-to-use guide.

## Context

### Area architecture

This task touches documentation in three places:

- `README.md` (334 lines) — public marketplace landing page
- `skills/hi/SKILL.md` (138 lines) — static welcome skill, no agents, plain markdown body
- `docs/hi.md` — short companion reference for the skill

Yoke auto-discovers skills by directory name (`skills/<name>/SKILL.md`) and exposes them under the `/yoke:<name>` namespace. Renaming a skill means renaming the directory and every cross-reference. No central registry exists — `plugin.json` and `marketplace.json` do not list individual skills.

GitHub renders mermaid blocks in `README.md` natively (since Feb 2022), so the PNG can move inline.

### Files to change

- `README.md:3` — replace `![yoke …](yoke.png)` with a mermaid `flowchart LR` block
- `README.md:243-252` — move the `## Installation` section directly after the diagram and inspirations (currently buried at line 243)
- `README.md` — insert a new `## How to use` section immediately after `## Installation`
- `README.md:166-178` — keep the existing `## Full cycle` section in place (lower in the document); do not merge with How to use
- `README.md:325-329` — delete the `## References` section (the bare `superpowers-lab` line is the "strange rev"); the inspirations list at lines 5-9 already credits `obra/superpowers`
- `README.md:126-132,192` — update mentions of `/hi` to `/help`
- `skills/hi/` → rename directory to `skills/help/`
- `skills/help/SKILL.md` — change `name: hi` to `name: help`, update the description's trigger phrases, keep the static body content (skill catalog, full cycle, planned, install)
- `docs/hi.md` → rename to `docs/help.md`, update title and prose
- `CLAUDE.md:71` — change `/hi` to `/help` in the "Implemented skills" list
- `.claude/skills/yoke-create/SKILL.md:367` — update the `### /hi` reference
- `yoke.png` — delete the 1.1 MB binary from the repo

### Patterns to reuse

- The existing `/hi` SKILL.md body seeds `/help` — keep its skill catalog, "Full cycle" snippet, planned-skills table, and install command.
- Skill frontmatter pattern (kebab-case `name`, `description` listing trigger phrases) — see `skills/gst/SKILL.md:1-8` and `skills/explore/SKILL.md`.
- The pipeline content for the mermaid diagram already exists as text at `README.md:166-178` (`## Full cycle`) — translate it into mermaid edges.

### Tests

No automated doc tests. Validate per `CLAUDE.md`:

- `pnpm run format:check` — Prettier on `*.{md,json}` (`.prettierrc.json`: `proseWrap: preserve`, `printWidth: 120`)
- `head -1 skills/*/SKILL.md` — every file starts with `---`
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json'))"` — manifests parse
- Husky pre-commit auto-formats staged Markdown.

## Requirements

1. Replace `README.md:3` (`![yoke …](yoke.png)`) with a `mermaid` `flowchart LR` block. The diagram shows the main pipeline `task → plan → do → review → gca → gp → pr` with a `fix` side-branch looping back to `do`, plus a separate cluster of utility skills (`gst`, `explore`, `bootstrap`, `help`). Source the flow from the existing `## Full cycle` snippet at lines 166-178.
2. Move `## Installation` (currently `README.md:243-252`) directly after the inspirations list (before `## Skills`).
3. Add a new `## How to use` section directly after `## Installation`. Content: a short quick-start showing `/yoke:help`, `/yoke:bootstrap`, and one full-cycle command — followed by a one-line pointer "See `## Full cycle` below for the complete pipeline." Keep `## Full cycle` (lines 166-178) where it is.
4. Delete the `## References` section (lines 325-329) entirely.
5. Rename the `/hi` skill to `/help`:
   - Move `skills/hi/` to `skills/help/`.
   - In `skills/help/SKILL.md`: change `name: hi` to `name: help`; update the `description` so trigger phrases lead with help/usage intent (`"help"`, `"how do I use yoke"`, `"how to use"`, `"what skills are available"`), keep `"hi"`/`"hello"` as secondary triggers.
   - Keep the static body — no agent.
   - Move `docs/hi.md` to `docs/help.md`; update title and prose to match `/help`.
6. Update every cross-reference to `/hi`:
   - `README.md` skill list (lines 126-132) and the `Structure` tree (line 192)
   - `CLAUDE.md` line 71 (`Implemented skills` list)
   - `.claude/skills/yoke-create/SKILL.md:367`
7. Delete `yoke.png` from the repo root.

## Constraints

- Leave `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` untouched — neither lists individual skills.
- Do not touch any other skill (`skills/task/`, `skills/plan/`, `skills/do/`, etc.) or its `SKILL.md` body.
- Do not change historical artifacts under `docs/ai/*` or `docs/pi-yoke-repo-plan.md`/`docs/skill-optimization-plan.md` — leave existing `/hi` mentions in those files as a historical record.
- Do not merge `## Full cycle` (`README.md:166-178`) into `## How to use` — the user chose to keep both.
- Do not condense or remove `## Interactive review (revdiff)` (lines 274-323) — only `## References` goes.
- Do not add new dependencies, scripts, or hooks.
- Keep Prettier formatting (`proseWrap: preserve`, `printWidth: 120`); do not reflow paragraphs by hand.

## Verification

- `pnpm run format:check` — passes on every changed file.
- `head -1 skills/help/SKILL.md` — prints `---`.
- `ls skills/hi 2>/dev/null` — empty (directory removed); `ls skills/help/SKILL.md` — exists.
- `ls docs/hi.md 2>/dev/null` — empty; `ls docs/help.md` — exists.
- `ls yoke.png 2>/dev/null` — empty (file removed).
- `grep -rn "/hi" README.md CLAUDE.md skills/ .claude/skills/` — no matches outside historical `docs/ai/*` and `docs/pi-*.md` / `docs/skill-optimization-plan.md`.
- `grep -n "yoke.png" README.md` — no matches.
- `grep -n "superpowers-lab" README.md` — no matches.
- Open `README.md` on GitHub: the mermaid block renders as a flowchart; `## Installation` precedes `## How to use`; `## Skills` follows; `## References` is gone.
- `claude --plugin-dir .` followed by `/yoke:help` — prints the welcome content.
- `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json'))"` — exits 0.

## Materials

- [GitHub Issue #8](https://github.com/yokeloop/yoke/issues/8)
- `README.md` — primary edit target
- `skills/hi/SKILL.md` — source content for the new `/help`
- `docs/hi.md` — companion doc to rename
- `yoke.png` — file to delete
- `CLAUDE.md` — references `/hi` at line 71
- `.claude/skills/yoke-create/SKILL.md` — references `/hi` at line 367
- `skills/gst/SKILL.md` — frontmatter pattern reference
- `.prettierrc.json` — formatter config
