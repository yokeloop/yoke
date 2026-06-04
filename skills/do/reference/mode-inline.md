# Mode: inline

Inline mode handles a small task described directly in chat — for example, a quick follow-up right after `/yoke:grill`. Plan briefly, execute in-session, no confirmation pause, no plan artifact.

**Flow:**

```
1. Brief plan  → state the change in chat (1–3 bullets)
2. Execute     → edit directly in the current session
3. Validate    → run lint/type/test/build; fix failures
4. Commit      → per commit-convention.md
5. Summary     → print what changed; done
```

---

## Step 1 — Brief plan (in chat)

State the change in 1–3 bullets before touching any file:

- Which files to touch and why.
- The approach (what you will add, remove, or change).
- Any non-obvious dependency or ordering constraint.

**No `.yoke/ai/` file.** Do not dispatch `plan-architect` or `task-investigator` for trivial scope. This step is a few lines in chat, not a document.

---

## Step 2 — Execute in-session

Make the edits directly using the Read/Edit/Write/Bash tools. Do not dispatch `task-executor` sub-agents for an inline task — the current session is the executor.

Follow existing codebase patterns: naming conventions, file structure, import style, formatting.

---

## Step 3 — Validate

Run the project's validation commands. For this repo: `pnpm run format:check`. For other projects, run lint, type-check, test, and build as applicable. Fix any failures before committing.

---

## Step 4 — Commit

Commit per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.

Format: `TICKET type(SLUG): description`

Derive `TICKET` and `SLUG` from the task input when present (issue number, branch name, or slug). Omit them when there is no associated ticket.

---

## Step 5 — Summary

Print a brief summary of what changed: files touched, what was added or removed, and any noteworthy decisions. No report file, no pause.

---

## When to escalate

If the task turns out larger than expected — many files, parallelizable work, or a need for review gates — stop and switch to sub-agents mode instead: write a plan file, pause for confirmation, and follow `reference/mode-sub-agents.md`.

---

## Rules

- **No pause.** Inline executes without a confirmation gate.
- **No plan file.** Nothing written to `.yoke/ai/` or anywhere else.
- **No sub-agents.** All edits happen in the current session.
- **Commits by convention.** Format and ticket ID from `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- Language: match the task/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
