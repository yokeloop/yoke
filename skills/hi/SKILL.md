---
name: hi
description: Greets the user and explains available yoke skills. Activate when the user writes "hi", "hello", "what can you do", "help", "where do I start", "what skills are available", or on first contact with yoke.
---

# Welcome to yoke

**yoke** — a marketplace of skills and commands for Claude Code, inspired by [obra/superpowers](https://github.com/obra/superpowers).

## Skills

### /task — task formulation

Accepts a ticket URL or description text. Explores the codebase, analyzes the architecture, and produces a prompt-task: context, requirements, constraints, clarifying questions.

**Input:** ticket URL or text → **Output:** `docs/ai/<slug>/<slug>-task.md`

```
/yoke:task https://github.com/owner/repo/issues/86

add dark theme to settings
```

### /plan — building the implementation plan

Reads the task file, explores the codebase, makes design decisions, and decomposes the task into atomic tasks with dependencies and order.

**Input:** path to task file → **Output:** `docs/ai/<slug>/<slug>-plan.md`

```
/yoke:plan docs/ai/86-black-jack-page/86-black-jack-page-task.md
```

### /do — executing the task by plan

Delegates tasks to sub-agents, runs a two-stage review (spec compliance → code quality), polishes the code, validates, updates documentation, writes the report.

**Input:** path to plan file → **Output:** implemented code + `docs/ai/<slug>/<slug>-report.md`

```
/yoke:do docs/ai/86-black-jack-page/86-black-jack-page-plan.md
```

### /review — preparing the code review report

Analyzes changes against origin/main. Produces a report: key areas, complex decisions, risks, questions for the reviewer, verification scenarios.

**Input:** task-slug → **Output:** `docs/ai/<slug>/<slug>-review.md`

```
/yoke:review 86-black-jack-page
```

## Full cycle

```
/yoke:explore <topic>                # explore the codebase
/yoke:task <ticket or description>   # formulate the task
  → answer questions in the file
/yoke:plan <path to task file>       # build the plan
  → answer questions in the file
/yoke:do <path to plan file>         # execute the plan
/yoke:fix <description>              # quick fix after /do
/yoke:review <slug>                  # prepare review
/yoke:gp                             # push to remote
/yoke:pr                             # create pull request
```

### /gca — git commit with smart grouping

Analyzes changed files, classifies them into groups, and produces atomic commits with Conventional Commits in English. Determines the ticket ID from arguments, the branch, or the yoke flow.

**Input:** optionally ticket ID or URL → **Output:** atomic git commits

```
/yoke:gca
/yoke:gca #86
```

### /gp — git push with checks and report

Checks the repository state (branch, upstream, uncommitted changes, gh auth), pushes to remote, prints a report: pushed commits, diff stat, branch link, PR status.

**Input:** optionally `--force-with-lease` → **Output:** push + report

```
/yoke:gp
/yoke:gp --force-with-lease
```

### /pr — creating and updating a Pull Request

Creates or updates a GitHub PR from yoke flow artifacts (review + report). Produces a description with key areas, design decisions, and questions for the reviewer. Without artifacts — falls back to commits. Supports PR template, auto-labels, `<!-- yoke:start/end -->` markers for update.

**Input:** optionally `--draft`, `--base <branch>` → **Output:** PR on GitHub

```
/yoke:pr
/yoke:pr --draft
```

### /fix — quick fix

Compressed pipeline for small changes (1-3 files). Explores the codebase, implements the fix (opus), polishes, validates, writes to fix-log. Two modes: post-flow (after task/plan/do) and standalone. Supports fix chains and fix from PR comment URL.

**Input:** fix description or PR comment URL → **Output:** code + `docs/ai/<slug>/<slug>-fixes.md`

```
/yoke:fix correct email validation
/yoke:fix https://github.com/owner/repo/pull/42#discussion_r123456
```

### /explore — exploring the codebase

Read-only Q&A loop for codebase exploration and brainstorming. Classifies questions (codebase / web / hybrid), searches the code and the internet, accumulates context through a summary chain, writes an exploration log.

**Input:** topic or question → **Output:** `docs/ai/<slug>/<slug>-exploration.md`

```
/yoke:explore how authentication works
/yoke:explore compare Framer Motion and react-spring for our animations
```

## Planned skills

| Skill       | Purpose          |
| ----------- | ---------------- |
| `/polish`   | Code polishing   |
| `/qa`       | Testing          |
| `/memorize` | Saving to memory |
| `/merge`    | Branch merging   |

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

Uninstall: re-run with `--uninstall`.
