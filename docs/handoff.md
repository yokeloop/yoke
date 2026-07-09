# Skill /handoff

Saves the live state of the current conversation so a fresh session resumes where this one stopped. Writes to `.yoke/handoff/` and references existing artifacts instead of duplicating them.

## Input

`$ARGUMENTS` (optional) — what the next session will focus on; tailors the document.

```
/yoke:handoff
/yoke:handoff continue with the payment retry logic
```

## What it writes

Everything that exists only in the conversation: the open tasks with their status, the user's requirements quoted verbatim, the decisions and the alternatives rejected along the way, the git state, and the gotchas. It closes with a **Suggested skills** section pointing at the right yoke skills to continue (`/yoke:grill`, `/yoke:grill-docs`, `/yoke:do`, `/yoke:merge`, `/yoke:gca`, `/yoke:gp`, `/yoke:pr`).

- References PRDs, plans, ADRs, issues, commits, and diffs by path or URL — never duplicates them.
- Links the previous handoff of the same conversation rather than restating it.
- Redacts secrets and PII — the file is committed with the rest of `.yoke/`.

## Output

`.yoke/handoff/<YYYYMMDD-HHMMSS>-<slug>.md`, always in the root checkout — never inside a worktree, which `/yoke:merge` deletes. The skill prints the absolute path so you can hand it to the next agent. Handoffs accumulate; nothing prunes them.

See [ADR 0009](../.yoke/adr/0009-handoff-under-yoke-root-checkout.md) for why the document lives there.

## Connections

Utility, usable anytime. Bridges two sessions when context runs long or work passes to another agent.
