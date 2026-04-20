# yoke

![yoke — command and workflow overview](yoke.png)

A marketplace of skills and commands for Claude Code, inspired by:

- [obra/superpowers](https://github.com/obra/superpowers).
- [obra/the-elements-of-style](https://github.com/obra/the-elements-of-style)
- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official)

## Skills

### /task — task definition

Accepts a ticket URL or free-form description. Explores the codebase, analyzes architecture, and produces a prompt-task with context, requirements, constraints, and clarifying questions. [Details →](docs/task.md)

```
/yoke:task https://github.com/owner/repo/issues/86
/yoke:task add dark theme to settings
```

**Output:** `docs/ai/<slug>/<slug>-task.md`

### /plan — implementation planning

Reads the task file, explores the codebase, makes design decisions, decomposes the work into atomic tasks with dependencies, picks the execution order (sequential/parallel), and reviews the plan. [Details →](docs/plan.md)

```
/yoke:plan docs/ai/86-black-jack-page/86-black-jack-page-task.md
```

**Output:** `docs/ai/<slug>/<slug>-plan.md`

### /do — plan execution

Dispatches sub-agents for each task. After each one, runs a two-stage review (spec compliance → code quality). Polishes the code, validates (lint, types, tests, build), updates documentation, and writes a report. [Details →](docs/do.md)

```
/yoke:do docs/ai/86-black-jack-page/86-black-jack-page-plan.md
```

**Output:** implemented code + `docs/ai/<slug>/<slug>-report.md`

### /review — code review report

Analyzes all changes against origin/main. Produces a report: key areas, complex decisions, risks, questions for the reviewer, manual verification scenarios. [Details →](docs/review.md)

```
/yoke:review 86-black-jack-page
```

**Output:** `docs/ai/<slug>/<slug>-review.md`

### /gca — git commit with smart grouping

Analyzes changed files, classifies them into groups (feature, test, docs, style, chore), and produces atomic commits following Conventional Commits in English. Resolves the ticket ID from arguments, branch name, or yoke flow. [Details →](docs/gca.md)

```
/yoke:gca
/yoke:gca #86
/yoke:gca https://github.com/owner/repo/issues/86
```

### /gp — git push with checks and report

Inspects the repository state (branch, upstream, uncommitted changes, gh auth), pushes to remote, and prints a report: pushed commits, diff stat, branch link, PR status. [Details →](docs/gp.md)

```
/yoke:gp
/yoke:gp --force-with-lease
```

### /pr — create and update Pull Request

Creates or updates a GitHub PR. Builds the description from yoke flow artifacts (review + report): key areas, design decisions, questions for the reviewer, risks, test plan. Without artifacts, falls back to commits and diff. Supports PR templates and auto-labels. [Details →](docs/pr.md)

```
/yoke:pr
/yoke:pr --draft
/yoke:pr --base develop
```

### /fix — quick fix

Compressed pipeline for small changes (1–3 files). Explores the codebase, implements the fix (opus), polishes, validates, and appends an entry to the fix log. Two modes: post-flow (after task/plan/do) and standalone. Supports chains of fixes and "fix from PR comment URL". [Details →](docs/fix.md)

```
/yoke:fix fix email validation — it doesn't handle empty strings
/yoke:fix bump reconnect timeout from 5s to 15s
/yoke:fix https://github.com/owner/repo/pull/42#discussion_r123456
```

**Output:** code + `docs/ai/<slug>/<slug>-fixes.md`

### /gst — repository status

Shows development status: branch, changes, commits relative to main, hot files, semantic summary. [Details →](docs/gst.md)

```
/yoke:gst
```

### /explore — codebase exploration

Interactive Q&A over the codebase and brainstorming. Delegates research to a sub-agent, accumulates findings in a summary chain, and saves an exploration log. [Details →](docs/explore.md)

```
/yoke:explore how does authorization work
/yoke:explore compare caching approaches
/yoke:explore what if we replaced REST with gRPC
```

**Output:** `docs/ai/<slug>/<slug>-exploration.md`

### /bootstrap — prepare project for yoke flow

Detects the project stack, analyzes architecture, scans conventions, and generates CLAUDE.md and `.claude/yoke-context.md`. Entry point for wiring yoke into a new project. [Details →](docs/bootstrap.md)

```
/yoke:bootstrap
/yoke:bootstrap configure yoke for this project
```

**Output:** `CLAUDE.md` + `.claude/yoke-context.md`

### /hi — skills overview

Welcome skill — explains available skills and the recommended workflow. Entry point for new users. [Details →](docs/hi.md)

```
/yoke:hi
```

## Local skills (development)

Skills under `.claude/skills/` are tools for developing the yoke plugin itself. They are available when working in the repository but are not part of the published plugin.

### /yoke-create — skill factory

Full pipeline for creating a new skill: task analysis, design with a mermaid diagram, SKILL.md and agent implementation, quality validation (elements-of-style + skill-development), documentation integration. [Details →](docs/yoke-create.md)

```
/yoke-create a skill for automated code review with bug hunting
/yoke-create https://github.com/yokeloop/yoke/issues/44
```

**Output:** `skills/<name>/SKILL.md` + agents + docs + updated README and CLAUDE.md

### /yoke-release — plugin release

Quality checks (prose, structure, documentation, links), version bump, tag, push, GitHub release with changelog.

```
/yoke-release minor
/yoke-release 2.0.0
```

**Output:** new tag + GitHub release

## Telegram notifications

When working on multiple projects in parallel (tmux + worktree), skills send contextual notifications to Telegram: when questions need an answer, when a task is complete, when something is blocked. [Details →](docs/notify.md)

11 notification points across 5 skills: `/task`, `/plan`, `/do`, `/fix`, `/pr`. Three types: ACTION_REQUIRED, STAGE_COMPLETE, ALERT. Opt-in via env vars `CC_TELEGRAM_BOT_TOKEN` and `CC_TELEGRAM_CHAT_ID`.

## Full cycle

```
/yoke:task <ticket or description>   # define the task
  → answer questions in the file
/yoke:plan <path to task file>       # build the plan
  → answer questions in the file
/yoke:do <path to plan file>         # execute the plan
/yoke:fix <description>              # quick fix after /do
/yoke:review <slug>                  # prepare the review
/yoke:gp                             # push to remote
/yoke:pr                             # create a pull request
```

## Structure

```
yoke/
├── .claude/
│   └── skills/              # local skills (plugin development)
│       ├── yoke-create/     # skill factory
│       └── yoke-release/    # plugin release
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # marketplace registry
├── skills/
│   ├── hi/                  # welcome and skills overview
│   ├── bootstrap/           # prepare project for yoke flow
│   │   ├── SKILL.md
│   │   ├── agents/          # stack-detector, architecture-mapper, convention-scanner, etc.
│   │   └── reference/
│   ├── task/                # task definition
│   │   ├── SKILL.md
│   │   ├── agents/          # task-explorer, task-architect
│   │   ├── reference/       # synthesize-guide, frontend-guide, elements-of-style
│   │   └── examples/
│   ├── plan/                # planning
│   │   ├── SKILL.md
│   │   ├── agents/          # plan-explorer, plan-designer, plan-reviewer
│   │   ├── reference/       # routing-rules, plan-format, elements-of-style
│   │   └── examples/
│   ├── do/                  # plan execution
│   │   ├── SKILL.md
│   │   ├── agents/          # task-executor, spec-reviewer, quality-reviewer, code-polisher, doc-updater
│   │   └── reference/       # status-protocol, report-format
│   ├── review/              # code review preparation
│   │   ├── SKILL.md
│   │   └── agents/          # review-analyzer
│   ├── gca/                 # git commit with smart grouping
│   │   ├── SKILL.md
│   │   └── reference/       # commit-convention, staging-strategy
│   ├── gp/                  # git push with checks
│   │   ├── SKILL.md
│   │   └── agents/          # git-pre-checker, git-pusher
│   ├── pr/                  # create and update PR
│   │   ├── SKILL.md
│   │   ├── agents/          # pr-data-collector, pr-body-generator
│   │   └── reference/       # pr-body-format
│   ├── fix/                 # quick fix (1–3 files)
│   │   ├── SKILL.md
│   │   ├── agents/          # fix-context-collector, fix-investigator, fix-log-writer
│   │   └── reference/       # fix-log-format
│   ├── explore/             # codebase exploration and brainstorming
│   │   ├── SKILL.md
│   │   └── agents/          # explore-agent, explore-log-writer
│   └── gst/                 # repository status
│       ├── SKILL.md
│       └── agents/          # git-data-collector
├── hooks/
│   ├── hooks.json           # Stop hook registration (Telegram notifications)
│   └── notify.sh            # delivery script: reads the queue → sends to Telegram
├── lib/
│   └── notify.sh            # write library: skills call it to enqueue messages
├── commands/
└── docs/                    # per-skill documentation
```

## Installation

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/yokeloop/yoke/main/install.sh | bash
```

### Windows

```powershell
irm https://raw.githubusercontent.com/yokeloop/yoke/main/install.ps1 | iex
```

<details><summary>Manual install</summary>

```bash
git clone https://github.com/yokeloop/yoke.git
cd yoke && ./install.sh   # or .\install.ps1 on Windows
```

</details>

> These one-liners run a remote script. Prefer to review it first — download, inspect, then run. The full source lives at [install.sh](./install.sh) and [install.ps1](./install.ps1) in this repo.

```bash
curl -fsSL https://raw.githubusercontent.com/yokeloop/yoke/main/install.sh -o install.sh
less install.sh
bash install.sh
```

```powershell
irm https://raw.githubusercontent.com/yokeloop/yoke/main/install.ps1 -OutFile install.ps1
Get-Content install.ps1 | more
.\install.ps1
```

Uninstall: re-run with `--uninstall` (macOS / Linux) or `-Uninstall` (Windows).

## Planned skills

`/polish` `/qa` `/memorize` `/merge`

## Development

Skill:

```
skills/<name>/SKILL.md
```

Command:

```
commands/<name>.md
```

Both formats use YAML frontmatter with `name` and `description`.

## Interactive review (revdiff)

yoke delegates interactive artifact review to [revdiff](https://github.com/umputun/revdiff) — a terminal TUI shipped as a separate Claude Code plugin. revdiff opens task files, plan files, and /do diffs for inline annotation; yoke folds the annotations back into the artifact.

### Install

The yoke installer provisions the revdiff binary automatically (see the top of this README). To install the Claude Code plugin separately:

```text
/plugin marketplace add umputun/revdiff
/plugin install revdiff@umputun-revdiff
```

### Terminal requirements

revdiff launches inside a terminal overlay. One of the following is required; otherwise the plugin exits with an error.

- tmux
- Zellij
- kitty
- wezterm
- Kaku
- cmux
- ghostty (macOS only)
- iTerm2 (macOS only)
- Emacs vterm

### Usage in yoke

Each yoke skill that produces an artifact offers "Review via revdiff" at its Complete phase.

- Task file (from `/yoke:task` Phase 6):
  ```text
  /revdiff --only docs/ai/<slug>/<slug>-task.md
  ```
  Reviews the markdown task file.
- Plan file (from `/yoke:plan` Phase 8):
  ```text
  /revdiff --only docs/ai/<slug>/<slug>-plan.md
  ```
  Reviews the markdown plan file.
- Code changes (from `/yoke:do` Phase 7):
  ```text
  /revdiff <base>...HEAD
  ```
  Reviews the diff produced by /do against the default branch. `<base>` resolves via the cascade `origin/HEAD` → `origin/main` → `origin/master` → `main` (see `skills/do/SKILL.md` Phase 7).

### Annotation fold-back

revdiff returns structured annotations on quit. For task and plan files, yoke applies the annotations in place and overwrites the file. For /do code review, yoke appends the annotations to the execution report at `docs/ai/<slug>/<slug>-report.md` under a `## Review notes` heading.

See https://github.com/umputun/revdiff (MIT) for binary install paths and deeper documentation.

## References

- https://github.com/Q00/ouroboros
- https://github.com/Yeachan-Heo/oh-my-claudecode
- superpowers-lab

## License

MIT
