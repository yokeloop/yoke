# Adapting yoke for pi dev — full research

> Date: 2026-04-27  
> yoke version: 1.0.0

## Contents

1. [Overview of the yoke architecture](#1-overview-of-the-yoke-architecture)
2. [Critical incompatibilities with pi](#2-critical-incompatibilities-with-pi)
3. [pi plugins that solve the core problems](#3-pi-plugins-that-solve-the-core-problems)
4. [Detailed Claude Code → Pi mapping](#4-detailed-claude-code--pi-mapping)
5. [Adapting each skill](#5-adapting-each-skill)
6. [Residual problems not solved by plugins](#6-residual-problems-not-solved-by-plugins)
7. [Strategy: universal skills for both platforms](#7-strategy-universal-skills-for-both-platforms)
8. [Implementation plan](#8-implementation-plan)
9. [List of files to change](#9-list-of-files-to-change)
10. [Appendices](#appendices)

---

## 1. Overview of the yoke architecture

Yoke is a set of 12 skills for Claude Code, organized around the "orchestrator → agents" pattern:

```
skills/
  bootstrap/SKILL.md          # Prepare a project for the yoke flow
  do/SKILL.md                 # Execute a task per the plan
  explore/SKILL.md             # Explore the codebase
  fix/SKILL.md                 # Quick fix
  gca/SKILL.md                 # Git commit with smart grouping
  gp/SKILL.md                  # Git push with checks
  gst/SKILL.md                 # Development status
  hi/SKILL.md                  # Greeting and skills overview
  plan/SKILL.md                # Build an implementation plan
  pr/SKILL.md                  # Create/update a Pull Request
  review/SKILL.md              # Code review with auto-fixes
  task/SKILL.md                # Frame a task for AI

  Each skill:
  ├── SKILL.md                 # Orchestrator (frontmatter + instructions)
  ├── agents/                  # Sub-agents (dispatched via the Agent tool)
  ├── reference/               # Reference material
  └── examples/                # Examples (not in all of them)
```

### Key concepts

| Concept                      | Description                            | Frequency            |
| ---------------------------- | -------------------------------------- | -------------------- |
| **Agent tool**               | Dispatch a sub-agent from SKILL.md     | 30 agents, 50+ calls |
| **AskUserQuestion**          | Interactive Q&A with the user          | 6 skills, 15+ calls  |
| **$ARGUMENTS**               | Auto-substitution of command arguments | 9 skills, 20+ calls  |
| **${CLAUDE_PLUGIN_ROOT}**    | Path to the plugin root                | 6 skills, 20+ calls  |
| **{{PLACEHOLDER}}**          | Template variables in agent prompts    | 126 occurrences      |
| **TodoWrite**                | Phase progress tracking                | 5 skills, 15+ calls  |
| **model: opus/sonnet/haiku** | Model selection in agent frontmatter   | All 30 agents        |
| **tools: Read, Write...**    | Restricting an agent's tools           | All 30 agents        |
| **color:**                   | Agent color label                      | All 30 agents        |
| **notify.sh**                | Notifications via Telegram             | 3 skills, hooks/     |

### Agent catalog (30 of them)

| Skill                | Agents                                                                                                                                                                                                         |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bootstrap (10)       | stack-detector, architecture-mapper, convention-scanner, validation-scanner, existing-rules-detector, domain-analyzer, claude-md-generator, yoke-context-generator, automation-recommender, bootstrap-verifier |
| do (8)               | task-executor, spec-reviewer, quality-reviewer, code-polisher, validator, formatter, doc-updater, report-writer                                                                                                |
| explore (2)          | explore-agent, explore-log-writer                                                                                                                                                                              |
| fix (3 + 3 cross)    | fix-context-collector, fix-investigator, fix-log-writer; + task-executor, code-polisher, validator from do                                                                                                     |
| gca (0)              | — (the orchestrator works directly)                                                                                                                                                                            |
| gp (2)               | git-pre-checker, git-pusher                                                                                                                                                                                    |
| gst (1)              | git-data-collector                                                                                                                                                                                             |
| plan (3)             | plan-explorer, plan-designer, plan-reviewer                                                                                                                                                                    |
| pr (2)               | pr-data-collector, pr-body-generator                                                                                                                                                                           |
| review (4 + 2 cross) | code-reviewer, issue-fixer, single-fix-agent, review-report-writer; + validator, formatter from do                                                                                                             |
| task (2)             | task-explorer, task-architect                                                                                                                                                                                  |

---

## 2. Critical incompatibilities with pi

### 2.1. Agent tool — the main barrier

In every complex skill, the orchestrator dispatches work to agents via the `Agent tool`. Pi **has no built-in Agent tool**.

**Example from do/SKILL.md:**

```
Dispatch via the Agent tool (model: sonnet). The agent file is already read in Init.
```

**Example from bootstrap/SKILL.md:**

```
Dispatch 6 agents in parallel via the Agent tool (6 calls at once):
- stack-detector → agents/stack-detector.md
- architecture-mapper → agents/architecture-mapper.md
...
```

### 2.2. AskUserQuestion — interactive decisions

Orchestrators get decisions from the user via `AskUserQuestion`:

```
AskUserQuestion with 3 options:
1. Add exception .claude/yoke-context.md to .gitignore
2. Commit only CLAUDE.md
3. Cancel
```

Pi has no `AskUserQuestion`.

### 2.3. $ARGUMENTS — command arguments

Claude Code automatically substitutes `$ARGUMENTS` into the context. Pi passes arguments as the text after `/skill:name`.

### 2.4. ${CLAUDE_PLUGIN_ROOT} — paths to the root

```
${CLAUDE_PLUGIN_ROOT}/skills/do/agents/task-executor.md
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE ...
```

Pi does not provide this variable and does not use a plugin-style directory structure for agents.

### 2.5. {{PLACEHOLDER}} — templates in prompts

The orchestrator substitutes data before dispatch:

```yaml
TASK_WHAT: { { TASK_WHAT } }
TASK_HOW: { { TASK_HOW } }
PROJECT_PROFILE: { { PROJECT_PROFILE } }
```

126 occurrences. Pi-subagents does not support templates — `task:` is just a string.

### 2.6. TodoWrite — phase tracking

```markdown
Mark in TodoWrite: [x] Detect
Mark in TodoWrite: [x] Execute
```

Pi has no TodoWrite. Alternative: markdown checklists or the built-in progress of pi-subagents.

### 2.7. Agent frontmatter — different formats

| Field                   | Claude Code               | Pi (pi-subagents)                                                                    |
| ----------------------- | ------------------------- | ------------------------------------------------------------------------------------ |
| `tools`                 | `Glob, Grep, Read, Bash`  | `find, grep, read, bash, ls`                                                         |
| `model`                 | `opus`, `sonnet`, `haiku` | `anthropic/claude-opus-4`, `anthropic/claude-sonnet-4`, `anthropic/claude-haiku-4-5` |
| `color`                 | `blue`, `cyan`, etc.      | None (Pi ignores it)                                                                 |
| `systemPromptMode`      | None                      | `replace` / `append`                                                                 |
| `inheritProjectContext` | None                      | `true` / `false`                                                                     |
| `inheritSkills`         | None                      | `true` / `false`                                                                     |
| `output`                | None                      | `context.md`                                                                         |
| `defaultProgress`       | None                      | `true`                                                                               |

### 2.8. Built-in tool names

| Claude Code    | Pi            | Note               |
| -------------- | ------------- | ------------------ |
| `Read`         | `read`        | —                  |
| `Write`        | `write`       | —                  |
| `Edit`         | `edit`        | —                  |
| `Bash`         | `bash`        | —                  |
| `Glob`         | `find` / `ls` | Pi has no Glob     |
| `Grep`         | `grep`        | —                  |
| `LS`           | `ls`          | —                  |
| `TodoWrite`    | —             | Remove             |
| `NotebookRead` | —             | Or `pi-docparser`  |
| `WebFetch`     | —             | Or `pi-web-access` |
| `WebSearch`    | —             | Or `pi-web-access` |
| `KillShell`    | —             | No equivalent      |
| `BashOutput`   | —             | No equivalent      |

### 2.9. Project context

| Aspect         | Claude Code                          | Pi                                   |
| -------------- | ------------------------------------ | ------------------------------------ |
| Context file   | `.claude/yoke-context.md`            | `.pi/yoke-context.md` or `AGENTS.md` |
| Project rules  | `CLAUDE.md`                          | `AGENTS.md` or `.pi/settings.json`   |
| Path to plugin | `${CLAUDE_PLUGIN_ROOT}`              | Relative path                        |
| Arguments      | `$ARGUMENTS`                         | Text after `/skill:name`             |
| Notifications  | `hooks/hooks.json` + `lib/notify.sh` | pi extension events                  |

---

## 3. pi plugins that solve the core problems

### 3.1. pi-subagents (v0.19.3) — replacement for the Agent tool

**Install:** `pi install npm:pi-subagents`

**Capabilities:**

- Single dispatch: `subagent({ agent: "stack-detector", task: "..." })`
- Parallel: `subagent({ tasks: [{ agent: "scout", task: "..." }, ...], concurrency: 6 })`
- Chains: `subagent({ chain: [{ agent: "scout", task: "..." }, { agent: "planner" }, ...] })`
- Async/background: `subagent({ agent: "worker", task: "...", async: true })`
- Fork context: `subagent({ agent: "oracle", task: "...", context: "fork" })`
- Model selection: in agent frontmatter (`model: anthropic/claude-sonnet-4`)
- Model override: `/run reviewer[model=anthropic/claude-sonnet-4]`
- Worktrees for parallel writes: `worktree: true`
- Agent management: `subagent({ action: "list" })`, create, update, delete
- `/agents` — interactive TUI manager
- `/run`, `/chain`, `/parallel` — slash commands

**Agent format:**

```yaml
---
name: my-agent
description: What this agent does
model: anthropic/claude-sonnet-4
systemPromptMode: replace
inheritProjectContext: true
inheritSkills: false
tools: read, write, edit, bash, find, grep, ls
output: context.md
defaultProgress: true
---
System prompt body...
```

**Agent discovery:**

- `~/.pi/agent/agents/*.md` — global
- `.pi/agents/*.md` — project-level
- `.agents/*.md` — legacy (compatibility)
- `~/.pi/agent/extensions/subagent/agents/` — built-in

**yoke → pi-subagents mapping:**

| yoke                                | pi-subagents                                 |
| ----------------------------------- | -------------------------------------------- |
| `Dispatch agent via the Agent tool` | `subagent({ agent: "...", task: "..." })`    |
| `Dispatch 6 agents in parallel`     | `subagent({ tasks: [...], concurrency: 6 })` |
| `model: opus`                       | `model: anthropic/claude-opus-4`             |
| `model: sonnet`                     | `model: anthropic/claude-sonnet-4`           |
| `model: haiku`                      | `model: anthropic/claude-haiku-4-5`          |
| `tools: Read, Write, Edit, Bash`    | `tools: read, write, edit, bash`             |
| `tools: Glob, Grep`                 | `tools: find, grep`                          |
| `tools: LS`                         | `tools: ls`                                  |

### 3.2. pi-ask-user (v0.6.1) — replacement for AskUserQuestion

**Install:** `pi install npm:pi-ask-user`

**Capabilities:**

- Interactive TUI with search, split-pane preview
- Single-select and multi-select
- Freeform input
- Optional comment after selection
- Overlay mode
- Timeout (auto-close)
- Fallback in RPC/headless mode (via `ctx.ui.select()`)
- Bundles the `ask-user` skill with a decision-gate pattern

**Mapping example:**

```markdown
# Claude Code

AskUserQuestion with 3 options:

1. Add exception
2. Commit only
3. Cancel

# Pi

ask_user({
question: "How should we handle yoke-context.md in git?",
context: "CLAUDE.md and yoke-context.md have been generated.",
options: [
{ title: "Add .claude/yoke-context.md exception to .gitignore", description: "Commit both files" },
{ title: "Commit only CLAUDE.md", description: "Skip yoke-context" },
{ title: "Cancel", description: "Don't commit anything" }
],
allowFreeform: true
})
```

### 3.3. pi-intercom (v0.2.1) — coordination and notifications

**Install:** `pi install npm:pi-intercom`

**Capabilities:**

- 1:1 messaging between pi sessions
- `intercom({ action: "send", to: "worker", message: "..." })` — send
- `intercom({ action: "ask", to: "planner", message: "..." })` — blocking question
- Integration with pi-subagents for needs-attention notifications
- `/intercom` or Alt+M — TUI

**Replacement for notify.sh:**
Instead of `bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE ...` you can:

- For orchestrator ↔ agent coordination: `intercom({ action: "send", message: "..." })`
- For UI notifications to the user: `ctx.ui.notify()` (in a pi extension)

### 3.4. Optional plugins

| Package                    | Replaces                            | Install                                   |
| -------------------------- | ----------------------------------- | ----------------------------------------- |
| `pi-web-access`            | `WebFetch`, `WebSearch`             | `pi install npm:pi-web-access`            |
| `pi-docparser`             | `NotebookRead` (PDF/Office)         | `pi install npm:pi-docparser`             |
| `pi-lens`                  | Manual bash checks in the validator | `pi install npm:pi-lens`                  |
| `pi-prompt-template-model` | Reusable prompt templates           | `pi install npm:pi-prompt-template-model` |

---

## 4. Detailed Claude Code → Pi mapping

### 4.1. Agent tool → subagent()

```markdown
# Claude Code

Dispatch via the Agent tool:

- Agent: `${CLAUDE_PLUGIN_ROOT}/skills/gst/agents/git-data-collector.md`
- Prompt: "Collect data on the current git repository state and produce a report"

# Pi

subagent({
agent: "git-data-collector",
task: "Collect data on the current git repository state and produce a report"
})
```

### 4.2. Parallel dispatch

```markdown
# Claude Code

Dispatch 6 agents **in parallel** via the Agent tool (6 calls at once):

1. stack-detector → agents/stack-detector.md
2. architecture-mapper → agents/architecture-mapper.md
   ...

# Pi

subagent({
tasks: [
{ agent: "stack-detector", task: "Detect the tech stack..." },
{ agent: "architecture-mapper", task: "Map the architecture..." },
{ agent: "convention-scanner", task: "Scan conventions..." },
{ agent: "validation-scanner", task: "Scan validation..." },
{ agent: "existing-rules-detector", task: "Detect existing rules..." },
{ agent: "domain-analyzer", task: "Analyze the domain..." }
],
concurrency: 6
})
```

### 4.3. Sequential chain

```markdown
# Claude Code (manual dispatch in SKILL.md)

1. Run task-executor → agents/task-executor.md
2. Then spec-reviewer → agents/spec-reviewer.md
3. Then quality-reviewer → agents/quality-reviewer.md
   ...

# Pi

subagent({
chain: [
{ agent: "task-executor", task: "Implement: ..." },
{ agent: "spec-reviewer", task: "Review spec compliance from {previous}" },
{ agent: "quality-reviewer", task: "Review quality from {previous}" },
{ agent: "code-polisher", task: "Polish code from {previous}" },
{ agent: "validator", task: "Run validation from {previous}" },
{ agent: "doc-updater", task: "Update docs from {previous}" },
{ agent: "formatter", task: "Format from {previous}" },
{ agent: "report-writer", task: "Write report from {previous}" }
]
})
```

### 4.4. AskUserQuestion → ask_user()

```markdown
# Claude Code

AskUserQuestion with 3 options:

1. Add exception `.claude/yoke-context.md` to .gitignore
2. Commit only `CLAUDE.md`
3. Cancel

# Pi

ask_user({
question: "How should we handle the generated files?",
context: "CLAUDE.md and yoke-context.md have been created. .claude/ may be in .gitignore.",
options: [
{ title: "Add .claude/yoke-context.md exception", description: "Commit both files" },
{ title: "Commit only CLAUDE.md", description: "Skip yoke-context" },
{ title: "Cancel", description: "Don't commit anything" }
],
allowFreeform: true
})
```

### 4.5. $ARGUMENTS → prompt arguments

```markdown
# Claude Code

$ARGUMENTS — path to a task file, e.g. `docs/ai/86-black-jack-page/86-black-jack-page-task.md`

# Pi

The user's input follows the skill invocation. For `/skill:plan`, the argument
is the path to a task file, e.g. `docs/ai/86-black-jack-page/86-black-jack-page-task.md`.
If the argument is missing — ask via ask_user.
```

### 4.6. CLAUDE_PLUGIN_ROOT → agent names / relative paths

```markdown
# Claude Code

- Implementation → `${CLAUDE_PLUGIN_ROOT}/skills/do/agents/task-executor.md`

# Pi

- Implementation → subagent({ agent: "task-executor", task: "..." })

# For reference/ files in SKILL.md — relative paths work in both environments:

See [commit convention](reference/commit-convention.md) for details.
```

### 4.7. {{PLACEHOLDER}} templates

Pi-subagents does not substitute templates. Two approaches:

**Approach A: Context via the task: string**

```markdown
subagent({
agent: "task-executor",
task: `Implement the following task:

What: ${TASK_WHAT}

How: ${TASK_HOW}

Files to create/change: ${TASK_FILES}

Verify: ${TASK_VERIFY}`
})
```

**Approach B: Context via a reads: file**

```markdown
# The orchestrator writes a temporary context file

# then:

subagent({
agent: "task-executor",
task: "Execute the task per context file",
reads: "context.md"
})
```

### 4.8. TodoWrite → markdown checklists

```markdown
# Claude Code

Mark in TodoWrite: [x] Detect
Mark in TodoWrite: [x] Execute

# Pi: just text in SKILL.md

Progress checklist (update as you complete each phase):

- [ ] Detect
- [ ] Execute
- [ ] Generate
- [ ] Verify
```

Or use the built-in progress of pi-subagents (`defaultProgress: true`).

### 4.9. Notifications (notify.sh) → pi extension

```markdown
# Claude Code

bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type ACTION_REQUIRED --skill bootstrap --phase Confirm --slug "bootstrap" --title "Bootstrap ready" --body "CLAUDE.md and yoke-context.md created"

# Pi: via ctx.ui.notify() in an extension

ctx.ui.notify("Bootstrap ready: CLAUDE.md and yoke-context.md created", "success");

# Pi: via intercom (for orchestrator ↔ agent coordination)

intercom({ action: "send", to: "parent", message: "Bootstrap phase Complete done" })
```

### 4.10. hooks/hooks.json → pi extension

```json
// Claude Code: hooks/hooks.json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/notify.sh",
        "timeout": 10,
        "allowedEnvVars": ["CC_TELEGRAM_BOT_TOKEN", "CC_TELEGRAM_CHAT_ID"]
      }]
    }]
  }
}

// Pi: extension event
pi.on("session_shutdown", async (event, ctx) => {
  // Check for pending notification and send to Telegram
  // Or use ctx.ui.notify() for in-TUI notifications
});
```

---

## 5. Adapting each skill

### 5.1. hi — 🟢 Easy

No agents, no `$ARGUMENTS`, no `AskUserQuestion`. Almost pure text.

**Changes:**

- Update command prefixes: `/yoke:task` → `/skill:task`
- In the pi context, remove references to `/yoke:`

### 5.2. gca — 🟡 Medium

No agents. Has `$ARGUMENTS`, `AskUserQuestion`, and `reference/`.

**Changes:**

- `$ARGUMENTS` → instruction about arguments
- `AskUserQuestion` → `ask_user()`
- `reference/` — leave as is (relative paths)

### 5.3. gst — 🟡 Medium

1 agent (`git-data-collector`).

**Changes:**

- `Agent tool` → `subagent({ agent: "git-data-collector", task: "..." })`
- `${CLAUDE_PLUGIN_ROOT}/skills/gst/agents/git-data-collector.md` → agent name `git-data-collector`

### 5.4. explore — 🟡 Medium

2 agents, `AskUserQuestion`, `$ARGUMENTS`.

**Changes:**

- 2 agents → `subagent()`
- `AskUserQuestion` → `ask_user()`
- `$ARGUMENTS` → instruction

### 5.5. gp — 🟡 Medium

2 agents.

**Changes:**

- 2 agents → `subagent()`
- `${CLAUDE_PLUGIN_ROOT}` → agent names

### 5.6. pr — 🟡 Medium

2 agents, `AskUserQuestion`, `$ARGUMENTS`.

**Changes:**

- 2 agents → `subagent()`
- `AskUserQuestion` → `ask_user()`
- `${CLAUDE_PLUGIN_ROOT}` → agent names

### 5.7. task — 🟡 Medium

2 agents, `KillShell`, `BashOutput`, `WebSearch`, `WebFetch` in the frontmatter.

**Changes:**

- 2 agents → `subagent()`
- Remove `KillShell`, `BashOutput`, `WebSearch`, `WebFetch` from tools
- Or add `pi-web-access` as a dependency

### 5.8. plan — 🔴 High

3 agents, `KillShell`, `BashOutput` in the frontmatter, `{{PLACEHOLDER}}`.

**Changes:**

- 3 agents → `subagent({ chain: [...] })`
- Remove `KillShell`, `BashOutput`
- Templates → context via `task:` or `reads:`

### 5.9. bootstrap — 🔴 High

10 agents, parallel dispatch, `{{PLACEHOLDER}}`, `TodoWrite`, `AskUserQuestion`, `.claude/`.

**Changes:**

- Parallel dispatch → `subagent({ tasks: [...], concurrency: 6 })`
- `{{PLACEHOLDER}}` → context via the `task:` string
- `TodoWrite` → markdown checklist
- `AskUserQuestion` → `ask_user()`
- `.claude/` → `.pi/`
- `${CLAUDE_PLUGIN_ROOT}` → agent names
- `notify.sh` → pi-integration

### 5.10. do — 🔴 High

8 agents, sequential and parallel phases, review loop, model routing.

**Changes:**

- Sequential phases → `subagent({ chain: [...] })`
- Parallel `task-executor` → `subagent({ tasks: [...], concurrency: N })`
- `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md` → the agent reads the file directly
- `TodoWrite` → remove
- `notify.sh` → pi-intercom / ctx.ui.notify()

### 5.11. fix — 🔴 High

3 own + 3 cross-skill agents, `AskUserQuestion`, `CLAUDE_PLUGIN_ROOT`, escalation to opus.

**Changes:**

- 6 agents → `subagent()` by name (no paths)
- `AskUserQuestion` → `ask_user()`
- Model routing → `model: anthropic/claude-opus-4` in the agent frontmatter
- `notify.sh` → pi-intercom

### 5.12. review — 🔴 High

4 own + 2 cross-skill agents, parallel fix agents.

**Changes:**

- 6 agents → `subagent()` by name
- Parallel fix → `subagent({ tasks: [...] })`
- `${CLAUDE_PLUGIN_ROOT}` → agent names

---

## 6. Residual problems not solved by plugins

### 6.1. TodoWrite

**Problem:** 15+ calls across 5 skills.

**Solution:** Replace with markdown checklists or rely on the built-in progress of pi-subagents (`defaultProgress: true`). Not critical — it is cosmetic tracking.

### 6.2. `.claude/yoke-context.md` → `.pi/`

**Problem:** Bootstrap generates `.claude/yoke-context.md`. Pi expects `.pi/`.

**Solution:** Specify both paths in the universal SKILL.md. For Pi — generate into `.pi/yoke-context.md`.

### 6.3. Notifications

**Problem:** `hooks/hooks.json` + `lib/notify.sh` + `hooks/notify.sh` are Claude Code hooks.

**Solution:** Write a mini-extension `pi-yoke-notify.ts` (~50 lines) that:

1. Registers a custom `yoke_notify` tool
2. Sends notifications via the Telegram Bot API
3. Or subscribes to `session_shutdown` to send a summary

### 6.4. NotebookRead

**Problem:** Used in `task-executor.md`.

**Solution:** Remove it from tools (the agent can use `read` for text files). For PDF/Office — add `pi-docparser`.

### 6.5. KillShell, BashOutput

**Problem:** Used in `plan-designer.md`, `plan-explorer.md`, `task-architect.md`, `task-explorer.md`.

**Solution:** Remove them — pi does not have these tools. Agents can be interrupted via the standard pi-subagents mechanism.

---

## 7. Strategy: universal skills for both platforms

### 7.1. Why full unification is impossible

Agents have **fundamentally different** frontmatter formats:

```yaml
# Claude Code
---
name: task-explorer
description: Deeply analyzes the codebase...
tools: Glob, Grep, LS, Read, Bash, WebSearch, WebFetch, TodoWrite
model: sonnet
color: yellow
---
# Pi (pi-subagents)
---
name: task-explorer
description: Deeply analyzes the codebase...
tools: find, grep, ls, read, bash
model: anthropic/claude-sonnet-4
systemPromptMode: replace
inheritProjectContext: true
inheritSkills: false
output: context.md
defaultProgress: true
---
```

You cannot put both formats in a single file.

### 7.2. Recommended strategy: single source of truth

```
yoke/
  agents/                     # Single source of truth — 30 files
    stack-detector.md          # Prompt body + metadata for the generator
    task-executor.md
    ...

  skills/                     # Universal SKILL.md — 12 files
    task/SKILL.md              # Dual-instructions (CC + Pi)
    plan/SKILL.md
    ...
    task/reference/             # References (shared)
      elements-of-style-rules.md
      ...

  scripts/
    build-agents.ts            # Generator: agents/* → agents-cc/* + agents-pi/*

  lib/
    notify.sh                  # CC notifications

  hooks/
    hooks.json                 # CC hooks

  .pi/agents/                  # ← Generated: Pi format
  skills/*/agents/             # ← Generated: CC format

  .pi/settings.json            # Pi package configuration
```

### 7.3. Unified agent format

````yaml
# agents/stack-detector.md

---
# CC frontmatter (generated into skills/*/agents/stack-detector.md)
# cc-tools: Bash, Glob, Read
# cc-model: haiku

# Pi frontmatter (generated into .pi/agents/stack-detector.md)
# pi-tools: bash, find, read, ls
# pi-model: anthropic/claude-haiku-4-5
# pi-systemPromptMode: replace
# pi-inheritProjectContext: true
# pi-inheritSkills: false
# pi-output: context.md
# pi-defaultProgress: true
---

# Stack Detector

Detects the tech stack of the project: languages, frameworks, build tools, package managers.

## Process

1. **Package manifests** — check for `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, etc.
2. **Config files** — check for `.eslintrc`, `tsconfig.json`, `Dockerfile`, `docker-compose.yml`
3. **Lock files** — check for `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
...

## Structured Output

Return the data strictly in this format:

```yaml
LANGUAGES:
  - <language>: <percentage or presence indicator>
  ...
FRAMEWORKS:
  - <framework>: <version if detectable>
  ...
BUILD_TOOLS:
  - <tool>: <config file>
  ...
````

## Rules

- Read-only.
- Command error — record it and continue.
- Return data. The orchestrator makes decisions.

````

### 7.4. Universal SKILL.md template

```markdown
---
name: task
description: >-
  Draft a task file for AI implementation. Triggered when the user writes
  "create a task", "task from ticket", "draft a task", "prepare an implementation
  prompt", or passes a ticket URL / feature description.
---

# Draft a task for AI implementation

You are the orchestrator. Coordinate sub-agents and talk to the user.

Delegate codebase investigation through the available delegation tool:

## Input

The user's input follows the skill invocation. It contains one or both of:
- **Ticket URL** — GitHub Issues, YouTrack, Jira, etc.
- **Task text** — description, code snippets, links

If the input is empty, ask for a description:

<!-- CC: AskUserQuestion -->
<!-- Pi: ask_user({ question: "What task would you like to draft?", allowFreeform: true }) -->

## Delegation

Delegate investigation tasks:

<!-- CC: Dispatch via Agent tool. Read `agents/task-explorer.md` and `agents/task-architect.md`. -->
<!-- Pi: Use subagent({ agent: "task-explorer", task: "..." }) and subagent({ agent: "task-architect", task: "..." }) -->

...

## Project Context

<!-- CC: Read `.claude/yoke-context.md` if it exists. -->
<!-- Pi: Read `.pi/yoke-context.md` or `AGENTS.md` if it exists. -->

...
````

### 7.5. The build-agents.ts script

```typescript
// scripts/build-agents.ts
// Reads yoke/agents/*.md
// For each file:
//   1. Extracts CC/Pi metadata from comments
//   2. Generates the CC format → skills/<parent>/agents/<name>.md
//   3. Generates the Pi format → .pi/agents/<name>.md

import * as fs from "fs";
import * as path from "path";

const AGENTS_DIR = "agents";
const PI_AGENTS_DIR = ".pi/agents";
const CC_SKILLS_DIR = "skills";

// Mapping: agent name → parent skill
const AGENT_TO_SKILL: Record<string, string> = {
  "stack-detector": "bootstrap",
  "architecture-mapper": "bootstrap",
  // ...
  "task-executor": "do",
  // ...
};

// Mapping: CC tool name → Pi tool name
const CC_TO_PI_TOOLS: Record<string, string> = {
  Read: "read",
  Write: "write",
  Edit: "edit",
  Bash: "bash",
  Glob: "find",
  Grep: "grep",
  LS: "ls",
  NotebookRead: "",
  WebFetch: "",
  WebSearch: "",
  TodoWrite: "",
  KillShell: "",
  BashOutput: "",
};

// Mapping: CC model name → Pi model name
const CC_TO_PI_MODEL: Record<string, string> = {
  opus: "anthropic/claude-opus-4",
  sonnet: "anthropic/claude-sonnet-4",
  haiku: "anthropic/claude-haiku-4-5",
};

interface AgentMeta {
  ccTools: string;
  ccModel: string;
  piTools: string;
  piModel: string;
  piSystemPromptMode: string;
  piInheritProjectContext: boolean;
  piInheritSkills: boolean;
  piOutput?: string;
  piDefaultProgress: boolean;
  body: string;
  name: string;
  description: string;
}

function parseAgent(content: string, filename: string): AgentMeta {
  // Extract the frontmatter and body
  // Extract CC/Pi metadata from comments
  // Build AgentMeta
  // ...
}

function generateCC(agent: AgentMeta): string {
  const frontmatter = [
    "---",
    `name: ${agent.name}`,
    `description: ${agent.description}`,
    `tools: ${agent.ccTools}`,
    `model: ${agent.ccModel}`,
    "---",
  ].join("\n");
  return frontmatter + "\n" + agent.body;
}

function generatePi(agent: AgentMeta): string {
  const frontmatter = [
    "---",
    `name: ${agent.name}`,
    `description: ${agent.description}`,
    `tools: ${agent.piTools}`,
    `model: ${agent.piModel}`,
    `systemPromptMode: ${agent.piSystemPromptMode}`,
    `inheritProjectContext: ${agent.piInheritProjectContext}`,
    `inheritSkills: ${agent.piInheritSkills}`,
    agent.piOutput ? `output: ${agent.piOutput}` : "",
    `defaultProgress: ${agent.piDefaultProgress}`,
    "---",
  ]
    .filter(Boolean)
    .join("\n");
  return frontmatter + "\n" + agent.body;
}

// Main
const agents = fs.readdirSync(AGENTS_DIR).filter((f) => f.endsWith(".md"));

for (const file of agents) {
  const content = fs.readFileSync(path.join(AGENTS_DIR, file), "utf-8");
  const agent = parseAgent(content, file);

  // Generate CC
  const skill = AGENT_TO_SKILL[agent.name];
  if (skill) {
    const ccDir = path.join(CC_SKILLS_DIR, skill, "agents");
    fs.mkdirSync(ccDir, { recursive: true });
    fs.writeFileSync(path.join(ccDir, file), generateCC(agent));
  }

  // Generate Pi
  fs.mkdirSync(PI_AGENTS_DIR, { recursive: true });
  fs.writeFileSync(path.join(PI_AGENTS_DIR, file), generatePi(agent));
}
```

---

## 8. Implementation plan

### Phase 1: Infrastructure (1-2 days)

1. Install the plugins:

   ```bash
   pi install npm:pi-subagents
   pi install npm:pi-ask-user
   pi install npm:pi-intercom
   ```

2. Create `.pi/settings.json` with the configuration:

   ```json
   {
     "skills": ["./skills"],
     "subagents": {
       "agentOverrides": {}
     }
   }
   ```

3. Create the `.pi/agents/` directory.

4. Write `scripts/build-agents.ts` — the generator of CC/Pi formats from a single source.

### Phase 2: Simple skills (1-2 days)

Adapt in order of complexity:

1. **hi** — update command prefixes
2. **gca** — `AskUserQuestion` → `ask_user()`, `$ARGUMENTS` → instruction
3. **gst** — `Agent tool` → `subagent()`, 1 agent

### Phase 3: Medium skills (2-3 days)

4. **explore** — 2 agents, `AskUserQuestion`, `$ARGUMENTS`
5. **gp** — 2 agents, `CLAUDE_PLUGIN_ROOT`
6. **pr** — 2 agents, `AskUserQuestion`, `$ARGUMENTS`
7. **task** — 2 agents, remove CC-specific tools

### Phase 4: Complex skills (3-5 days)

8. **plan** — 3 agents, chain, templates
9. **bootstrap** — 10 agents, parallel dispatch, `.claude/` → `.pi/`
10. **do** — 8 agents, chains, review loop
11. **fix** — 6 agents (cross-skill references), `ask_user()`, escalation
12. **review** — 6 agents, parallel fix agents

### Phase 5: Infrastructure (1-2 days)

13. Write the `pi-yoke-notify` extension (~50 lines)
14. Adapt `bootstrap` for `.pi/`
15. Test on both platforms

**Total: ~8-14 days**

---

## 9. List of files to change

### SKILL.md (12 files — rewrite with dual-instructions)

| File                        | Complexity | Key changes                                           |
| --------------------------- | ---------- | ----------------------------------------------------- |
| `skills/hi/SKILL.md`        | 🟢         | Update command prefixes                               |
| `skills/gca/SKILL.md`       | 🟡         | `AskUserQuestion` → `ask_user()`, `$ARGUMENTS`        |
| `skills/gst/SKILL.md`       | 🟡         | `Agent tool` → `subagent()`                           |
| `skills/explore/SKILL.md`   | 🟡         | `Agent`, `AskUserQuestion`, `$ARGUMENTS`              |
| `skills/gp/SKILL.md`        | 🟡         | `Agent`, `CLAUDE_PLUGIN_ROOT`                         |
| `skills/pr/SKILL.md`        | 🟡         | `Agent`, `AskUserQuestion`                            |
| `skills/task/SKILL.md`      | 🟡         | `Agent`, remove CC tools                              |
| `skills/plan/SKILL.md`      | 🔴         | `Agent` chain, templates, CC tools                    |
| `skills/bootstrap/SKILL.md` | 🔴         | Parallel dispatch, `{{PLACEHOLDER}}`, `.claude/`      |
| `skills/do/SKILL.md`        | 🔴         | Chain, review loop, `CLAUDE_PLUGIN_ROOT`, `TodoWrite` |
| `skills/fix/SKILL.md`       | 🔴         | Cross-skill agents, `ask_user()`, model routing       |
| `skills/review/SKILL.md`    | 🔴         | Parallel fix, cross-skill references                  |

### Agents (30 files — adapt frontmatter + content)

| Agent                   | Remove CC tools                                       | CC tools → Pi tools                                                       | CC model → Pi model              |
| ----------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------- | -------------------------------- |
| stack-detector          | —                                                     | Bash→bash, Glob→find, Read→read                                           | haiku→anthropic/claude-haiku-4-5 |
| architecture-mapper     | —                                                     | Glob→find, Grep→grep, Read→read, Bash→bash                                | sonnet→anthropic/claude-sonnet-4 |
| convention-scanner      | —                                                     | Glob→find, Grep→grep, Read→read                                           | sonnet→anthropic/claude-sonnet-4 |
| validation-scanner      | —                                                     | Bash→bash, Glob→read, Read→read                                           | haiku→anthropic/claude-haiku-4-5 |
| existing-rules-detector | —                                                     | Bash→bash, Read→read, Glob→find                                           | haiku→anthropic/claude-haiku-4-5 |
| domain-analyzer         | —                                                     | Glob→find, Grep→grep, Read→read, Bash→bash                                | sonnet→anthropic/claude-sonnet-4 |
| claude-md-generator     | —                                                     | Read→read, Write→write, Edit→edit, Glob→find                              | sonnet→anthropic/claude-sonnet-4 |
| yoke-context-generator  | —                                                     | Read→read, Write→write, Bash→bash, Glob→find                              | haiku→anthropic/claude-haiku-4-5 |
| automation-recommender  | —                                                     | Read→read                                                                 | haiku→anthropic/claude-haiku-4-5 |
| bootstrap-verifier      | —                                                     | Read→read, Bash→bash, Glob→find                                           | sonnet→anthropic/claude-sonnet-4 |
| task-executor           | NotebookRead, WebFetch, TodoWrite                     | Read→read, Write→write, Edit→edit, Bash→bash, Glob→find, Grep→grep, LS→ls | opus→anthropic/claude-opus-4     |
| spec-reviewer           | —                                                     | Read→read, Glob→find, Grep→grep, LS→ls                                    | sonnet→anthropic/claude-sonnet-4 |
| quality-reviewer        | —                                                     | Read→read, Glob→find, Grep→grep, LS→ls, Bash→bash                         | sonnet→anthropic/claude-sonnet-4 |
| code-polisher           | —                                                     | Read→read, Write→write, Edit→edit, Bash→bash, Glob→find, Grep→grep, LS→ls | opus→anthropic/claude-opus-4     |
| validator               | —                                                     | Read→read, Edit→edit, Bash→bash, Glob→find, Grep→grep, LS→ls              | haiku→anthropic/claude-haiku-4-5 |
| formatter               | —                                                     | Read→read, Bash→bash, Glob→find, Grep→grep, LS→ls                         | haiku→anthropic/claude-haiku-4-5 |
| doc-updater             | —                                                     | Read→read, Write→write, Edit→edit, Bash→bash, Glob→find, Grep→grep, LS→ls | sonnet→anthropic/claude-sonnet-4 |
| report-writer           | —                                                     | Read→read, Write→write, Bash→bash, Glob→find, LS→ls                       | haiku→anthropic/claude-haiku-4-5 |
| explore-agent           | WebSearch, WebFetch                                   | Glob→find, Grep→grep, LS→ls, Read→read, Bash→bash                         | sonnet→anthropic/claude-sonnet-4 |
| explore-log-writer      | —                                                     | Read→read, Write→write, Edit→edit, Bash→bash                              | haiku→anthropic/claude-haiku-4-5 |
| fix-context-collector   | —                                                     | Bash→bash, Glob→find, LS→ls                                               | haiku→anthropic/claude-haiku-4-5 |
| fix-investigator        | —                                                     | Glob→find, Grep→grep, LS→ls, Read→read, Bash→bash                         | sonnet→anthropic/claude-sonnet-4 |
| fix-log-writer          | —                                                     | Read→read, Write→write, Edit→edit, Bash→bash                              | haiku→anthropic/claude-haiku-4-5 |
| git-data-collector      | —                                                     | Bash→bash                                                                 | haiku→anthropic/claude-haiku-4-5 |
| git-pre-checker         | —                                                     | Bash→bash                                                                 | haiku→anthropic/claude-haiku-4-5 |
| git-pusher              | —                                                     | Bash→bash                                                                 | haiku→anthropic/claude-haiku-4-5 |
| plan-explorer           | KillShell, BashOutput, WebSearch, WebFetch, TodoWrite | Glob→find, Grep→grep, LS→ls, Read→read                                    | sonnet→anthropic/claude-sonnet-4 |
| plan-designer           | KillShell, BashOutput, WebSearch, WebFetch, TodoWrite | Glob→find, Grep→grep, LS→ls, Read→read                                    | opus→anthropic/claude-opus-4     |
| plan-reviewer           | NotebookRead                                          | Glob→find, Grep→grep, LS→ls, Read→read                                    | sonnet→anthropic/claude-sonnet-4 |
| pr-data-collector       | —                                                     | Bash→bash, Read→read, Glob→find                                           | haiku→anthropic/claude-haiku-4-5 |
| pr-body-generator       | —                                                     | Read→read                                                                 | sonnet→anthropic/claude-sonnet-4 |
| code-reviewer           | —                                                     | Read→read, Bash→bash, Glob→find, Grep→grep                                | sonnet→anthropic/claude-sonnet-4 |
| issue-fixer             | —                                                     | Read→read, Bash→bash, Glob→find, Grep→grep                                | sonnet→anthropic/claude-sonnet-4 |
| single-fix-agent        | —                                                     | Read→read, Edit→edit, Bash→bash, Glob→find, Grep→grep, LS→ls              | opus→anthropic/claude-opus-4     |
| review-report-writer    | —                                                     | Read→read, Write→write, Bash→bash, Glob→find, Grep→grep                   | sonnet→anthropic/claude-sonnet-4 |
| task-explorer           | KillShell, BashOutput, WebSearch, WebFetch, TodoWrite | Glob→find, Grep→grep, LS→ls, Read→read                                    | sonnet→anthropic/claude-sonnet-4 |
| task-architect          | KillShell, BashOutput, WebSearch, WebFetch, TodoWrite | Glob→find, Grep→grep, LS→ls, Read→read                                    | opus→anthropic/claude-opus-4     |

### Infrastructure files

| File                      | Action                                   |
| ------------------------- | ---------------------------------------- |
| `.pi/settings.json`       | Create — package and skill configuration |
| `.pi/agents/*.md`         | Create — 30 Pi agents (generated)        |
| `scripts/build-agents.ts` | Create — generator of CC/Pi formats      |
| `package.json`            | Update — add build scripts               |
| `pi-yoke-notify.ts`       | Create — pi extension for notifications  |
| `skills/*/agents/*.md`    | Update — CC agents (generated)           |

---

## Appendix A: Full agent frontmatter mapping

### All 37 agents (including cross-skill references)

```
Agent                  | CC tools                                    | CC model | Pi tools ( proposed)                    | Pi model
-----------------------|---------------------------------------------|----------|----------------------------------------|----
stack-detector          | Bash, Glob, Read                            | haiku    | bash, find, read, ls                   | anthropic/claude-haiku-4-5
architecture-mapper    | Glob, Grep, Read, Bash                      | sonnet   | find, grep, read, bash, ls             | anthropic/claude-sonnet-4
convention-scanner     | Glob, Grep, Read                            | sonnet   | find, grep, read, ls                  | anthropic/claude-sonnet-4
validation-scanner     | Bash, Glob, Read                            | haiku    | bash, find, read, ls                   | anthropic/claude-haiku-4-5
existing-rules-detector| Bash, Read, Glob                            | haiku    | bash, read, find, ls                  | anthropic/claude-haiku-4-5
domain-analyzer        | Glob, Grep, Read, Bash                     | sonnet   | find, grep, read, bash, ls             | anthropic/claude-sonnet-4
claude-md-generator   | Read, Write, Edit, Glob                    | sonnet   | read, write, edit, find, ls            | anthropic/claude-sonnet-4
yoke-context-generator| Read, Write, Bash, Glob                     | haiku    | read, write, bash, find, ls             | anthropic/claude-haiku-4-5
automation-recommender| Read                                        | haiku    | read                                    | anthropic/claude-haiku-4-5
bootstrap-verifier     | Read, Bash, Glob                            | sonnet   | read, bash, find, ls                   | anthropic/claude-sonnet-4
task-executor          | Read, Write, Edit, Bash, Glob, Grep, LS, NotebookRead, WebFetch, TodoWrite | opus | read, write, edit, bash, find, grep, ls | anthropic/claude-opus-4
spec-reviewer          | Read, Glob, Grep, LS                        | sonnet   | read, find, grep, ls                   | anthropic/claude-sonnet-4
quality-reviewer       | Read, Glob, Grep, LS, Bash                  | sonnet   | read, find, grep, ls, bash             | anthropic/claude-sonnet-4
code-polisher          | Read, Write, Edit, Bash, Glob, Grep, LS     | opus     | read, write, edit, bash, find, grep, ls| anthropic/claude-opus-4
validator              | Read, Edit, Bash, Glob, Grep, LS            | haiku    | read, edit, bash, find, grep, ls       | anthropic/claude-haiku-4-5
formatter              | Read, Bash, Glob, Grep, LS                  | haiku    | read, bash, find, grep, ls             | anthropic/claude-haiku-4-5
doc-updater            | Read, Write, Edit, Bash, Glob, Grep, LS     | sonnet   | read, write, edit, bash, find, grep, ls| anthropic/claude-sonnet-4
report-writer          | Read, Write, Bash, Glob, LS                 | haiku    | read, write, bash, find, ls             | anthropic/claude-haiku-4-5
explore-agent          | Glob, Grep, LS, Read, Bash, WebSearch, WebFetch | sonnet | find, grep, ls, read, bash          | anthropic/claude-sonnet-4
explore-log-writer    | Read, Write, Edit, Bash                     | haiku    | read, write, edit, bash                 | anthropic/claude-haiku-4-5
fix-context-collector  | Bash, Glob, LS                              | haiku    | bash, find, ls                          | anthropic/claude-haiku-4-5
fix-investigator       | Glob, Grep, LS, Read, Bash                 | sonnet   | find, grep, ls, read, bash             | anthropic/claude-sonnet-4
fix-log-writer         | Read, Write, Edit, Bash                     | haiku    | read, write, edit, bash                 | anthropic/claude-haiku-4-5
git-data-collector    | Bash                                        | haiku    | bash                                    | anthropic/claude-haiku-4-5
git-pre-checker       | Bash                                        | haiku    | bash                                    | anthropic/claude-haiku-4-5
git-pusher             | Bash                                        | haiku    | bash                                    | anthropic/claude-haiku-4-5
plan-explorer          | Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, KillShell, BashOutput | sonnet | find, grep, ls, read             | anthropic/claude-sonnet-4
plan-designer          | Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, KillShell, BashOutput | opus | find, grep, ls, read            | anthropic/claude-opus-4
plan-reviewer          | Glob, Grep, LS, Read, NotebookRead          | sonnet   | find, grep, ls, read                   | anthropic/claude-sonnet-4
pr-data-collector     | Bash, Read, Glob                            | haiku    | bash, read, find                        | anthropic/claude-haiku-4-5
pr-body-generator     | Read                                        | sonnet   | read                                    | anthropic/claude-sonnet-4
code-reviewer          | Read, Bash, Glob, Grep                      | sonnet   | read, bash, find, grep                 | anthropic/claude-sonnet-4
issue-fixer            | Read, Bash, Glob, Grep                      | sonnet   | read, bash, find, grep                 | anthropic/claude-sonnet-4
single-fix-agent       | Read, Edit, Bash, Glob, Grep, LS            | opus     | read, edit, bash, find, grep, ls       | anthropic/claude-opus-4
review-report-writer  | Read, Write, Bash, Glob, Grep               | sonnet   | read, write, bash, find, grep           | anthropic/claude-sonnet-4
task-explorer          | Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, KillShell, BashOutput | sonnet | find, grep, ls, read             | anthropic/claude-sonnet-4
task-architect         | Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, KillShell, BashOutput | opus | find, grep, ls, read            | anthropic/claude-opus-4
```

## Appendix B: Full catalog of pi plugins

| Package                    | Version | Purpose                                                              | Requirement     |
| -------------------------- | ------- | -------------------------------------------------------------------- | --------------- |
| `pi-subagents`             | 0.19.3  | Sub-agents, chains, parallel dispatch, fork context, per-agent model | **Required**    |
| `pi-ask-user`              | 0.6.1   | Interactive Q&A (replacement for AskUserQuestion)                    | **Required**    |
| `pi-intercom`              | 0.2.1   | Orchestrator ↔ agent coordination, notifications                     | **Recommended** |
| `pi-web-access`            | latest  | WebSearch, WebFetch (replacement for CC tools)                       | Optional        |
| `pi-docparser`             | latest  | PDF/Office parsing (replacement for NotebookRead)                    | Optional        |
| `pi-lens`                  | 3.8.33  | Real-time LSP/linter (replacement for manual checks)                 | Optional        |
| `pi-prompt-template-model` | latest  | Reusable prompt templates                                            | Optional        |

## Appendix C: Pi-subagents agent frontmatter reference

```yaml
---
name: my-agent # 1-64 chars, lowercase a-z 0-9 hyphens
description: What this agent does # Max 1024 chars
tools: read, write, edit, bash, find, grep, ls # Tool allowlist
model: anthropic/claude-sonnet-4 # Default model
fallbackModels: # Ordered backup models
  - openai/gpt-5-mini
  - anthropic/claude-haiku-4-5
thinking: high # Thinking level: off, minimal, low, medium, high, xhigh
systemPromptMode: replace # replace (default) or append
inheritProjectContext: true # Keep project instructions
inheritSkills: false # Keep skills catalog
skills: safe-bash, chrome-devtools # Inject specific skills
output: context.md # Default output file
defaultReads: context.md # Files to read before running
defaultProgress: true # Maintain progress.md
interactive: true # Parsed for compatibility
maxSubagentDepth: 1 # Tighten nested delegation
extensions: # Empty = no extensions
---
System prompt body...
```

## Appendix D: Pi-ask-user tool parameters

```json
{
  "question": "Which option should we use?",
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
{
  "kind": "selection",
  "selections": ["Option A"],
  "comment": null
}
```

or

```json
{
  "kind": "freeform",
  "text": "I want something different..."
}
```
