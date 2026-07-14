---
name: draft
description: >-
  Projects the agreed plan onto the code as Markup — TODO markers plus a
  compilable skeleton — and opens a Draft PR for review, instead of
  implementing. Triggered when the user writes "draft", "mark the code",
  "mark up the plan", "make a draft", "draft pr".
---

# Mark the code per plan

The optional marking step between grill and do (ADR-0011). A do-shaped run — the same
inputs and the same finish machinery as `/do` — that marks instead of
implementing: it projects the plan onto the code as Markup and opens a GitHub
Draft PR for remote review. `/draft` NEVER pauses — the Draft PR is the pause.
The flow becomes **grill → draft → PR review → do**; grill → do stays the
default.

---

## Input

`$ARGUMENTS` — one of:

- **empty** — no input; work from the current conversation
- **a plain task description** — chat text, no ticket
- **a single issue URL**, a bare `<slug>`, or a `*-task.md` path

All of the above → fresh marking. Plus the iteration shapes:

- **a Draft PR URL**, or **a bare `<slug>`** whose
  `.yoke/ai/<slug>/<slug>-draft.md` exists → iteration against the existing
  Draft

---

## Router

Detect the run from `$ARGUMENTS`. First match wins:

1. **Input is a Draft PR URL, or a `<slug>` with an existing
   `.yoke/ai/<slug>/<slug>-draft.md`** → **iteration**. Read and follow
   `reference/mode-draft.md` § Iteration.
2. **Anything else** → **fresh marking**. Read and follow
   `reference/mode-draft.md` from Phase 0.

The full procedure lives in `reference/mode-draft.md`. Read it, then execute.

---

## Principles

These hold for every run:

- **Never pauses.** No cold-start gate, no confirmation, no mid-run question —
  the Draft PR is the pause.
- **Marks, never implements.** The Markup contract is
  `reference/markup-format.md`: `TODO(yoke):` Markers plus a compilable
  skeleton. The build stays green; tests may be red.
- **Ends at the Draft PR.** Never flips it to ready, never merges — `/do`
  executes the Draft; `/merge` finishes after approval.
- **Worktree on default branch + finish machinery** per
  `${CLAUDE_PLUGIN_ROOT}/skills/do/reference/finish.md`.
- **Artifacts under `.yoke/`.** `<slug>-plan.md` and `<slug>-draft.md` live in
  `.yoke/ai/<slug>/`.
- **Commits by convention** per
  `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- **Read the git memory first** per
  `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/history-reading.md` — a Marker
  must not re-propose what a `Rejected:` trailer already dismissed, and
  Markup respects active `Constraint:` entries.
- Language: match the ticket/input language, or follow the project-level
  definition in CLAUDE.md / AGENTS.md.

---

## After the run

The user reviews the Draft PR on GitHub and comments on it. A re-run of
`/draft` re-marks per the comments; `/do <draft-PR-URL>` (or `/do <slug>`)
implements the Markers and flips the PR to ready.
