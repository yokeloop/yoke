# yoke 2.0 — Global Refactor — issue breakdown

**Epic:** https://github.com/yokeloop/yoke/issues/17
**PRD:** [yoke-2-global-refactor-prd.md](./yoke-2-global-refactor-prd.md)

7 vertical slices. Dependency order: **S1** is the spine (blocks S3/S4/S5);
**S2** and **S6** are independent; **S7** is the capstone.

| Slice                                              | Issue                                             | Type | Label           | Blocked by |
| -------------------------------------------------- | ------------------------------------------------- | ---- | --------------- | ---------- |
| S1 — `.yoke/` artifact convention + path migration | [#18](https://github.com/yokeloop/yoke/issues/18) | AFK  | ready-for-agent | —          |
| S2 — Deprecate fix/gst/explore; relocate sync-docs | [#19](https://github.com/yokeloop/yoke/issues/19) | AFK  | ready-for-agent | —          |
| S6 — Direct Telegram notifications (folds #16)     | [#20](https://github.com/yokeloop/yoke/issues/20) | AFK  | ready-for-agent | —          |
| S3 — `do` universal rework; deprecate task/plan    | [#21](https://github.com/yokeloop/yoke/issues/21) | AFK  | ready-for-agent | #18        |
| S4 — `/yoke:journal` skill                         | [#22](https://github.com/yokeloop/yoke/issues/22) | AFK  | ready-for-agent | #18        |
| S5 — `bootstrap` rework                            | [#23](https://github.com/yokeloop/yoke/issues/23) | AFK  | ready-for-agent | #18        |
| S7 — Release yoke 2.0.0                            | [#24](https://github.com/yokeloop/yoke/issues/24) | HITL | ready-for-human | #18–#23    |

All seven are typed `Task` and linked as sub-issues of epic #17.

**Related existing issues:** #16 folded into S6 (closed on completion); #5
absorbed by S3; #6 (`/autopilot`) downstream of S3; #2 (Lore/git memory layer)
deferred to 2.1.

---

## S1 — #18 — `.yoke/` artifact convention + path migration

**Type:** AFK · **Blocked by:** none

## Parent

Epic: #17 — yoke 2.0 — Global Refactor

## What to build

Establish `.yoke/` as the single root for everything yoke produces in a target
project, with a fixed path convention (no manifest), and migrate every skill
that is _not_ otherwise being reworked in this epic onto it. This is the spine
the rest of 2.0 depends on. Recorded in **ADR 0004**.

The convention (per ADR 0004):

- `.yoke/context.md` — the domain glossary (was root `CONTEXT.md`).
- `.yoke/adr/` — architecture decision records (was `docs/adr/`).
- `.yoke/ai/<slug>/` — per-task pipeline artifacts (PRD, plan, report,
  exploration, issues index) (was `docs/ai/<slug>/`).
- `.yoke/journal.md` — the session journal (created/written by S4).

End-to-end behavior: after this slice, invoking any migrated skill reads from
and writes to the `.yoke/` layout and nothing lands under `docs/ai/` or root
`CONTEXT.md`. `.yoke/` is committed to git by default; the user may `.gitignore`
it. Skills no longer probe `.gitignore` to decide where to write — they always
target `.yoke/` and commit unless the root is ignored.

Scope of skills migrated here (the ones not reworked elsewhere in the epic):
`grill-docs`, `grill`, `prd`, `issues`, `review`, `gca`, `handoff`. The skills
reworked in their own slices (`do` in S3, `journal` in S4, `bootstrap` in S5)
adopt the convention as part of their rework. Move the existing ADRs
(`docs/adr/0001`–`0005`) into `.yoke/adr/`. Update `README.md` and `CLAUDE.md`
to describe the `.yoke/` convention.

## Acceptance criteria

- [ ] `.yoke/` path convention documented in `CLAUDE.md` and `README.md`
- [ ] Glossary lives at `.yoke/context.md`; root `CONTEXT.md` is gone
- [ ] ADRs live in `.yoke/adr/`; `docs/adr/` no longer holds them
- [ ] `grill-docs`, `grill`, `prd`, `issues`, `review`, `gca`, `handoff` read/write artifacts under `.yoke/ai/<slug>/` (and `.yoke/adr/`, `.yoke/context.md`)
- [ ] No skill writes to `docs/ai/` or root `CONTEXT.md` anymore
- [ ] The `.gitignore`-probing logic that decided artifact location is removed; skills always write to `.yoke/` and commit unless `.yoke/` is ignored
- [ ] Manual check: running each migrated skill lands its artifact at the documented `.yoke/` path

## Blocked by

None - can start immediately. (This slice blocks S3, S4 and S5.)

---

## S2 — #19 — Deprecate fix/gst/explore; relocate sync-docs to .claude/

**Type:** AFK · **Blocked by:** none

## Parent

Epic: #17 — yoke 2.0 — Global Refactor

## What to build

Shrink the shipped skill set: retire the unused skills and fix the
miscategorised one. Recorded in **ADR 0005** (skill cleanup section).

- Move `fix`, `gst`, `explore` into a top-level `deprecated/` directory, out of
  auto-discovery — they stop loading and stop shipping, but remain recoverable
  from git.
- Relocate `sync-docs` from `skills/` to `.claude/skills/` as a **repo-internal**
  skill. It only maintains _this_ repo's public docs site (ADR 0001/0002), so it
  should never have shipped to users. The docs site keeps regenerating; the skill
  is simply no longer part of the marketplace surface.
- Update `README.md`, `CLAUDE.md` and the public skill catalog so the documented
  shipped set matches reality.

Note: `task` and `plan` are NOT handled here — they are moved to `deprecated/`
in S3, after `do` has absorbed their logic, to avoid a capability gap.

End-to-end behavior: after this slice, `fix`/`gst`/`explore`/`sync-docs` no
longer appear as `/yoke:*` skills; `sync-docs` is still runnable from `.claude/`
and the site still builds; the catalog and docs reflect the smaller set.

## Acceptance criteria

- [ ] `fix`, `gst`, `explore` live under `deprecated/` and are not auto-discovered
- [ ] `sync-docs` lives under `.claude/skills/`, not `skills/`, and is not shipped
- [ ] The public docs site still regenerates via the relocated `sync-docs`
- [ ] `README.md`, `CLAUDE.md` and the catalog list only the shipped skills
- [ ] Plugin manifest validation still passes (`python3 -c "import json; ..."`)

## Blocked by

None - can start immediately.

---

## S6 — #20 — Direct Telegram notifications (folds #16)

**Type:** AFK · **Blocked by:** none · closes #16

## Parent

Epic: #17 — yoke 2.0 — Global Refactor

## What to build

Fold in the direct Telegram notifications change (issue #16, **ADR 0003**):
replace the queue + Stop-hook with a single direct-send `lib/notify.sh` that
POSTs to the Telegram Bot API immediately, inline, on each call.

- Rewrite `lib/notify.sh` as a direct sender: reads `CC_TELEGRAM_BOT_TOKEN` /
  `CC_TELEGRAM_CHAT_ID` from the environment, form-encodes via
  `curl --data-urlencode` (no `jq`), POSTs immediately, honors an optional
  `CC_NOTIFY_LEVELS` filter, and is always silent / always exits 0 with a bounded
  `--max-time`. Flags: `--type`, `--title`, `--body`, `--skill`
  (`--slug`/`--phase` dropped). `project_name = basename "$PWD"`.
- Remove `hooks/notify.sh`, `hooks/hooks.json`, the `hooks/` directory, the
  `jq` dependency, and the `.yoke/notify-pending.json` queue. The plugin ships
  no hooks after this.
- Update the surviving call sites (in the non-deprecated skills) to the
  simplified flags.
- Rewrite `docs/notify.md`, and update `README.md`/`CLAUDE.md`.

**Escape hatch (acceptance decision):** verify direct inline send works
reliably. If it does NOT, remove the Telegram notification story entirely
(script + all call sites + docs) and close #16 as `wontfix` instead of shipping
a flaky feature.

## Acceptance criteria

- [ ] `lib/notify.sh` sends directly, no queue file, no `jq`, `curl`-only
- [ ] `hooks/` directory, `hooks.json`, Stop hook, and the queue are removed
- [ ] Surviving call sites use `--type`/`--title`/`--body`/`--skill` only
- [ ] Behavioral checks pass: happy path delivers; unset credentials → exit 0, no output; `CC_NOTIFY_LEVELS` filter respected; missing `curl` → exit 0; special characters arrive intact
- [ ] `docs/notify.md`, `README.md`, `CLAUDE.md` describe direct send
- [ ] If direct send proves unreliable: notifications removed entirely and #16 closed as wontfix

## Blocked by

None - can start immediately. (Closes #16.)

---

## S3 — #21 — do universal rework (inline/sub-agents/team); deprecate task/plan

**Type:** AFK · **Blocked by:** #18 · absorbs #5

## Parent

Epic: #17 — yoke 2.0 — Global Refactor

## What to build

Turn `do` into the universal execution tool and retire `task`/`plan`. Recorded
in **ADR 0005**. Absorbs #5 (`/yoke:do V3 — execution via agent-team`).

`do` absorbs the surviving "how and where we change the code" working-out from
`task`/`plan`, recorded as a plan artifact under `.yoke/ai/<slug>/`. It then
**auto-detects its mode** from the input and runs accordingly:

- **Inline** — a small task described in chat (e.g. straight after `grill`).
  Plans briefly in chat, executes in the current session, no pause.
- **Sub-agents** — a single issue. Writes a full `<slug>-plan.md`, pauses for
  user confirmation, then executes via the existing executor → reviewer →
  validator → formatter → report pipeline.
- **Team** — a PRD ticket with many sub-issues. Writes a full `<slug>-plan.md`,
  pauses for confirmation, then dispatches a team of agents across the
  sub-issues.

The plan artifact is mode-dependent (short inline vs full file). A wrong mode
guess is caught at the confirmation pause in sub-agents/team modes, so an
auto-detection mistake never triggers an unreviewed costly run.

Finally, move `task` and `plan` into the top-level `deprecated/` directory (out
of auto-discovery) — only now, after `do` has absorbed their logic, so there is
no capability gap. Update `README.md`, `CLAUDE.md` and the catalog.

## Acceptance criteria

- [ ] `do` writes its own "how/where" plan artifact under `.yoke/ai/<slug>/`
- [ ] `do` auto-detects inline vs sub-agents vs team from the input
- [ ] Inline mode plans briefly and executes in-session with no pause
- [ ] Sub-agents and team modes write a full plan artifact and pause for confirmation before any code change
- [ ] Team mode dispatches across the sub-issues of a PRD ticket
- [ ] `task` and `plan` moved to `deprecated/`, no longer auto-discovered
- [ ] `README.md`, `CLAUDE.md`, catalog updated; #5 referenced/closed
- [ ] Manual check: each of the three input shapes triggers the expected mode and pause behavior

## Blocked by

- #18 (S1 — `.yoke/` artifact convention) — uses the `.yoke/ai/` plan-artifact path

---

## S4 — #22 — /yoke:journal skill (.yoke/journal.md memory layer)

**Type:** AFK · **Blocked by:** #18

## Parent

Epic: #17 — yoke 2.0 — Global Refactor

## What to build

A new shipped skill `journal`, invoked manually as `/yoke:journal`, that appends
a short summary of the session's real work to `.yoke/journal.md`. This is the
first layer of yoke's connected memory (journal → artifacts → future git layer).

End-to-end behavior: the user runs `/yoke:journal` at (or during) the end of a
session; the skill writes a concise, newest-first entry describing what was done
and links the relevant `.yoke/ai/<slug>/` artifacts. The entry is an index into
the detail, not a duplicate of it. No hook is used — the trigger is manual, and
the plugin stays hook-free. Running it again appends a new entry without
clobbering earlier ones.

This graduates the existing repo-local `/journal` command into a real, shipped
skill writing to the `.yoke/` convention.

## Acceptance criteria

- [ ] `/yoke:journal` exists as a shipped skill and is auto-discovered
- [ ] It appends a newest-first, concise entry to `.yoke/journal.md`
- [ ] Each entry links the session's relevant `.yoke/ai/<slug>/` artifacts
- [ ] The trigger is manual only — no hook is added
- [ ] Repeated runs append rather than overwrite
- [ ] `README.md`, `CLAUDE.md` and the catalog list the new skill

## Blocked by

- #18 (S1 — `.yoke/` artifact convention) — writes to `.yoke/journal.md`

---

## S5 — #23 — bootstrap rework (scaffold .yoke/)

**Type:** AFK · **Blocked by:** #18

## Parent

Epic: #17 — yoke 2.0 — Global Refactor

## What to build

Rework `bootstrap` to prepare a repository for the 2.0 flow by scaffolding the
`.yoke/` layout and seeding project context.

End-to-end behavior: running `bootstrap` on a fresh repo produces the full
`.yoke/` skeleton (the root, a `context.md` skeleton, an empty `journal.md`, the
`ai/` directory), detects the project's stack, seeds `.yoke/context.md` and the
project context from that detection, and writes or updates `CLAUDE.md` to point
at the `.yoke/` conventions so the agent and every other skill know where things
live. A bootstrapped repo is indistinguishable from a correctly hand-set-up one.

## Acceptance criteria

- [ ] `bootstrap` creates the `.yoke/` skeleton (`context.md`, `journal.md`, `ai/`, `adr/`)
- [ ] It detects the project stack and seeds `.yoke/context.md` / project context
- [ ] It writes/updates `CLAUDE.md` to reference the `.yoke/` conventions
- [ ] A freshly bootstrapped repo matches the layout every other 2.0 skill expects
- [ ] Manual check: on a clean repo, one `bootstrap` run yields a ready-to-use `.yoke/` and a wired `CLAUDE.md`

## Blocked by

- #18 (S1 — `.yoke/` artifact convention) — scaffolds the `.yoke/` layout it defines

---

## S7 — #24 — Release yoke 2.0.0

**Type:** HITL · **Blocked by:** #18, #19, #20, #21, #22, #23

## Parent

Epic: #17 — yoke 2.0 — Global Refactor

## What to build

Cut the **2.0.0** release once all the refactor slices have landed. This is the
capstone: it makes the breaking changes (removed skills, new `.yoke/` artifact
paths) official.

End-to-end: bump `plugin.json` to `2.0.0`, regenerate the public skill catalog
and README/CLAUDE entries to the final shipped set, verify the marketplace
manifest, run the formatter/validation, tag and publish the release. This is a
human-gated step (HITL) — a maintainer decides the release is ready.

Use `/yoke-release` for the mechanics.

## Acceptance criteria

- [ ] `plugin.json` version is `2.0.0`
- [ ] Catalog, `README.md`, `CLAUDE.md` reflect the final 2.0 shipped skill set
- [ ] Marketplace manifest validates (`python3 -c "import json; ..."`)
- [ ] Formatting passes (`pnpm run format:check`)
- [ ] Release tagged and published; breaking changes noted in the release notes
- [ ] Epic #17 checklist of slices is complete

## Blocked by

- #18 (S1 — `.yoke/` convention)
- #19 (S2 — deprecate/relocate skills)
- #20 (S6 — notifications)
- #21 (S3 — do rework)
- #22 (S4 — journal)
- #23 (S5 — bootstrap)
