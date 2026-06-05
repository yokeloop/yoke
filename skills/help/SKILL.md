---
name: help
description: Explains how to use yoke and lists the available skills; also greets new users. Activated when the user writes "help", "how do I use yoke", "how to use", "what skills are available", "hi", "hello", "where do I start", or on first contact with yoke.
---

# Welcome to yoke

**yoke** — a marketplace of skills and commands for Claude Code, inspired by [obra/superpowers](https://github.com/obra/superpowers).

## Skills

### /bootstrap — prepare the project

Prepares a repo for the yoke flow on first run: detects the stack, scaffolds the `.yoke/` layout (`context.md`, `journal.md`, `ai/`, `adr/`), seeds the glossary, and wires `CLAUDE.md` to the `.yoke/` conventions.

**Input:** the project (current directory) → **Output:** `.yoke/` skeleton + `CLAUDE.md` + `.claude/yoke-context.md`

```
/yoke:bootstrap
```

### /do — universal execution

Auto-detects the scope from its input and picks the right execution mode:

- **Plain description** → inline (implements directly in-session, no pause).
- **Single ticket / issue URL** → sub-agents (writes a plan, pauses for confirmation, then executes with parallel sub-agents).
- **PRD or issue with sub-issues** → team (orchestrates a fleet of agents across all sub-issues).

**Input:** ticket URL, description, or nothing (uses current context) → **Output:** implemented code + `.yoke/ai/<slug>/<slug>-report.md`

```
/yoke:do https://github.com/owner/repo/issues/86
/yoke:do add dark theme to settings
/yoke:do
```

### /review — preparing the code review report

Analyzes changes against origin/main. Produces a report: key areas, complex decisions, risks, questions for the reviewer, verification scenarios.

**Input:** task-slug → **Output:** `.yoke/ai/<slug>/<slug>-review.md`

```
/yoke:review 86-black-jack-page
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

### /grill — interactive plan grilling

Interrogates the user about a plan or design one question at a time via AskUserQuestion (recommended answer first), walking the decision tree to a shared understanding. Read-only.

**Input:** plan or topic → **Output:** shared understanding (no file)

```
/yoke:grill should we cache sessions in Redis or Postgres
```

### /grill-docs — grilling with domain docs

Same grilling, plus it maintains the glossary `.yoke/context.md` and ADRs in `.yoke/adr/` inline as decisions land.

**Input:** plan or topic → **Output:** `.yoke/context.md` + `.yoke/adr/NNNN-*.md`

```
/yoke:grill-docs design the order cancellation flow
```

### /prd — PRD from context

Synthesizes the current conversation into a PRD, publishes it as a GitHub issue (`ready-for-agent`), and saves a local copy. No interview.

**Input:** current context → **Output:** GitHub issue + `.yoke/ai/<slug>/<slug>-prd.md`

```
/yoke:prd
```

### /issues — break work into issues

Breaks a plan, spec, or PRD into independently-grabbable GitHub issues using vertical slices (tracer bullets), in dependency order.

**Input:** context or issue reference → **Output:** GitHub issues + `.yoke/ai/<slug>/<slug>-issues.md`

```
/yoke:issues
/yoke:issues https://github.com/owner/repo/issues/42
```

### /handoff — conversation handoff

Compacts the conversation into a handoff document for a fresh agent, referencing existing artifacts. Saves to the OS temp directory.

**Input:** optional focus → **Output:** handoff doc in the OS temp directory

```
/yoke:handoff
```

### /journal — session memory

Appends a concise, newest-first entry to `.yoke/journal.md` summarizing the session's work and linking the relevant `.yoke/ai/<slug>/` artifacts — the first layer of yoke's connected memory. Triggered manually.

**Input:** current session → **Output:** appended entry in `.yoke/journal.md`

```
/yoke:journal
```

## Full cycle

```
/yoke:bootstrap                      # prepare the project (first run)
/yoke:grill <plan>                   # stress-test the idea (optional)
/yoke:grill-docs <plan>              # …and capture terms + ADRs (optional)
/yoke:prd                            # PRD → GitHub issue (optional)
/yoke:issues                         # break into issues (optional)
/yoke:do <ticket | description>      # execute — inline / sub-agents / team
/yoke:review <slug>                  # prepare review
/yoke:gca                            # commit changes
/yoke:gp                             # push to remote
/yoke:pr                             # create pull request
/yoke:journal                        # save session memory (manual, end of session)
```

## Planned skills

| Skill       | Purpose          |
| ----------- | ---------------- |
| `/polish`   | Code polishing   |
| `/qa`       | Testing          |
| `/memorize` | Saving to memory |
| `/merge`    | Branch merging   |

## Installation

```bash
claude marketplace add github:yokeloop/yoke
```
