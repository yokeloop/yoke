# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**yoke** — a marketplace of skills and commands for Claude Code, inspired by [obra/superpowers](https://github.com/obra/superpowers). Forked from [projectory-com/sp](https://github.com/projectory-com/sp). Distributed as a Claude Code plugin via `.claude-plugin/marketplace.json`.

## Architecture

```
.claude/
  skills/              # local skills for plugin development (yoke-create, yoke-release, yoke-validate)
.claude-plugin/
  plugin.json          # plugin manifest (name, version, author)
  marketplace.json     # marketplace registry (name, owner, plugins[])
skills/                # skills — auto-discovered by SKILL.md in subdirectories
lib/                   # shared scripts called from skills (notify.sh, gp-precheck.sh, gp-push.sh, pr-collect.sh)
docs/                  # reference documentation for the plugin system
```

Components (`skills/`) live at the repository root, NOT inside `.claude-plugin/`.

## Plugin System

- **Skills** (`skills/<name>/SKILL.md`): model-invoked, activated automatically by `description` in YAML frontmatter
- **Agents** (`skills/<name>/agents/<agent>.md`): model-invoked sub-agents dispatched by skill orchestrators via the Agent tool; YAML frontmatter with `name` and `description`
- **Namespace**: all components are available as `/yoke:<name>` after installation
- **`$ARGUMENTS`**: placeholder for user-supplied arguments in skills and commands
- **`${CLAUDE_PLUGIN_ROOT}`**: for paths inside the plugin (e.g. `${CLAUDE_PLUGIN_ROOT}/lib/notify.sh`) in skills and MCP configs

## Validation

```bash
# Validate JSON manifests
python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"

# Validate YAML frontmatter in skills — first line must be ---
head -1 skills/*/SKILL.md
```

## Testing locally

```bash
claude --plugin-dir .
```

## Conventions

- **Content language**: English by default. Skills adapt to the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
- **Files and directories**: kebab-case
- **Versioning**: semver in `plugin.json` (source of truth for the version)
- **marketplace.json**: required top-level fields — `name`, `owner` (object with `name`), `plugins[]`
- **Plugin source**: `"./"` for self-contained (plugin at the marketplace root), `{ "source": "github", "repo": "owner/repo" }` for external
- **SKILL.md frontmatter**: `name` (identifier), `description` (when to activate)

### Artifact root (`.yoke/`)

Skills write their artifacts under `.yoke/` in the target project:

- `.yoke/context.md` — domain glossary
- `.yoke/adr/` — architecture decision records
- `.yoke/ai/<slug>/` — per-task pipeline artifacts (PRD, task, plan, report, exploration, issues index)
- `.yoke/journal.md` — session journal

`.yoke/` is committed to git by default. Only `.yoke/sync-docs-tmp/` is gitignored. Skills always write under `.yoke/` and commit unless `.yoke/` is ignored.

## Implemented skills

`/do` is the universal execution tool: no args → inline execution; an issue URL → sub-agents (plan then pause for confirmation); a PRD with sub-issues → team of parallel agents. `/task` and `/plan` are deprecated and have moved to `deprecated/`.

<!-- yoke:skills:start -->

- `/bootstrap` — Prepares a project for the yoke flow — stack detection, scaffolding the `.yoke/` layout, and generation of CLAUDE.md and yoke-context.md.
- `/do` — Executes a task per plan.
- `/gca` — Git staging and commit with smart file grouping.
- `/gp` — Git push with checks and report.
- `/grill` — Interviews the user one interactive question at a time about a plan or design, walking each branch of the decision tree to a shared understanding; every question offers a recommended answer.
- `/grill-docs` — Docs-aware grilling: interrogates the user's plan one question at a time AND maintains the domain glossary (.yoke/context.md) and architecture decision records (.yoke/adr/) inline as decisions crystallise.
- `/handoff` — Compacts the current conversation into a handoff document so a fresh agent can continue the work, referencing existing artifacts instead of duplicating them.
- `/help` — Explains how to use yoke and lists the available skills; also greets new users.
- `/issues` — Breaks a plan, spec, or PRD into independently-grabbable GitHub issues using vertical slices (tracer bullets), publishes them in dependency order, and saves a local index in .yoke/ai.
- `/journal` — Appends a concise, newest-first entry to `.yoke/journal.md` summarizing the session's real work and linking the relevant `.yoke/ai/<slug>/` artifacts — the first layer of yoke's connected memory.
- `/pr` — Creates or updates a GitHub Pull Request.
- `/prd` — Turns the current conversation and codebase understanding into a PRD, publishes it as a GitHub issue, and saves a local copy in .yoke/ai.
- `/review` — Finds problems in code, fixes them and produces a report.

<!-- yoke:skills:end -->

## Local skills (development)

- `/yoke-create` — skill factory: analysis, design, implementation, validation, integration
- `/yoke-release` — plugin release: quality checks, version bump, tag, push, GitHub release
- `/yoke-validate` — runs every `SKILL.md` changed in the current branch through elements-of-style (Strunk) and plugin-dev's skill-development conventions, auto-fixes safe findings, and reports the rest. Depends on the `elements-of-style` and `plugin-dev` plugins.
- `/sync-docs` — regenerates the shipped skill catalog (per-skill MDX, README + CLAUDE.md sentinel blocks); repo-internal, not shipped to the marketplace.

## Planned skills

`/polish` `/qa` `/memorize` `/merge`

## Reference docs

- `docs/notify.md` — Telegram notifications: setup, types, map of trigger points
- `skills/issues/reference/github-issues.md` — GitHub issue tracker conventions, triage labels, issue types + sub-issues (used by `/prd`, `/issues`)
- `skills/grill-docs/reference/domain-docs.md` — domain-doc consumer rules for `.yoke/context.md`/ADRs (used by `/prd`, `/issues`)

## Formatting

```bash
pnpm run format          # format all *.{md,json}
pnpm run format:check    # check formatting (CI-ready)
```

Config: `.prettierrc.json` (proseWrap: preserve, printWidth: 120).
A pre-commit hook via Husky formats staged files automatically.
