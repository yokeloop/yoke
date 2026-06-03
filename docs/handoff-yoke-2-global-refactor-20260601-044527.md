# Handoff — yoke 2.0 Global Refactor (planning → implementation)

**Repo:** `/home/ivan/projects/yoke` · **Branch:** `17-next-version` (just created off `main`)
**Date:** 2026-06-01

## Goal

Plan and then implement a breaking **yoke 2.0** refactor of the plugin: one
artifact root (`.yoke/`), a universal `do`, fewer skills, a session journal,
reworked `bootstrap`, and the Telegram-notification simplification folded in.

## Current state — DONE (planning complete)

The full planning flow ran: `grill-docs` → `prd` → `issues`. All decisions are
captured in artifacts and published to GitHub. **No code/skill changes yet.**

- **Epic:** https://github.com/yokeloop/yoke/issues/17 (Feature, `ready-for-agent`)
- **7 sub-issues published, typed `Task`, linked under #17.** Execution order:
  - https://github.com/yokeloop/yoke/issues/18 — S1 `.yoke/` convention + path migration (**spine**)
  - https://github.com/yokeloop/yoke/issues/19 — S2 deprecate fix/gst/explore; relocate sync-docs
  - https://github.com/yokeloop/yoke/issues/20 — S6 direct Telegram notifications (folds #16)
  - https://github.com/yokeloop/yoke/issues/21 — S3 `do` universal rework; deprecate task/plan (absorbs #5)
  - https://github.com/yokeloop/yoke/issues/22 — S4 `/yoke:journal`
  - https://github.com/yokeloop/yoke/issues/23 — S5 `bootstrap` rework
  - https://github.com/yokeloop/yoke/issues/24 — S7 release 2.0.0 (HITL, `ready-for-human`)

## Key decisions (full detail in the ADRs/PRD — do not re-litigate)

- **ADR 0004** (`docs/adr/0004-yoke-artifact-root.md`) — single `.yoke/` root:
  `.yoke/context.md`, `.yoke/adr/`, `.yoke/ai/<slug>/`, `.yoke/journal.md`. Fixed
  path convention, **no manifest**. Committed by default (user may gitignore).
- **ADR 0005** (`docs/adr/0005-do-universal-orchestrator.md`) — `do` becomes
  universal, auto-detects **inline / sub-agents / team**; mode-dependent plan
  artifact; sub-agents/team pause for confirmation. `task`/`plan` retired.
- **ADR 0003** (`docs/adr/0003-direct-telegram-notify.md`) — direct inline
  `lib/notify.sh`, no hook/queue/jq. With an **escape hatch**: if unreliable in
  practice, remove notifications entirely and close #16 wontfix.
- Skill disposition: `fix`/`gst`/`explore`/`task`/`plan` → `deprecated/`;
  `sync-docs` → `.claude/skills/` (repo-internal, **not** deprecated — it feeds
  the public docs site, ADR 0001/0002).
- Memory: this epic ships only the **journal + artifact** layers. The git-backed
  layer (Lore trailers / GitHub comments, issue #2) is **deferred to 2.1**.
- Version: **2.0.0** (breaking).

## Dependency graph / order

Wave 0 (no blockers, start with #18): **#18**, #19, #20.
Wave 1 (after #18 merges): #21, #22, #23 (mutually independent).
Wave 2 (capstone, after all): #24.
Critical path: **#18 → #21/#22/#23 → #24**.

## Gotchas / blockers

- **`.yoke/` is gitignored in THIS repo** (`.gitignore` line 2: `.yoke`). So the
  local artifacts below are **untracked / invisible to git**. The **canonical**
  copies of the PRD and issue breakdown are the **GitHub issues (#17–#24)** — use
  those, not the local files, as the source of truth.
  - Local-only (ignored): `.yoke/context.md`, `.yoke/ai/yoke-2-global-refactor/{…-prd.md,…-issues.md}`.
  - **Decision for S1 (#18):** the repo currently ignores `.yoke`, but ADR 0004 +
    S1 acceptance say it should be committed by default. S1 must reconcile this —
    likely remove `.yoke` from `.gitignore` (and keep only `.yoke/notify-pending.json`
    if anything, which S6 deletes anyway). Confirm with the user.
- **Untracked but committable** (NOT ignored), created this session:
  `docs/adr/0003-…`, `docs/adr/0004-…`, `docs/adr/0005-…`, and the older #16 PRD
  `docs/ai/direct-telegram-notifications/`. These are not yet committed.
  - Note: ADR 0004 says ADRs migrate from `docs/adr/` → `.yoke/adr/` as part of S1.
- **`docs/note.md`** is untracked and **pre-existing / not authored this session** —
  leave it alone unless the user asks.
- Nothing has been committed and nothing pushed. `git` was intentionally not
  touched during planning.

## What's left / next steps

1. **Commit the planning artifacts** (user's call on what to track). The ADRs and
   #16 PRD under `docs/` are committable now; decide `.yoke/` ignore policy first
   (see gotcha). Use `/yoke:gca`.
2. **Implement S1 first — #18** (the spine). It unblocks #21/#22/#23 and must
   resolve the `.gitignore` `.yoke` question.
3. #19 and #20 can proceed in parallel with #18 (independent of the path convention).
4. Then #21/#22/#23, then the #24 release (HITL).

## Suggested skills

- **`/yoke:gca`** — first, to commit the ADRs/PRD artifacts on this branch.
- **`/yoke:do https://github.com/yokeloop/yoke/issues/18`** — implement S1 (spine).
  Per ADR 0005, a single issue → sub-agents mode (writes a plan artifact, pauses
  for confirmation). Note: `do` itself is only reworked in S3, so today it still
  expects a plan-file path — you may need to drive S1 more manually or run
  `/yoke:plan` then `/yoke:do` under the _current_ (pre-2.0) flow.
- **`/yoke:review`** — after each slice lands.
- Repeat `/yoke:do` for #19, #20, then #21–#23; finish with **`/yoke-release`** for #24.
