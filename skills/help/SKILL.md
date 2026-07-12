---
name: help
description: Explains how to use yoke and lists the available skills; also greets new users. Activated when the user writes "help", "how do I use yoke", "how to use", "what skills are available", "hi", "hello", "where do I start", or on first contact with yoke.
---

# Welcome to yoke

**yoke** — a marketplace of skills and commands for Claude Code, inspired by [obra/superpowers](https://github.com/obra/superpowers).

## Skills

### /bootstrap — prepare the project

Prepares a repo for the yoke flow on first run: detects the stack, scaffolds the `.yoke/` layout (`context.md`, `journal.md`, `ai/`, `adr/`), seeds the glossary, writes the flow map `.yoke/flow.md`, and wires `CLAUDE.md` to the `.yoke/` conventions.

**Input:** the project (current directory) → **Output:** `.yoke/` skeleton + `CLAUDE.md` + `.yoke/yoke-context.md` + `.yoke/flow.md` (the flow map every skill reads)

```
/yoke:bootstrap
```

### /do — universal execution, finishing at the PR

Auto-detects the scope from its input, picks an execution mode, and drives the run all the way to a pull request:

- **Plain description** → inline (implements directly in-session).
- **Single ticket / issue URL** → sub-agents (plans, pauses only on a cold start, then executes with parallel sub-agents).
- **PRD or issue with sub-issues** → team (orchestrates a fleet of agents across all sub-issues).

Every mode ends the same way: enter a worktree on the default branch, commit each task, push, open or update the PR, comment the PR link on the ticket, and notify. `do` never merges — the merge stays your call on GitHub. The one exception is an explicit "straight to main" up front. Run `/yoke:merge` when you approve the PR.

**Input:** ticket URL, description, or nothing (uses current context) → **Output:** a ready pull request + `.yoke/ai/<slug>/<slug>-report.md`

```
/yoke:do https://github.com/owner/repo/issues/86
/yoke:do add dark theme to settings
/yoke:do
```

### /merge — the finisher after you approve the PR

The user-triggered tail of the flow. Once you approve the PR on GitHub, `/yoke:merge` runs the whole post-PR sequence from `.yoke/flow.md`: merge the PR(s), run cascade merges, run any deploy/release commands, move the ticket to its target state, clean up worktrees, and return to the default branch. Never auto-runs — the merge decision stays yours.

**Input:** optional PR URL(s) or `<slug>` (empty → the current branch's PR) → **Output:** merged PR(s) + deploy/transition per the flow map

```
/yoke:merge
```

> `/review`, `/gca`, `/gp`, and `/pr` are standalone utilities. `/do` now folds all four into its finish, so reach for them only in manual cases — reviewing existing changes, committing or pushing by hand, or opening a PR outside a `do` run.

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

### /draft — optional marking step between grill and do

A do-shaped run that marks instead of implementing: it projects the agreed plan onto the code as Markup (`TODO(yoke):` Markers plus a compilable skeleton) and opens a GitHub Draft PR for remote review. Never pauses — the Draft PR is the pause. Comment on the Draft PR and re-run `/yoke:draft` to re-mark, or run `/yoke:do <draft-PR-URL>` to implement the Markers and flip the PR to ready.

**Input:** ticket URL, description, or nothing — fresh marking; a Draft PR URL or a drafted `<slug>` — iteration → **Output:** a GitHub Draft PR carrying the Markup + `.yoke/ai/<slug>/<slug>-draft.md`

```
/yoke:draft https://github.com/owner/repo/issues/86
/yoke:draft https://github.com/owner/repo/pull/90
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

Compacts the conversation into a handoff document for a fresh agent, referencing existing artifacts. Saves to `.yoke/handoff/`.

**Input:** optional focus → **Output:** handoff doc under `.yoke/handoff/`

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

The everyday loop is short: **grill → do → PR on GitHub → merge**. `do` carries the run to a ready pull request and stops; you review and approve on GitHub; `/merge` runs the rest.

```
/yoke:bootstrap                      # prepare the project (first run) — writes .yoke/flow.md
/yoke:grill <plan>                   # stress-test the idea (grill-docs also captures terms + ADRs)
/yoke:draft <ticket | description>   # optional: mark the code, open a Draft PR to review before implementing
/yoke:do <ticket | description>      # execute end to end → a ready pull request
#  → review the PR on GitHub, comment, approve
/yoke:merge                          # merge, cascade, deploy/release, transition the ticket, clean up
/yoke:journal                        # save session memory (manual, end of session)
```

For larger, trackable work, spec it first: `/yoke:prd` → an epic GitHub issue, `/yoke:issues` → tracer-bullet sub-tasks, then hand a URL to `/yoke:do`. The manual utilities (`/review`, `/gca`, `/gp`, `/pr`) fill in when you step outside a `do` run.

## Planned skills

| Skill       | Purpose          |
| ----------- | ---------------- |
| `/polish`   | Code polishing   |
| `/qa`       | Testing          |
| `/memorize` | Saving to memory |

## Installation

```bash
claude marketplace add github:yokeloop/yoke
```
