# Mode: inline

Inline mode handles a small task described directly in chat — for example, a quick follow-up right after `/yoke:grill`. The lightest mode: plan briefly, execute in-session, no confirmation pause, no plan artifact. Even so, a change ends at a pull request, never at bare commits on a branch nobody pushed (ADR-0006).

**Flow:**

```
1. Brief plan  → state the change in chat (1–3 bullets)
2. Isolate     → on the default branch, branch or worktree first (finish.md §2)
3. Execute     → edit directly in the current session
4. Validate    → run lint/type/test/build; fix failures
5. Commit      → per commit-convention.md
6. Finish      → push, PR, ticket comment, notify (finish.md §3, §5, §7)
```

---

## Step 1 — Brief plan (in chat)

State the change in 1–3 bullets before touching any file:

- Which files to touch and why.
- The approach (what you will add, remove, or change).
- Any non-obvious dependency or ordering constraint.

**No `.yoke/ai/` file.** Do not dispatch `plan-architect` or `task-investigator` for trivial scope. This step is a few lines in chat, not a document.

---

## Step 2 — Isolate (before any edit)

**On the repo's default branch → branch first, before the first edit.** A plain `git switch -c <slug>` is enough for a single-repo inline change; use a worktree per `reference/finish.md` §2 when isolation matters. Already on a feature branch or inside a worktree → work in place. Inline has no confirmation pause, so isolate here — right before Step 3 — since there is no plan gate to hang the worktree entry on.

---

## Step 3 — Execute in-session

Make the edits directly using the Read/Edit/Write/Bash tools. Do not dispatch `task-executor` sub-agents for an inline task — the current session is the executor.

Follow existing codebase patterns: naming conventions, file structure, import style, formatting.

---

## Step 4 — Validate

Run the project's validation commands. For this repo: `pnpm run format:check`. For other projects, run lint, type-check, test, and build as applicable. Fix any failures before committing.

---

## Step 5 — Commit

Commit per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.

Format: `TICKET type(SLUG): description`

Derive `TICKET` and `SLUG` from the task input when present (issue number, branch name, or slug). Omit them when there is no associated ticket.

---

## Step 6 — Finish (drive to PR)

Even a small inline change ends with a pull request — never with bare commits on a branch nobody pushed (ADR-0006). Hand off to `reference/finish.md` and run its lightest path:

- **§3 Per-repo finish** — usually just `git push -u origin <branch>`, then create the PR through the pr skill's mechanics. For a `direct-push` repo, push the default branch and publish instead.
- **§5 Ticket comment** — when a tracker is configured, post one short comment (summary + PR URL) to the task's ticket. No tracker → skip silently.
- **§7 Notify** — send **one** STAGE_COMPLETE notification carrying the PR URL. This is the run's completion — the PR link is the deliverable, not a chat-only summary.

The only exits without a PR are the user's explicit **straight-to-main** signal (`reference/finish.md` §6) and a repo whose policy is `direct-push`.

---

## When to escalate

If the task turns out larger than expected — many files, parallelizable work, or a need for review gates — stop and switch to sub-agents mode instead: write a plan file, pause for confirmation, and follow `reference/mode-sub-agents.md`.

---

## Rules

- **No pause.** Inline executes without a confirmation gate.
- **No plan file.** Nothing written to `.yoke/ai/` or anywhere else.
- **No sub-agents.** All edits happen in the current session.
- **Always finish at a PR.** Isolate on the default branch before editing, then finish per `reference/finish.md` — push, PR, ticket comment, one STAGE_COMPLETE notify. The only exceptions are the straight-to-main signal (§6) and a `direct-push` repo.
- **Commits by convention.** Format and ticket ID from `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- Language: match the task/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
