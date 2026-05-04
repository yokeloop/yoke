# Skill /help

How to use yoke — the help skill explains the marketplace layout, available skills, and the recommended workflow.
Entry point for new users of the plugin.

## Input

Fires automatically on prompts like: "how do I use yoke?", "what is the marketplace?",
"which skills are available?", or on first contact with the plugin. No parameters.

```
/yoke:help
```

## Output

A structured overview:

- **Project description** — what yoke is, inspiration
- **Skills catalog** — short description of each skill with example commands
- **Full cycle** — recommended sequence: task → plan → do → fix → review
- **Planned skills** — list of upcoming components
- **Installation** — command to install the plugin

## Notes

- Informational skill — no sub-agents, no side effects
- Static content, printed directly in the main thread

## Example

```
/yoke:help
```

Result: an overview of the yoke marketplace and available skills.

## Connections

Entry point into the yoke system. Recommends the full cycle: `/task` → `/plan` → `/do` → `/fix` → `/review`.
