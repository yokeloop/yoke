# Skill /grill-docs

A grilling session that challenges your plan against the project's domain model, sharpens terminology, and updates documentation inline as decisions crystallise. Same interactive interview as `/yoke:grill`, plus it maintains the glossary (`.yoke/context.md`) and architecture decision records (`.yoke/adr/`).

## Input

`$ARGUMENTS` — the plan, design, or topic to grill. If empty, asks via AskUserQuestion.

```
/yoke:grill-docs design the order cancellation flow
```

## How it works

Interactive, one question at a time (recommended answer first, "Other" for free-form), exactly like `/yoke:grill`. On top of that, during the session it:

- **Challenges against the glossary** — flags terms that conflict with `.yoke/context.md`.
- **Sharpens fuzzy language** — proposes a precise canonical term for overloaded words.
- **Stress-tests with scenarios** — invents edge cases to force precise boundaries.
- **Cross-references code** — surfaces contradictions between what you say and what the code does.
- **Updates `.yoke/context.md` inline** — captures resolved terms as they happen (glossary only, no implementation detail).
- **Offers ADRs sparingly** — only when a decision is hard to reverse, surprising without context, and the result of a real trade-off.

Files are created lazily — only when there is something to write.

## Output

- `.yoke/context.md` — the domain glossary. Format: [CONTEXT-FORMAT.md](../skills/grill-docs/reference/CONTEXT-FORMAT.md).
- `.yoke/adr/NNNN-*.md` — architecture decision records. Format: [ADR-FORMAT.md](../skills/grill-docs/reference/ADR-FORMAT.md).

Downstream skills consume these via the consumer rules in [domain-docs.md](../skills/grill-docs/reference/domain-docs.md).

## Connections

Discovery front-end with memory. The glossary and ADRs it produces feed `/yoke:prd`, `/yoke:issues`, and codebase exploration.
