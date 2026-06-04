---
name: handoff
description: >-
  Compacts the current conversation into a handoff document so a fresh agent can
  continue the work, referencing existing artifacts instead of duplicating them.
  Saves to the OS temp directory. Activates when the user writes "handoff",
  "hand off", "compact the conversation", "summarize for the next session",
  "prepare a handoff doc", "pass this to another agent".
---

# Handoff

Write a handoff document summarizing the current conversation so a fresh agent can continue the work. Resolve the OS temp directory with a shell call (`echo "${TMPDIR:-/tmp}"`) and save there — not in the current workspace — under a collision-proof name like `handoff-<slug>-<YYYYMMDD-HHMMSS>.md`.

Cover concisely: the goal, the current state (what is done), what is left and the next steps, key decisions, gotchas or blockers, and paths or URLs to the relevant artifacts.

Include a "Suggested skills" section recommending which yoke skills the next agent should invoke, based on where the work sits in the flow (e.g. unstarted → `/yoke:do`; implemented but unreviewed → `/yoke:review`).

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead. Yoke artifacts live under `.yoke/` in the workspace (e.g. `.yoke/ai/<slug>/`, `.yoke/adr/`, `.yoke/context.md`).

Redact any sensitive information — API keys, passwords, PII — by replacing it with `[REDACTED]` (the file lands in shared `/tmp`).

If the user passed `$ARGUMENTS`, treat it as a description of what the next session will focus on and tailor the doc accordingly.

Print the absolute path to the saved file so the user can hand it to the next agent.

## Rules

- Save to the OS temp directory, not the workspace.
- Reference existing artifacts by path or URL; don't duplicate their content.
- Redact secrets and PII.
- Language: match the conversation language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
