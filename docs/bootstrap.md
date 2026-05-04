# Skill /bootstrap

Prepares a project for yoke flow. Detects the stack, analyzes the architecture, scans conventions,
and generates CLAUDE.md and `.claude/yoke-context.md`.

## Input

Fires on prompts like: "bootstrap", "configure yoke", "prepare the project", "init yoke",
"setup yoke", "first run". No parameters.

```
/yoke:bootstrap
```

## Output

- `CLAUDE.md` — instructions for Claude Code; the skill generates it from the project's stack and conventions
- `.claude/yoke-context.md` — project context for yoke flow

## Phases

1. **Stack detection** — identify languages, frameworks, build tools
2. **Architecture analysis** — map directories, layers, dependencies
3. **Convention scanning** — code style, naming, patterns
4. **Existing rules detection** — linters, CI, configs
5. **Validation** — check collected data
6. **CLAUDE.md generation** — build the instructions
7. **yoke-context.md generation** — build the context
8. **Automation recommendations** — suggestions for hooks and scripts
9. **Verification** — final check of the results

## Notes

- Orchestrator with 9 sub-agents
- Interactive: asks clarifying questions via AskUserQuestion
- Entry point for a new project in yoke

## Connections

The first step before using yoke flow. After bootstrap, use the full cycle: `/task` → `/plan` → `/do`.
