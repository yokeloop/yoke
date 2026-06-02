# Domain docs — consumer rules

How to consume this repo's domain documentation — the glossary and ADRs that `/yoke:grill-docs` produces — when exploring the codebase for `/yoke:prd`, `/yoke:issues`, or any analysis.

## Before exploring, read these

- **`.yoke/context.md`** — the single domain glossary for the whole repo.
- **`.yoke/adr/`** — read the ADRs that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their absence or suggest creating them upfront — `/yoke:grill-docs` creates them lazily when terms or decisions are resolved.

## Use the glossary's vocabulary

When your output names a domain concept (an issue title, a requirement, a user story, a hypothesis, a test name), use the term as defined in `.yoke/context.md`. Don't drift to synonyms the glossary explicitly avoids.

If a concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider), or there's a real gap (note it for `/yoke:grill-docs`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…_
