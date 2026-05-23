# yoke-pi Repository Creation Plan

> Date: 2026-04-27
> Status: Draft

## Contents

1. [Overview and goals](#1-overview-and-goals)
2. [Repository structure](#2-repository-structure)
3. [Phase 0: Repository preparation](#3-phase-0-repository-preparation)
4. [Phase 1: Infrastructure and packages](#4-phase-1-infrastructure-and-packages)
5. [Phase 2: Agents — the single source of truth](#5-phase-2-agents--the-single-source-of-truth)
6. [Phase 3: SKILL.md — universal orchestrators](#6-phase-3-skillmd--universal-orchestrators)
7. [Phase 4: Porting skills — by order of complexity](#7-phase-4-porting-skills--by-order-of-complexity)
8. [Phase 5: Extensions and notifications](#8-phase-5-extensions-and-notifications)
9. [Phase 6: Documentation and CI](#9-phase-6-documentation-and-ci)
10. [Phase 7: Testing and polish](#10-phase-7-testing-and-polish)
11. [Acceptance criteria](#11-acceptance-criteria)
12. [Risks](#12-risks)
13. [Effort estimate](#13-effort-estimate)
14. [Appendices](#appendices)

---

## 1. Overview and goals

### What we are building

A full clone of the `yokeloop/yoke` repository, rewritten for the pi dev ecosystem. New name: **`yoke-pi`** (repository `yokeloop/yoke-pi`).

### Goals

1. **Full feature parity** — all 12 skills work in pi exactly as they do in Claude Code
2. **Compatibility with pi plugins** — pi-subagents, pi-ask-user, pi-intercom
3. **Native pi patterns** — `subagent()`, `ask_user()`, `.pi/` instead of `.claude/`, AGENTS.md
4. **One-command install** — `pi install npm:yoke-pi` (or `pi install git:yokeloop/yoke-pi`)
5. **Knowledge backward compatibility** — the skill architecture, phases, and artifacts (task.md, plan.md, report.md) stay the same

### What we are NOT doing

- ❌ Supporting two harnesses in one repository simultaneously — too expensive
- ❌ Universal SKILL.md files with `<!-- CC -->` / `<!-- Pi -->` conditionals — each skill is rewritten entirely for pi
- ❌ Keeping the Claude Code plugin — the original `yoke` stays in `yokeloop/yoke`

---

## 2. Repository structure

```
yoke-pi/
├── package.json                    # npm package yoke-pi
├── README.md                       # Documentation
├── LICENSE                         # MIT
├── AGENTS.md                       # Instructions for pi (instead of CLAUDE.md)
├── .gitignore
├── .editorconfig
├── .prettierrc.json
├── .prettierignore
├── .husky/
│   └── pre-commit                  # prettier
│
├── agents/                         # Single source of truth — 37 agents
│   ├── stack-detector.md
│   ├── architecture-mapper.md
│   ├── convention-scanner.md
│   ├── validation-scanner.md
│   ├── existing-rules-detector.md
│   ├── domain-analyzer.md
│   ├── claude-md-generator.md      # → rename to project-md-generator.md
│   ├── yoke-context-generator.md
│   ├── automation-recommender.md
│   ├── bootstrap-verifier.md
│   ├── task-executor.md
│   ├── spec-reviewer.md
│   ├── quality-reviewer.md
│   ├── code-polisher.md
│   ├── validator.md
│   ├── formatter.md
│   ├── doc-updater.md
│   ├── report-writer.md
│   ├── explore-agent.md
│   ├── explore-log-writer.md
│   ├── fix-context-collector.md
│   ├── fix-investigator.md
│   ├── fix-log-writer.md
│   ├── git-data-collector.md
│   ├── git-pre-checker.md
│   ├── git-pusher.md
│   ├── plan-explorer.md
│   ├── plan-designer.md
│   ├── plan-reviewer.md
│   ├── pr-data-collector.md
│   ├── pr-body-generator.md
│   ├── code-reviewer.md
│   ├── issue-fixer.md
│   ├── single-fix-agent.md
│   ├── review-report-writer.md
│   ├── task-explorer.md
│   └── task-architect.md
│
├── skills/                          # 12 SKILL.md (rewritten for pi)
│   ├── bootstrap/SKILL.md
│   │   └── reference/              # Reference docs (carried over as-is)
│   │       ├── project-md-template.md      # formerly claude-md-template.md
│   │       ├── hooks-patterns.md
│   │       ├── mcp-servers.md
│   │       ├── quality-criteria.md
│   │       └── update-guidelines.md
│   ├── do/SKILL.md
│   │   └── reference/
│   ├── explore/SKILL.md
│   │   └── reference/
│   ├── fix/SKILL.md
│   │   └── reference/
│   ├── gca/SKILL.md
│   │   └── reference/
│   ├── gp/SKILL.md
│   ├── gst/SKILL.md
│   ├── hi/SKILL.md
│   ├── plan/SKILL.md
│   │   └── reference/
│   │   └── examples/
│   ├── pr/SKILL.md
│   │   └── reference/
│   ├── review/SKILL.md
│   │   └── reference/
│   └── task/SKILL.md
│       └── reference/
│       └── examples/
│
├── extensions/                      # pi extensions
│   └── yoke-notify.ts               # Notifications (replacement for hooks/notify.sh)
│
├── docs/                            # Skill documentation
│   ├── task.md
│   ├── plan.md
│   ├── do.md
│   ├── review.md
│   ├── gca.md
│   ├── gp.md
│   ├── pr.md
│   ├── gst.md
│   ├── fix.md
│   ├── explore.md
│   ├── bootstrap.md
│   ├── hi.md
│   └── notify.md
│
├── yoke.png                         # Logo
│
└── scripts/
    └── validate.ts                   # Package validation
```

### Key differences from the original yoke

| What            | yoke (Claude Code)                     | yoke-pi (pi)                                          |
| --------------- | -------------------------------------- | ----------------------------------------------------- |
| Agents          | `skills/*/agents/*.md` (inside skills) | `agents/*.md` (root, single directory)                |
| SKILL.md        | Dispatches via `Agent tool`            | Dispatches via `subagent()`                           |
| Q&A             | `AskUserQuestion`                      | `ask_user()`                                          |
| Arguments       | `$ARGUMENTS`                           | Text after `/skill:name`                              |
| Path to root    | `${CLAUDE_PLUGIN_ROOT}`                | Relative paths / agent names                          |
| Project context | `.claude/yoke-context.md`              | `.pi/yoke-context.md`                                 |
| Project rules   | `CLAUDE.md`                            | `AGENTS.md`                                           |
| Plugin file     | `.claude-plugin/plugin.json`           | `package.json` (pi key)                               |
| Manifest        | `.claude-plugin/marketplace.json`      | `package.json` (pi key)                               |
| Notifications   | `hooks/hooks.json` + `lib/notify.sh`   | `extensions/yoke-notify.ts`                           |
| Progress        | `TodoWrite`                            | Markdown checklists + subagent progress               |
| Templates       | `{{PLACEHOLDER}}` by the orchestrator  | Context via the `task:` string                        |
| Namespace       | `/yoke:<name>`                         | `/skill:<name>` (or `/skill:yoke-<name>` on conflict) |
| Locale skills   | `.claude/skills/`                      | `.pi/skills/`                                         |

---

## 3. Phase 0: Repository preparation

### 0.1. Create the repository

```bash
# Clone the original as a starting point
git clone https://github.com/yokeloop/yoke.git yoke-pi
cd yoke-pi

# Rewrite history so we don't drag in junk
# Or start a clean repository and copy over the needed files
```

### 0.2. Remove Claude Code-specific files

```bash
rm -rf .claude-plugin/
rm -rf .claude/
rm -rf hooks/
rm -f  lib/notify.sh
rm -rf docs/ai/          # Example artifacts — not needed in the repo
```

### 0.3. Create package.json

```json
{
  "name": "yoke-pi",
  "version": "1.0.0",
  "description": "A marketplace of skills for pi dev — task, plan, do, review, gca, gp, pr, gst, fix, explore, bootstrap, hi",
  "author": { "name": "Heliotic" },
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/yokeloop/yoke-pi.git"
  },
  "keywords": ["pi-package", "pi", "pi-coding-agent", "skills", "workflow", "productivity", "yoke"],
  "pi": {
    "extensions": ["./extensions/yoke-notify.ts"],
    "skills": ["./skills"],
    "agents": ["./agents"]
  },
  "scripts": {
    "format": "prettier --write '**/*.{md,json,ts}'",
    "format:check": "prettier --check '**/*.{md,json,ts}'",
    "validate": "tsx scripts/validate.ts"
  },
  "devDependencies": {
    "husky": "^9.1.7",
    "lint-staged": "^15.4.3",
    "prettier": "^3.5.3",
    "tsx": "^4.19.0",
    "@mariozechner/pi-coding-agent": "*",
    "@sinclair/typebox": "*"
  },
  "lint-staged": {
    "*.{md,json,ts}": "prettier --write"
  },
  "peerDependencies": {
    "@mariozechner/pi-coding-agent": "*"
  },
  "files": ["agents/", "skills/", "extensions/", "docs/", "README.md", "LICENSE", "AGENTS.md", "yoke.png"]
}
```

### 0.4. Create .gitignore

```
node_modules/
.yoke/
.worktrees/
.config/wt.toml*
.pi/
```

### 0.5. Create AGENTS.md (instead of CLAUDE.md)

```markdown
# AGENTS.md

## Project

**yoke-pi** — a marketplace of skills for pi dev, adapted from [yokeloop/yoke](https://github.com/yokeloop/yoke).

## Architecture
```

agents/ # Subagent definitions — discovered by pi-subagents
skills/ # Skills — discovered by pi skill system
extensions/ # pi extensions (yoke-notify)
docs/ # Per-skill documentation

```

## Key differences from yoke (Claude Code)

- **Agents** are in `agents/` root, discovered by pi-subagents by name
- **Skills** use `subagent()` instead of Agent tool, `ask_user()` instead of AskUserQuestion
- **Project context** is `.pi/yoke-context.md` instead of `.claude/yoke-context.md`
- **Notifications** use pi extensions instead of hooks

## Skills

(Same list as original yoke — task, plan, do, review, etc.)

## Conventions

- Content language: English by default. Skills adapt to the input language.
- Files and directories: kebab-case
- Versioning: semver in package.json
- SKILL.md frontmatter: `name` (identifier, kebab-case), `description` (when to activate)
```

### 0.6. Set up husky and formatting

Copy `.husky/pre-commit`, `.prettierrc.json`, `.prettierignore`, and `.editorconfig` from the original.

---

## 4. Phase 1: Infrastructure and packages

### 1.1. pi dependencies

In `.pi/settings.json` (project) or `~/.pi/agent/settings.json` (global):

```json
{
  "packages": ["npm:pi-subagents", "npm:pi-ask-user", "npm:pi-intercom"]
}
```

These packages are installed by the user when installing yoke-pi. The README will include instructions.

### 1.2. Test installation

```bash
# Install dependencies
pi install npm:pi-subagents
pi install npm:pi-ask-user
pi install npm:pi-intercom

# Run yoke-pi locally
pi --skill-dir ./skills --agents-dir ./agents
```

---

## 5. Phase 2: Agents — the single source of truth

All 37 agents move into the root `agents/` directory. Each agent is rewritten in the pi-subagents format.

### 5.1. The `agents/` directory

Why in the root rather than inside the skills:

1. pi-subagents looks for agents in `.pi/agents/` and `agents/` — a single directory is more convenient
2. Agents are used by several skills (task-executor is used by do and fix)
3. When installed as an npm package, `agents/` unpacks into the project

**Alternative**: place agents in `.pi/agents/` inside the project — but then they aren't included in the npm package automatically. We recommend `agents/` in the root, with `package.json > pi.agents` pointing to it.

### 5.2. Agent format

Each `agents/<name>.md` is rewritten with new frontmatter:

**Before (Claude Code):**

```yaml
---
name: stack-detector
description: >-
  Detects the tech stack of the project: languages, frameworks, build tools,
  package managers, config files.
tools: Bash, Glob, Read
model: haiku
color: cyan
---
```

**After (Pi):**

```yaml
---
name: stack-detector
description: >-
  Detects the tech stack of the project: languages, frameworks, build tools,
  package managers, config files.
tools: bash, find, read, ls
model: anthropic/claude-haiku-4-5
systemPromptMode: replace
inheritProjectContext: true
inheritSkills: false
output: context.md
defaultProgress: true
---
```

### 5.3. Full agent rename and mapping table

#### Renames

| Old name              | New name               | Reason                  |
| --------------------- | ---------------------- | ----------------------- |
| `claude-md-generator` | `project-md-generator` | Not tied to Claude Code |

#### Tool mapping (for all agents)

| Claude Code    | Pi      | Remove                                   |
| -------------- | ------- | ---------------------------------------- |
| `Read`         | `read`  | —                                        |
| `Write`        | `write` | —                                        |
| `Edit`         | `edit`  | —                                        |
| `Bash`         | `bash`  | —                                        |
| `Glob`         | `find`  | —                                        |
| `Grep`         | `grep`  | —                                        |
| `LS`           | `ls`    | —                                        |
| `NotebookRead` | —       | ✗                                        |
| `WebFetch`     | —       | ✗ (or `fetch_content` via pi-web-access) |
| `WebSearch`    | —       | ✗ (or `web_search` via pi-web-access)    |
| `TodoWrite`    | —       | ✗                                        |
| `KillShell`    | —       | ✗                                        |
| `BashOutput`   | —       | ✗                                        |

#### Model mapping

| Claude Code | Pi                           |
| ----------- | ---------------------------- |
| `haiku`     | `anthropic/claude-haiku-4-5` |
| `sonnet`    | `anthropic/claude-sonnet-4`  |
| `opus`      | `anthropic/claude-opus-4`    |

#### Pi-specific fields (added to all agents)

| Field                   | Value        | Note                             |
| ----------------------- | ------------ | -------------------------------- |
| `systemPromptMode`      | `replace`    | The agent gets a clean prompt    |
| `inheritProjectContext` | `true`       | Inherits AGENTS.md, .pi/settings |
| `inheritSkills`         | `false`      | Does not inherit global skills   |
| `output`                | `context.md` | Where to write the result        |
| `defaultProgress`       | `true`       | Maintain progress.md             |

### 5.4. Changes to the agent prompt bodies

1. **Remove `TodoWrite`** — delete all mentions
2. **Remove `{{PLACEHOLDER}}`** — replace with instructions "Context is passed via task"
3. **Remove `Read ${CLAUDE_PLUGIN_ROOT}/...`** — replace with "Read files from the task argument"
4. **`.claude/yoke-context.md`** → `.pi/yoke-context.md`
5. **`CLAUDE.md`** → `AGENTS.md`
6. **Remove `NotebookRead`, `KillShell`, `BashOutput`** from the list of allowed actions
7. **Remove `color:` from the frontmatter**

### 5.5. Example of a rewritten agent

**`agents/stack-detector.md`:**

````markdown
---
name: stack-detector
description: >-
  Detects the tech stack of the project: languages, frameworks, build tools,
  package managers, config files.
tools: bash, find, read, ls
model: anthropic/claude-haiku-4-5
systemPromptMode: replace
inheritProjectContext: true
inheritSkills: false
output: context.md
defaultProgress: true
---

# Stack Detector

Detects the technology stack of the project.

## Process

1. **Package manifests** — check for `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `pom.xml`, `build.gradle`, etc.
2. **Config files** — check for `.eslintrc`, `tsconfig.json`, `Dockerfile`, `docker-compose.yml`, CI configs
3. **Lock files** — check for `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
4. **Source patterns** — glob for .ts, .py, .go, .java, .rb, .rs, etc.
5. **Dev tools** — check for `Makefile`, `justfile`, `Taskfile.yml`

Run each check. On command error — record it and continue.

## Structured Output

Return the data strictly in this format:

```yaml
PATTERN: <monorepo | monolith | microservices | plugin | cli | static-site | flat>
KEY_DIRS:
  - <dir> — <purpose>
  ...
ENTRY_POINTS:
  - <path> — <type>
  ...
LANGUAGES:
  - <language>: <presence indicator>
  ...
FRAMEWORKS:
  - <framework>: <version if detectable>
  ...
BUILD_TOOLS:
  - <tool>: <config file>
  ...
PACKAGE_MANAGERS:
  - <manager>: <lock file>
  ...
TEST_FRAMEWORKS:
  - <framework>: <config>
  ...
ENV_FILES:
  - <filename>: <purpose>
  ...
```
````

## Rules

- Read-only. Do not modify the repository.
- Command error — record it and continue.
- Return data. The orchestrator makes decisions.

````

### 5.6. List of all 37 agents to port

| # | Agent | Lines | Skill | CC tools | Pi tools | Pi model | Complexity |
|---|---|---|---|---|---|---|---|
| 1 | stack-detector | 104 | bootstrap | Bash, Glob, Read | bash, find, read, ls | haiku-4-5 | easy |
| 2 | architecture-mapper | 116 | bootstrap | Glob, Grep, Read, Bash | find, grep, read, bash, ls | sonnet-4 | easy |
| 3 | convention-scanner | 110 | bootstrap | Glob, Grep, Read | find, grep, read, ls | sonnet-4 | easy |
| 4 | validation-scanner | 92 | bootstrap | Bash, Glob, Read | bash, find, read, ls | haiku-4-5 | easy |
| 5 | existing-rules-detector | 108 | bootstrap | Bash, Read, Glob | bash, read, find, ls | haiku-4-5 | easy |
| 6 | domain-analyzer | 213 | bootstrap | Glob, Grep, Read, Bash | find, grep, read, bash, ls | sonnet-4 | medium |
| 7 | project-md-generator | 104 | bootstrap | Read, Write, Edit, Glob | read, write, edit, find, ls | sonnet-4 | easy |
| 8 | yoke-context-generator | 102 | bootstrap | Read, Write, Bash, Glob | read, write, bash, find, ls | haiku-4-5 | easy |
| 9 | automation-recommender | 65 | bootstrap | Read | read | haiku-4-5 | easy |
| 10 | bootstrap-verifier | 97 | bootstrap | Read, Bash, Glob | read, bash, find, ls | sonnet-4 | easy |
| 11 | task-executor | 190 | do | Read, Write, Edit, Bash, Glob, Grep, LS, NotebookRead, WebFetch, TodoWrite | read, write, edit, bash, find, grep, ls | opus-4 | medium |
| 12 | spec-reviewer | 59 | do | Read, Glob, Grep, LS | read, find, grep, ls | sonnet-4 | easy |
| 13 | quality-reviewer | 75 | do | Read, Glob, Grep, LS, Bash | read, find, grep, ls, bash | sonnet-4 | easy |
| 14 | code-polisher | 67 | do | Read, Write, Edit, Bash, Glob, Grep, LS | read, write, edit, bash, find, grep, ls | opus-4 | easy |
| 15 | validator | 112 | do | Read, Edit, Bash, Glob, Grep, LS | read, edit, bash, find, grep, ls | haiku-4-5 | medium |
| 16 | formatter | 83 | do | Read, Bash, Glob, Grep, LS | read, bash, find, grep, ls | haiku-4-5 | easy |
| 17 | doc-updater | 87 | do | Read, Write, Edit, Bash, Glob, Grep, LS | read, write, edit, bash, find, grep, ls | sonnet-4 | easy |
| 18 | report-writer | 56 | do | Read, Write, Bash, Glob, LS | read, write, bash, find, ls | haiku-4-5 | easy |
| 19 | explore-agent | 100 | explore | Glob, Grep, LS, Read, Bash, WebSearch, WebFetch | find, grep, ls, read, bash | sonnet-4 | medium |
| 20 | explore-log-writer | 87 | explore | Read, Write, Edit, Bash | read, write, edit, bash | haiku-4-5 | easy |
| 21 | fix-context-collector | 130 | fix | Bash, Glob, LS | bash, find, ls | haiku-4-5 | medium |
| 22 | fix-investigator | 86 | fix | Glob, Grep, LS, Read, Bash | find, grep, ls, read, bash | sonnet-4 | easy |
| 23 | fix-log-writer | 95 | fix | Read, Write, Edit, Bash | read, write, edit, bash | haiku-4-5 | easy |
| 24 | git-data-collector | 195 | gst | Bash | bash | haiku-4-5 | medium |
| 25 | git-pre-checker | 150 | gp | Bash | bash | haiku-4-5 | medium |
| 26 | git-pusher | 109 | gp | Bash | bash | haiku-4-5 | easy |
| 27 | plan-explorer | 108 | plan | Glob, Grep, LS, Read, ✗4 | find, grep, ls, read | sonnet-4 | medium |
| 28 | plan-designer | 118 | plan | Glob, Grep, LS, Read, ✗4 | find, grep, ls, read | opus-4 | medium |
| 29 | plan-reviewer | 78 | plan | Glob, Grep, LS, Read, ✗1 | find, grep, ls, read | sonnet-4 | easy |
| 30 | pr-data-collector | 175 | pr | Bash, Read, Glob | bash, read, find | haiku-4-5 | medium |
| 31 | pr-body-generator | 103 | pr | Read | read | sonnet-4 | easy |
| 32 | code-reviewer | 118 | review | Read, Bash, Glob, Grep | read, bash, find, grep | sonnet-4 | medium |
| 33 | issue-fixer | 67 | review | Read, Bash, Glob, Grep | read, bash, find, grep | sonnet-4 | easy |
| 34 | single-fix-agent | 49 | review | Read, Edit, Bash, Glob, Grep, LS | read, edit, bash, find, grep, ls | opus-4 | easy |
| 35 | review-report-writer | 84 | review | Read, Write, Bash, Glob, Grep | read, write, bash, find, grep | sonnet-4 | easy |
| 36 | task-explorer | 62 | task | Glob, Grep, LS, Read, ✗4 | find, grep, ls, read | sonnet-4 | easy |
| 37 | task-architect | 41 | task | Glob, Grep, LS, Read, ✗4 | find, grep, ls, read | opus-4 | easy |

✗ = excluded: NotebookRead, WebFetch, WebSearch, TodoWrite, KillShell, BashOutput

---

## 6. Phase 3: SKILL.md — universal orchestrators

### 6.1. Principles for rewriting SKILL.md

1. **Frontmatter does not change** — `name` and `description` stay the same (the pi skill spec uses the same Agent Skills format)
2. **Agent tool → `subagent()`** — all dispatches are rewritten
3. **AskUserQuestion → `ask_user()`** — all Q&A is rewritten
4. **`$ARGUMENTS` → instruction** — "The user's input follows the skill name"
5. **`${CLAUDE_PLUGIN_ROOT}` → agent names** — `subagent({ agent: "stack-detector" })` instead of `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap/agents/stack-detector.md`
6. **`TodoWrite` → markdown checklist** — progress is tracked as text
7. **`{{PLACEHOLDER}}` → context via `task:`** — the orchestrator builds a string with the data
8. **`.claude/yoke-context.md` → `.pi/yoke-context.md`**
9. **`CLAUDE.md` → `AGENTS.md`**
10. **Path references to reference/ — stay relative** — `reference/commit-convention.md` works in both environments

### 6.2. Rewrite patterns

#### Pattern: Dispatch a single agent

```markdown
# Before (Claude Code)
Run `git-data-collector` via the Agent tool:
- Agent: `${CLAUDE_PLUGIN_ROOT}/skills/gst/agents/git-data-collector.md`
- Prompt: "Collect data on the current git repository state and produce a report"

# After (Pi)
Run `git-data-collector` via subagent:
subagent({ agent: "git-data-collector", task: "Collect data on the current git repository state and produce a report" })
````

#### Pattern: Parallel dispatch

```markdown
# Before (Claude Code)

Dispatch 6 agents **in parallel** via the Agent tool (6 calls at once):

1. **stack-detector** (haiku) — read `agents/stack-detector.md`, pass the prompt.
2. **architecture-mapper** (sonnet) — read `agents/architecture-mapper.md`, pass the prompt.
   ...

# After (Pi)

Collect project information in parallel:
subagent({ tasks: [
{ agent: "stack-detector", task: "Detect the tech stack..." },
{ agent: "architecture-mapper", task: "Map the architecture..." },
{ agent: "convention-scanner", task: "Scan conventions..." },
{ agent: "validation-scanner", task: "Scan validation..." },
{ agent: "existing-rules-detector", task: "Detect existing rules..." },
{ agent: "domain-analyzer", task: "Analyze the domain..." }
], concurrency: 6 })
```

#### Pattern: Chain

```markdown
# Before (Claude Code)

Phase 6: Run sub-agents sequentially.

1. spec-reviewer → read `agents/spec-reviewer.md`, dispatch.
2. quality-reviewer → read `agents/quality-reviewer.md`, dispatch.
3. code-polisher → read `agents/code-polisher.md`, dispatch.
4. validator → read `agents/validator.md`, dispatch.
5. doc-updater → read `agents/doc-updater.md`, dispatch.
6. formatter → read `agents/formatter.md`, dispatch.

# After (Pi)

Run the review and polish chain:
subagent({ chain: [
{ agent: "spec-reviewer", task: "Verify that the implementation matches the spec from {previous}" },
{ agent: "quality-reviewer", task: "Check code quality from {previous}" },
{ agent: "code-polisher", task: "Polish code from {previous}" },
{ agent: "validator", task: "Run validation from {previous}" },
{ agent: "doc-updater", task: "Update documentation from {previous}" },
{ agent: "formatter", task: "Format changed files from {previous}" }
] })
```

#### Pattern: AskUserQuestion

```markdown
# Before (Claude Code)

AskUserQuestion with 3 options:

1. Add exception `.claude/yoke-context.md` to .gitignore — commit both files
2. Commit only `CLAUDE.md` — skip yoke-context
3. Cancel — tell the user and exit

# After (Pi)

ask_user({
question: "How should we handle the generated files in git?",
context: "CLAUDE.md and yoke-context.md have been created. .claude/ may be in .gitignore.",
options: [
{ title: "Add .pi/yoke-context.md exception to .gitignore", description: "Commit both files" },
{ title: "Commit only AGENTS.md", description: "Skip yoke-context" },
{ title: "Cancel", description: "Don't commit anything" }
],
allowFreeform: true
})
```

#### Pattern: Variables in task

```markdown
# Before (Claude Code)

Dispatch `task-executor` with:

- TASK_WHAT: {{TASK_WHAT}}
- TASK_HOW: {{TASK_HOW}}
- TASK_FILES: {{TASK_FILES}}

# After (Pi)

subagent({
agent: "task-executor",
task: `Execute the following task:

What: ${TASK_WHAT}

How: ${TASK_HOW}

Files to create/change: ${TASK_FILES}

Verify: ${TASK_VERIFY}

If the file .pi/yoke-context.md exists — read it first.`
})
```

### 6.3. Renames in reference/

| File                 | Old name                 | New name                          |
| -------------------- | ------------------------ | --------------------------------- |
| bootstrap/reference/ | `claude-md-template.md`  | `project-md-template.md`          |
| bootstrap/reference/ | `hooks-patterns.md`      | Rewrite: CC hooks → pi extensions |
| bootstrap/SKILL.md   | References to `.claude/` | `.pi/`                            |

---

## 7. Phase 4: Porting skills — by order of complexity

### 7.1. Ordering

| #   | Skill         | Complexity | Agents | Priority | Typical changes                                         |
| --- | ------------- | ---------- | ------ | -------- | ------------------------------------------------------- |
| 1   | **hi**        | 🟢         | 0      | 1        | Update skill descriptions, remove `/yoke:`              |
| 2   | **gst**       | 🟡         | 1      | 2        | `subagent()` instead of Agent tool                      |
| 3   | **gca**       | 🟡         | 0      | 3        | `ask_user()`, remove `$ARGUMENTS`                       |
| 4   | **gp**        | 🟡         | 2      | 4        | `subagent()`, remove `CLAUDE_PLUGIN_ROOT`               |
| 5   | **explore**   | 🟡         | 2      | 5        | `ask_user()`, `subagent()`, remove TodoWrite            |
| 6   | **pr**        | 🟡         | 2      | 6        | `subagent()`, `ask_user()`, remove `CLAUDE_PLUGIN_ROOT` |
| 7   | **task**      | 🟡         | 2      | 7        | `subagent()`, remove CC-specific tools                  |
| 8   | **plan**      | 🔴         | 3      | 8        | `subagent({ chain })`, remove templates, CC tools       |
| 9   | **review**    | 🔴         | 4+2    | 9        | Parallel fix agents, cross-skill references             |
| 10  | **fix**       | 🔴         | 3+3    | 10       | Cross-skill references, `ask_user()`, escalation        |
| 11  | **bootstrap** | 🔴         | 10     | 11       | Parallel dispatch, `.claude/` → `.pi/`, templates       |
| 12  | **do**        | 🔴         | 8      | 12       | Chain, review loop, cross-reference to gca              |

### 7.2. Detailed plan for each simple skill

#### hi (21 lines) — 15 min

- Remove `/yoke:` prefixes → `/skill:`
- Update skill descriptions (pi structure: `subagent()`, `ask_user()`)

#### gst (21 lines) — 30 min

- `Agent tool` dispatch → `subagent({ agent: "git-data-collector", task: "..." })`
- Remove `${CLAUDE_PLUGIN_ROOT}/skills/gst/agents/git-data-collector.md`

#### gca (128 lines) — 1 hour

- `AskUserQuestion` → `ask_user()` (3 occurrences)
- `$ARGUMENTS` → instruction about arguments
- `TodoWrite` → remove
- `reference/` — leave as-is

#### gp (156 lines) — 1.5 hours

- `Agent tool` dispatch → `subagent()` for 2 agents
- `${CLAUDE_PLUGIN_ROOT}` → agent names
- `$ARGUMENTS` → instruction

#### explore (154 lines) — 2 hours

- `Agent tool` dispatch → `subagent()` for 2 agents
- `AskUserQuestion` → `ask_user()` (3 occurrences)
- `$ARGUMENTS` → instruction
- `TodoWrite` → markdown checklist

#### pr (157 lines) — 2 hours

- `Agent tool` dispatch → `subagent()` for 2 agents
- `AskUserQuestion` → `ask_user()`
- `$ARGUMENTS` → instruction
- `${CLAUDE_PLUGIN_ROOT}` → agent names

#### task (286 lines) — 2.5 hours

- `Agent tool` dispatch → `subagent()` for 2 agents
- `AskUserQuestion` → `ask_user()`
- `$ARGUMENTS` → instruction
- Remove KillShell, BashOutput, WebSearch, WebFetch from the references

### 7.3. Detailed plan for the complex skills

#### plan (315 lines) — 3 hours

- 3 agents → `subagent({ chain: [...] })`
- Remove `{{PLACEHOLDER}}` — the orchestrator assembles context for `task:`
- Remove KillShell, BashOutput, WebSearch, WebFetch
- `AskUserQuestion` → `ask_user()`
- `TodoWrite` → markdown checklist

#### review (187 lines) — 3 hours

- 4 own + 2 cross-skill agents → `subagent()` by name
- Parallel fix agents → `subagent({ tasks: [...] })`
- `${CLAUDE_PLUGIN_ROOT}` → agent names
- `AskUserQuestion` → `ask_user()`

#### fix (287 lines) — 3.5 hours

- 3 own + 3 cross-skill agents → `subagent()` by name
- `AskUserQuestion` → `ask_user()`
- `${CLAUDE_PLUGIN_ROOT}` → agent names
- `TodoWrite` → remove
- `notify.sh` → `ask_user()` + markdown note

#### bootstrap (356 lines) — 4 hours

- 10 agents → parallel dispatch `subagent({ tasks: [...], concurrency: 6 })`
- `{{PLACEHOLDER}}` templates → context via `task:` strings
- `AskUserQuestion` → `ask_user()`
- `TodoWrite` → markdown checklist
- `.claude/` → `.pi/`
- `${CLAUDE_PLUGIN_ROOT}` → agent names
- `notify.sh` → pi extension

#### do (312 lines) — 4 hours

- 8 agents → `subagent({ chain: [...] })`
- Parallel `task-executor` → `subagent({ tasks: [...] })`
- `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md` → the agent reads the file directly
- `TodoWrite` → remove
- `notify.sh` → pi extension
- `{{PLACEHOLDER}}` → context via `task:` strings

---

## 8. Phase 5: Extensions and notifications

### 8.1. `extensions/yoke-notify.ts`

Replacement for `hooks/hooks.json` + `lib/notify.sh` + `hooks/notify.sh`.

```typescript
// extensions/yoke-notify.ts
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // Register a custom tool for notifications
  pi.registerTool({
    name: "yoke_notify",
    label: "Yoke Notification",
    description:
      "Send a notification about a yoke skill event. Use for ACTION_REQUIRED, STAGE_COMPLETE, and ALERT events.",
    parameters: {
      type: "object",
      properties: {
        type: { type: "string", enum: ["ACTION_REQUIRED", "STAGE_COMPLETE", "ALERT"] },
        skill: { type: "string", description: "Skill name" },
        phase: { type: "string", description: "Phase name" },
        slug: { type: "string", description: "Task slug" },
        title: { type: "string", description: "Notification title" },
        body: { type: "string", description: "Notification body" },
      },
      required: ["type", "skill", "title"],
    },
    async execute(_toolCallId, params) {
      const { type, skill, phase, slug, title, body } = params as any;

      // Build the text notification
      const emoji = type === "ACTION_REQUIRED" ? "⏸" : type === "STAGE_COMPLETE" ? "✅" : "⚠️";
      const message = `${emoji} ${type} — ${skill}${phase ? ` / ${phase}` : ""}: ${title}${body ? `\n${body}` : ""}`;

      return {
        content: [{ type: "text", text: `Notification sent: ${message}` }],
      };
    },
  });
}
```

**Further extension:** When `pi-intercom` is installed, notifications can be sent through intercom to the parent session.

### 8.2. `.pi/yoke-context.md` instead of `.claude/yoke-context.md`

The `yoke-context-generator` agent and the `bootstrap` SKILL.md are updated:

- Path: `.pi/yoke-context.md` instead of `.claude/yoke-context.md`
- Project rules: `AGENTS.md` instead of `CLAUDE.md`
- Bootstrap generates `AGENTS.md` instead of `CLAUDE.md`

### 8.3. `reference/hooks-patterns.md` → `reference/pi-extensions.md`

The `bootstrap/reference/hooks-patterns.md` file is rewritten for pi extensions:

```markdown
# Pi Extensions for yoke

## Notification extension

yoke-pi ships a `yoke_notify` tool that skills call to surface events.

### Integration with pi-intercom

When pi-intercom is installed and a subagent needs to notify the orchestrator:
use `intercom({ action: "send", to: "<target>", message: "..." })`.

### Integration with pi-subagents

Skill SKILL.md files reference subagents by name. pi-subagents discovers agents
from the `agents/` directory and `.pi/agents/` automatically.
```

---

## 9. Phase 6: Documentation and CI

### 9.1. README.md

Full README rework:

- Remove all `/yoke:` prefixes → `/skill:`
- Remove `{CLAUDE_PLUGIN_ROOT}` references
- Add a pi installation section
- Add the list of dependencies (pi-subagents, pi-ask-user, pi-intercom)
- Update command examples
- Update the directory structure

### 9.2. docs/\*.md

Update the 12 skill documentation files:

- `/yoke:<name>` → `/skill:<name>`
- Agent tool → subagent()
- AskUserQuestion → ask_user()
- Official model names
- pi command examples

### 9.3. CI / validation

`scripts/validate.ts`:

```typescript
// Check:
// 1. All SKILL.md files have valid frontmatter (name, description)
// 2. All agents in agents/ have valid pi-subagents frontmatter
// 3. All agents referenced by SKILL.md exist in agents/
// 4. All reference/ files referenced by SKILL.md exist
// 5. package.json is valid
```

### 9.4. Husky + prettier

Carry over from the original: `.husky/pre-commit`, `.prettierrc.json`, `.prettierignore`

---

## 10. Phase 7: Testing and polish

### 10.1. Smoke test for each skill

For each skill — run it in a test project:

| Skill     | Test command                        | Expected result             |
| --------- | ----------------------------------- | --------------------------- |
| hi        | `/skill:hi`                         | Prints the skill list       |
| gst       | `/skill:gst`                        | Shows the repository status |
| gca       | Create a file, `/skill:gca`         | Commit with grouping        |
| gp        | `/skill:gp`                         | Push with report            |
| pr        | `/skill:pr --draft`                 | Creates a draft PR          |
| explore   | `/skill:explore how does auth work` | Exploration with a log      |
| task      | `/skill:task add dark mode`         | task.md file                |
| plan      | `/skill:plan docs/ai/...task.md`    | plan.md file                |
| do        | `/skill:do docs/ai/...plan.md`      | Implementation + report     |
| fix       | `/skill:fix fix validation bug`     | Fix + log                   |
| review    | `/skill:review`                     | review.md file              |
| bootstrap | `/skill:bootstrap`                  | AGENTS.md + context         |

### 10.2. Verification criteria

1. **All agents discovered** — `subagent({ action: "list" })` shows all 37
2. **All skills activate** — `/skill:<name>` works for each
3. **ask_user works** — Q&A is displayed in the TUI
4. **Parallel dispatch works** — bootstrap launches 6 agents at once
5. **Chains work** — do runs review → polish → validate sequentially
6. **Project context is read** — `.pi/yoke-context.md` is read by agents
7. **Notifications are delivered** — `yoke_notify` prints messages

---

## 11. Acceptance criteria

- [ ] All 12 SKILL.md files rewritten for pi
- [ ] All 37 agents rewritten with pi-subagents frontmatter
- [ ] `pi install npm:yoke-pi` installs without errors
- [ ] `pi --skill-dir ./skills` loads all skills
- [ ] `subagent({ action: "list" })` shows 37 agents
- [ ] Each skill tested in pi dev
- [ ] README.md updated
- [ ] docs/\*.md updated
- [ ] CI (format:check + validate) passes
- [ ] No references to Claude Code, `${CLAUDE_PLUGIN_ROOT}`, `$ARGUMENTS`, `AskUserQuestion`, `Agent tool`

---

## 12. Risks

| Risk                                                         | Likelihood | Impact | Mitigation                                                               |
| ------------------------------------------------------------ | ---------- | ------ | ------------------------------------------------------------------------ |
| pi-subagents doesn't support the required model              | Low        | Medium | Use fallbackModels in the frontmatter                                    |
| ask_user doesn't work in non-interactive mode                | Low        | Low    | There is a fallback (text output)                                        |
| Parallel dispatch doesn't work as expected                   | Medium     | High   | Test concurrency; fall back to sequential dispatch on problems           |
| Agents aren't reachable by name, only by path                | Low        | Medium | Verify discovery: `subagent({ action: "list" })`                         |
| `{{PLACEHOLDER}}` templates get lost when passed via `task:` | Medium     | Medium | Test passing long context; on problems — write to a temp file + `reads:` |
| `.pi/agents/` isn't picked up from the npm package           | Medium     | High   | Verify pi package discovery; on problems — install agents manually       |
| yoke-pi conflicts with pi-subagents builtin agents           | Low        | Medium | Verify name uniqueness; on conflicts — add a `yoke-` prefix              |

---

## 13. Effort estimate

### By phase

| Phase     | Description                    | Estimate       |
| --------- | ------------------------------ | -------------- |
| 0         | Repository preparation         | 0.5 days       |
| 1         | Infrastructure and packages    | 0.5 days       |
| 2         | Agents (37 files)              | 2-3 days       |
| 3         | SKILL.md — simple (6 of them)  | 1-2 days       |
| 4         | SKILL.md — medium (1 of them)  | 1 day          |
| 5         | SKILL.md — complex (5 of them) | 3-4 days       |
| 5         | Extensions and notifications   | 1 day          |
| 6         | Documentation and CI           | 1 day          |
| 7         | Testing and polish             | 2-3 days       |
| **Total** |                                | **12-16 days** |

### By file type

| Type                                | Count     | Estimate                                              |
| ----------------------------------- | --------- | ----------------------------------------------------- |
| Agents (agents/\*.md)               | 37 files  | 2-3 days (mechanical frontmatter swap + body cleanup) |
| SKILL.md                            | 12 files  | 4-6 days (rewriting orchestration logic)              |
| Extensions (extensions/\*.ts)       | 1 file    | 0.5 days                                              |
| Scripts (scripts/\*.ts)             | 1 file    | 0.5 days                                              |
| package.json, AGENTS.md, .gitignore | 3 files   | 0.5 days                                              |
| README.md                           | 1 file    | 0.5 days                                              |
| docs/\*.md                          | 12 files  | 1 day                                                 |
| reference/ (modification)           | ~5 files  | 0.5 days                                              |
| **Total**                           | ~72 files | **12-16 days**                                        |

---

## Appendix A: Full migration file list

### Remove (Claude Code-specific)

```
.claude-plugin/plugin.json
.claude-plugin/marketplace.json
.claude/settings.json
.claude/skills/yoke-create/SKILL.md
.claude/skills/yoke-release/SKILL.md
hooks/hooks.json
hooks/notify.sh
lib/notify.sh
commands/                        # (empty directory)
CLAUDE.md
```

### Create from scratch

```
package.json                      # npm package yoke-pi with pi config
AGENTS.md                         # Instructions for pi
.gitignore                        # Updated
.pi/settings.json                 # (for local development, not in the package)
extensions/yoke-notify.ts         # Pi extension for notifications
scripts/validate.ts               # Package validation
```

### Rewrite fully (37 agents)

```
agents/stack-detector.md
agents/architecture-mapper.md
agents/convention-scanner.md
agents/validation-scanner.md
agents/existing-rules-detector.md
agents/domain-analyzer.md
agents/project-md-generator.md       # formerly claude-md-generator.md
agents/yoke-context-generator.md
agents/automation-recommender.md
agents/bootstrap-verifier.md
agents/task-executor.md
agents/spec-reviewer.md
agents/quality-reviewer.md
agents/code-polisher.md
agents/validator.md
agents/formatter.md
agents/doc-updater.md
agents/report-writer.md
agents/explore-agent.md
agents/explore-log-writer.md
agents/fix-context-collector.md
agents/fix-investigator.md
agents/fix-log-writer.md
agents/git-data-collector.md
agents/git-pre-checker.md
agents/git-pusher.md
agents/plan-explorer.md
agents/plan-designer.md
agents/plan-reviewer.md
agents/pr-data-collector.md
agents/pr-body-generator.md
agents/code-reviewer.md
agents/issue-fixer.md
agents/single-fix-agent.md
agents/review-report-writer.md
agents/task-explorer.md
agents/task-architect.md
```

### Rewrite fully (12 SKILL.md)

```
skills/bootstrap/SKILL.md
skills/do/SKILL.md
skills/explore/SKILL.md
skills/fix/SKILL.md
skills/gca/SKILL.md
skills/gp/SKILL.md
skills/gst/SKILL.md
skills/hi/SKILL.md
skills/plan/SKILL.md
skills/pr/SKILL.md
skills/review/SKILL.md
skills/task/SKILL.md
```

### Carry over with modifications (reference/)

```
skills/bootstrap/reference/project-md-template.md     # formerly claude-md-template.md
skills/bootstrap/reference/hooks-patterns.md          # rewrite substantially → pi-extensions.md
skills/bootstrap/reference/mcp-servers.md             # leave as-is
skills/bootstrap/reference/quality-criteria.md        # leave as-is
skills/bootstrap/reference/update-guidelines.md       # leave as-is
skills/do/reference/status-protocol.md                # remove TodoWrite
skills/do/reference/report-format.md                 # leave as-is
skills/explore/reference/exploration-log-format.md   # leave as-is
skills/fix/reference/fix-log-format.md               # leave as-is
skills/gca/reference/commit-convention.md            # leave as-is
skills/gca/reference/staging-strategy.md             # leave as-is
skills/plan/examples/simple-plan.md                   # leave as-is
skills/plan/examples/complex-plan.md                 # leave as-is
skills/plan/reference/elements-of-style-rules.md     # leave as-is
skills/plan/reference/plan-format.md                  # leave as-is
skills/plan/reference/routing-rules.md               # leave as-is
skills/pr/reference/pr-body-format.md                # leave as-is
skills/review/reference/review-format.md             # leave as-is
skills/task/examples/simple-task.md                   # leave as-is
skills/task/examples/complex-task.md                 # leave as-is
skills/task/reference/elements-of-style-rules.md     # leave as-is
skills/task/reference/frontend-guide.md              # leave as-is
skills/task/reference/synthesize-guide.md            # leave as-is
```

### Rewrite (documentation)

```
README.md
docs/task.md
docs/plan.md
docs/do.md
docs/review.md
docs/gca.md
docs/gp.md
docs/pr.md
docs/gst.md
docs/fix.md
docs/explore.md
docs/bootstrap.md
docs/hi.md
docs/notify.md
```

## Appendix B: Installing yoke-pi as an end user

```bash
# 1. Install yoke-pi as a pi package
pi install npm:yoke-pi

# Or from git:
pi install git:yokeloop/yoke-pi

# 2. Install dependencies
pi install npm:pi-subagents
pi install npm:pi-ask-user
pi install npm:pi-intercom

# 3. (Optional) Install web access
pi install npm:pi-web-access

# 4. Run
cd my-project
pi

# 5. Use
> /skill:hi           # skill overview
> /skill:bootstrap    # prepare the project
> /skill:task ...     # define a task
> /skill:plan ...     # build a plan
> /skill:do ...       # execute the plan
```

## Appendix C: pi-subagents frontmatter reference

```yaml
---
name: my-agent # 1-64 characters, kebab-case
description: What this agent does # Up to 1024 characters
tools: read, write, edit, bash, find, grep, ls
model: anthropic/claude-sonnet-4 # Model
fallbackModels: # Fallback models
  - openai/gpt-5-mini
  - anthropic/claude-haiku-4-5
thinking: high # off, minimal, low, medium, high, xhigh
systemPromptMode: replace # replace (default) or append
inheritProjectContext: true # Inherit AGENTS.md, .pi/settings
inheritSkills: false # Inherit the skills directory
skills: ask-user # Inject skills (with +)
output: context.md # Default output file
defaultReads: context.md # Files to read before starting
defaultProgress: true # Maintain progress.md
maxSubagentDepth: 1 # Subagent nesting limit
---
The agent's system prompt...
```

## Appendix D: ask_user API reference

```json
{
  "question": "Which option?",
  "context": "Short summary of findings",
  "options": [
    { "title": "Option A", "description": "Faster but less extensible" },
    { "title": "Option B", "description": "More effort, cleaner long-term" }
  ],
  "allowMultiple": false,
  "allowFreeform": true,
  "allowComment": false,
  "timeout": null
}
```

Response:

```json
{ "kind": "selection", "selections": ["Option A"], "comment": null }
```

or

```json
{ "kind": "freeform", "text": "Custom answer..." }
```

or

```json
null // The user cancelled
```

## Appendix E: subagent() API reference

```typescript
// Single agent
subagent({ agent: "stack-detector", task: "Detect the tech stack" });

// With model selection
subagent({ agent: "task-executor", task: "...", model: "anthropic/claude-opus-4" });

// Parallel
subagent({
  tasks: [
    { agent: "stack-detector", task: "Detect stack" },
    { agent: "architecture-mapper", task: "Map architecture" },
  ],
  concurrency: 2,
});

// Chain
subagent({
  chain: [
    { agent: "task-executor", task: "Implement: ..." },
    { agent: "spec-reviewer", task: "Review spec from {previous}" },
    { agent: "validator", task: "Validate from {previous}" },
  ],
});

// Async
subagent({ agent: "worker", task: "...", async: true });

// Fork context
subagent({ agent: "oracle", task: "Review direction", context: "fork" });

// Management
subagent({ action: "list" });
subagent({ action: "status" });
subagent({ action: "interrupt", id: "abc123" });
subagent({ action: "doctor" });
```
