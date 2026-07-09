# Skill /bootstrap

Prepares a project for yoke flow. Detects the stack, analyzes the architecture, scans conventions,
scaffolds the `.yoke/` layout, and generates CLAUDE.md and `.yoke/yoke-context.md`.

## Input

Fires on prompts like: "bootstrap", "configure yoke", "prepare the project", "init yoke",
"setup yoke", "first run". No parameters.

```
/yoke:bootstrap
```

## Output

- `CLAUDE.md` — instructions for Claude Code, generated from the project's stack and conventions, wired to the `.yoke/` conventions
- `.yoke/yoke-context.md` — stack/architecture/commands context for the yoke flow
- `.yoke/` skeleton — `context.md` (domain glossary seed), `journal.md`, `ai/`, `adr/`

## Phases

1. **Sibling discovery** — find already-bootstrapped neighbors via `additionalDirectories`, pick a hypothesis profile (ADR-0010)
2. **Stack detection** — identify languages, frameworks, build tools
3. **Architecture analysis** — map directories, layers, dependencies
4. **Convention scanning** — code style, naming, patterns
5. **Existing rules detection** — linters, CI, configs
6. **Validation** — check collected data
7. **CLAUDE.md generation** — build the instructions, wired to the `.yoke/` conventions
8. **Context + `.yoke/` scaffold** — write `.yoke/yoke-context.md` and scaffold `.yoke/` (`context.md`, `journal.md`, `ai/`, `adr/`)
9. **Automation recommendations** — suggestions for hooks and scripts
10. **Verification** — final check of CLAUDE.md, context, and the `.yoke/` skeleton

(Simplified overview; the actual pipeline is 7 phases including Preflight, Confirm, and Commit.)

## Notes

- Orchestrator with 10 sub-agents
- Interactive: asks clarifying questions via AskUserQuestion
- Entry point for a new project in yoke
- Sibling-aware: a stack-matching neighbor's `yoke-context.md` (or the repo's own
  on a re-run) is verified as a hypothesis instead of re-deriving everything;
  the neighbor's flow map pre-fills the flow interview. Shared facts are linked
  to their owner repo, never copied (ADR-0010)

## Connections

The first step before using yoke flow. After bootstrap, start work with `/yoke:do`.
