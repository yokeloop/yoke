# Skill /prd

Turns the current conversation and codebase understanding into a Product Requirements Document, publishes it as a GitHub issue, and saves a local copy. Does not interview you — synthesises what is already known from the session.

## Input

No arguments. Works from the current conversation context.

```
/yoke:prd
```

## Process

| Step | What happens                                                                |
| ---- | --------------------------------------------------------------------------- |
| 1    | Explore the repo; follow domain-doc consumer rules (.yoke/context.md, ADRs) |
| 2    | Sketch the major modules; favour deep, testable modules; confirm tests      |
| 3    | Write the PRD from the template                                             |
| 4    | Save a local copy to `.yoke/ai/<slug>/<slug>-prd.md`                        |
| 5    | Publish as a GitHub issue, apply `ready-for-agent`                          |

## PRD template

Problem Statement · Solution · User Stories (extensive, `As an <actor>, I want <feature>, so that <benefit>`) · Implementation Decisions · Testing Decisions · Out of Scope · Further Notes.

No file paths or code snippets (they go stale) — except a decision-encoding prototype snippet (state machine, schema, type shape) when prose cannot capture it.

## Output

- `.yoke/ai/<slug>/<slug>-prd.md` — local copy.
- A GitHub issue (when `gh` is authenticated and a GitHub remote exists), labelled `ready-for-agent`. See [github-issues.md](../skills/issues/reference/github-issues.md). Falls back to local-only otherwise.

## Connections

Spec front-end. Run after `/yoke:grill` / `/yoke:grill-docs` to formalise the discussion, then `/yoke:issues` to break the PRD into tickets.
