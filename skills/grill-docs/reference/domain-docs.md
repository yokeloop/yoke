# Domain docs — consumer rules

How to consume this repo's domain documentation — the glossary and ADRs that `/yoke:grill-docs` produces — when exploring the codebase for `/yoke:prd`, `/yoke:issues`, or any analysis.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root, or
- **`CONTEXT-MAP.md`** at the repo root if it exists — it points at one `CONTEXT.md` per context. Read each one relevant to the topic.
- **`docs/adr/`** — read the ADRs that touch the area you're about to work in. In multi-context repos, also check `src/<context>/docs/adr/` for context-scoped decisions.

If any of these files don't exist, **proceed silently**. Don't flag their absence or suggest creating them upfront — `/yoke:grill-docs` creates them lazily when terms or decisions are resolved.

## Use the glossary's vocabulary

When your output names a domain concept (an issue title, a requirement, a user story, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If a concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider), or there's a real gap (note it for `/yoke:grill-docs`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…_
