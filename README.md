# sp

![sp — command and workflow overview](sp.png)

A marketplace of skills and commands for Claude Code, inspired by:

- [obra/superpowers](https://github.com/obra/superpowers).
- [obra/the-elements-of-style](https://github.com/obra/the-elements-of-style)
- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official)

## Skills

### /task — task definition

Accepts a ticket URL or free-form description. Explores the codebase, analyzes architecture, and produces a prompt-task with context, requirements, constraints, and clarifying questions. [Details →](docs/task.md)

```
/sp:task https://github.com/owner/repo/issues/86
/sp:task add dark theme to settings
```

**Output:** `docs/ai/<slug>/<slug>-task.md`

### /plan — implementation planning

Reads the task file, explores the codebase, makes design decisions, decomposes the work into atomic tasks with dependencies, picks the execution order (sequential/parallel), and reviews the plan. [Details →](docs/plan.md)

```
/sp:plan docs/ai/86-black-jack-page/86-black-jack-page-task.md
```

**Output:** `docs/ai/<slug>/<slug>-plan.md`

### /do — plan execution

Dispatches sub-agents for each task. After each one, runs a two-stage review (spec compliance → code quality). Polishes the code, validates (lint, types, tests, build), updates documentation, and writes a report. [Details →](docs/do.md)

```
/sp:do docs/ai/86-black-jack-page/86-black-jack-page-plan.md
```

**Output:** implemented code + `docs/ai/<slug>/<slug>-report.md`

### /review — code review report

Analyzes all changes against origin/main. Produces a report: key areas, complex decisions, risks, questions for the reviewer, manual verification scenarios. [Details →](docs/review.md)

```
/sp:review 86-black-jack-page
```

**Output:** `docs/ai/<slug>/<slug>-review.md`

### /gca — git commit with smart grouping

Analyzes changed files, classifies them into groups (feature, test, docs, style, chore), and produces atomic commits following Conventional Commits in English. Resolves the ticket ID from arguments, branch name, or SP flow. [Details →](docs/gca.md)

```
/sp:gca
/sp:gca #86
/sp:gca https://github.com/owner/repo/issues/86
```

### /gp — git push with checks and report

Inspects the repository state (branch, upstream, uncommitted changes, gh auth), pushes to remote, and prints a report: pushed commits, diff stat, branch link, PR status. [Details →](docs/gp.md)

```
/sp:gp
/sp:gp --force-with-lease
```

### /pr — create and update Pull Request

Creates or updates a GitHub PR. Builds the description from sp flow artifacts (review + report): key areas, design decisions, questions for the reviewer, risks, test plan. Without artifacts, falls back to commits and diff. Supports PR templates and auto-labels. [Details →](docs/pr.md)

```
/sp:pr
/sp:pr --draft
/sp:pr --base develop
```

### /fix — quick fix

Compressed pipeline for small changes (1–3 files). Explores the codebase, implements the fix (opus), polishes, validates, and appends an entry to the fix log. Two modes: post-flow (after task/plan/do) and standalone. Supports chains of fixes and "fix from PR comment URL". [Details →](docs/fix.md)

```
/sp:fix fix email validation — it doesn't handle empty strings
/sp:fix bump reconnect timeout from 5s to 15s
/sp:fix https://github.com/owner/repo/pull/42#discussion_r123456
```

**Output:** code + `docs/ai/<slug>/<slug>-fixes.md`

### /gst — repository status

Shows development status: branch, changes, commits relative to main, hot files, semantic summary. [Details →](docs/gst.md)

```
/sp:gst
```

### /explore — codebase exploration

Interactive Q&A over the codebase and brainstorming. Delegates research to a sub-agent, accumulates findings in a summary chain, and saves an exploration log. [Details →](docs/explore.md)

```
/sp:explore how does authorization work
/sp:explore compare caching approaches
/sp:explore what if we replaced REST with gRPC
```

**Output:** `docs/ai/<slug>/<slug>-exploration.md`

### /bootstrap — prepare project for sp flow

Detects the project stack, analyzes architecture, scans conventions, and generates CLAUDE.md and `.claude/sp-context.md`. Entry point for wiring sp into a new project. [Details →](docs/bootstrap.md)

```
/sp:bootstrap
/sp:bootstrap configure sp for this project
```

**Output:** `CLAUDE.md` + `.claude/sp-context.md`

### /hi — skills overview

Welcome skill — explains available skills and the recommended workflow. Entry point for new users. [Details →](docs/hi.md)

```
/sp:hi
```

## Local skills (development)

Skills under `.claude/skills/` are tools for developing the sp plugin itself. They are available when working in the repository but are not part of the published plugin.

### /sp-create — skill factory

Full pipeline for creating a new skill: task analysis, design with a mermaid diagram, SKILL.md and agent implementation, quality validation (elements-of-style + skill-development), documentation integration. [Details →](docs/sp-create.md)

```
/sp-create a skill for automated code review with bug hunting
/sp-create https://github.com/projectory-com/sp/issues/44
```

**Output:** `skills/<name>/SKILL.md` + agents + docs + updated README and CLAUDE.md

### /sp-release — plugin release

Quality checks (prose, structure, documentation, links), version bump, tag, push, GitHub release with changelog.

```
/sp-release minor
/sp-release 2.0.0
```

**Output:** new tag + GitHub release

## Telegram notifications

When working on multiple projects in parallel (tmux + worktree), skills send contextual notifications to Telegram: when questions need an answer, when a task is complete, when something is blocked. [Details →](docs/notify.md)

11 notification points across 5 skills: `/task`, `/plan`, `/do`, `/fix`, `/pr`. Three types: ACTION_REQUIRED, STAGE_COMPLETE, ALERT. Opt-in via env vars `CC_TELEGRAM_BOT_TOKEN` and `CC_TELEGRAM_CHAT_ID`.

## Full cycle

```
/sp:task <ticket or description>   # define the task
  → answer questions in the file
/sp:plan <path to task file>       # build the plan
  → answer questions in the file
/sp:do <path to plan file>         # execute the plan
/sp:fix <description>              # quick fix after /do
/sp:review <slug>                  # prepare the review
/sp:gp                             # push to remote
/sp:pr                             # create a pull request
```

## Structure

```
sp/
├── .claude/
│   └── skills/              # local skills (plugin development)
│       ├── sp-create/       # skill factory
│       └── sp-release/      # plugin release
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # marketplace registry
├── skills/
│   ├── hi/                  # welcome and skills overview
│   ├── bootstrap/           # prepare project for sp flow
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

```bash
# Add the marketplace
claude marketplace add github:projectory-com/sp

# Locally (for development)
git clone https://github.com/projectory-com/sp.git
claude --plugin-dir ./sp
```

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

## References

- https://github.com/Q00/ouroboros
- https://github.com/Yeachan-Heo/oh-my-claudecode
- https://plannotator.ai/
- superpowers-lab

## License

MIT
