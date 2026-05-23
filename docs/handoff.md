# Skill /handoff

Compacts the current conversation into a handoff document so a fresh agent can pick up the work. Saves to the OS temp directory — not the workspace — and references existing artifacts instead of duplicating them.

## Input

`$ARGUMENTS` (optional) — what the next session will focus on; tailors the document.

```
/yoke:handoff
/yoke:handoff continue with the payment retry logic
```

## What it writes

A summary of the conversation for a new agent, including a **Suggested skills** section pointing at the right yoke skills to continue (`/yoke:task`, `/yoke:plan`, `/yoke:do`, `/yoke:review`, `/yoke:fix`, `/yoke:gca`).

- References PRDs, plans, ADRs, issues, commits, and diffs by path or URL — never duplicates them.
- Redacts secrets and PII.

## Output

A markdown file in the OS temp directory (`${TMPDIR:-/tmp}`). The absolute path is printed so you can hand it to the next agent.

## Connections

Utility, usable anytime. Bridges two sessions when context runs long or work passes to another agent.
