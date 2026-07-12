# Mode: draft

`/draft` is a do-shaped run — the same inputs as `/do`, the same finish machinery — that marks instead of implementing (ADR-0011, `.yoke/adr/0011-draft-optional-marking-step.md`). It projects the plan onto the code as Markup — `TODO(yoke):` Markers in existing files plus a compilable skeleton for new structure — and opens a GitHub Draft PR for remote review. **`/draft` NEVER pauses: the Draft PR is the pause.** No cold-start confirmation, no AskUserQuestion, no mid-run question — the run always drives to the Draft PR and the notify.

**Flow:**

```
0. Resolve        → input shape + flow map + SLUG/TICKET_ID + worktree (iteration input → Iteration)
1. Plan           → investigate + architect per do's Phase 1 → write <slug>-plan.md; NO confirmation pause
2. Mark           → orchestrator writes the Markup in-session per markup-format.md; build stays green; commit
3. Draft artifact → write <slug>-draft.md (Draft PR URLs, branches, repo set, plan pointer)
4. Finish         → finish.md §3-§5, §7 with --draft: push, one Draft PR per repo, ticket comment, one notify
```

---

## Phase 0 — Resolve input & slug

Accept the same input shapes as `/do`: empty input, a plain chat description, an issue URL, a bare `<slug>`, or a `*-task.md` path.

**Detect iteration first.** When the input is a **Draft PR URL**, or a `<slug>` whose `.yoke/ai/<slug>/<slug>-draft.md` exists, this is a re-run against an existing Draft — skip Phases 1–4 and go to **Iteration** below.

**Read the flow map** per `${CLAUDE_PLUGIN_ROOT}/skills/do/reference/finish.md` §1 (cited below as finish.md). Run the flow-map read once at the project root; hold the repos, finish policies, tracker, and commit language for the marking and the finish.

**Derive `SLUG` and `TICKET_ID`** per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`: issue URL → fetch the issue, build the slug from its number + title; `<slug>` → use directly; `*-task.md` path → take the slug from the `.yoke/ai/<slug>/` directory in the path; chat description → build a slug from the task essence.

**Enter the worktree** per finish.md §2 **immediately** — before any planning output touches disk. `/draft` never pauses, so there is no confirmed-plan moment to defer the entry to; isolate here, one worktree per repo the task will touch.

**Transition:** input resolved → Phase 1 (or → Iteration).

---

## Phase 1 — Plan

Run the **Plan phase of `${CLAUDE_PLUGIN_ROOT}/skills/do/reference/mode-sub-agents.md`** (Phase 1): dispatch `task-investigator` to map the change area, then `plan-architect` to design and decompose, then write `.yoke/ai/<slug>/<slug>-plan.md` per `${CLAUDE_PLUGIN_ROOT}/skills/do/reference/plan-format.md` and auto-commit the artifact with the escape-hatch. Reuse that machinery — do not re-derive it here.

**No confirmation pause follows.** Where sub-agents mode gates on a cold start, `/draft` goes straight to marking: the Draft PR review replaces the gate. The result is safe — Markup only, no implementation — and the user steers on GitHub, not in chat.

**Transition:** plan written and committed → Phase 2.

---

## Phase 2 — Mark

The orchestrator writes the Markup **in-session** — no sub-agents. A `task-executor` is trained to delete the very `TODO(yoke):` markers it would here be asked to write; marking is orchestrator work by design.

Walk the plan's tasks in order and project each onto the code per `reference/markup-format.md`:

- **Existing files** → a `TODO(yoke):` Marker at every change site, optionally carrying the plan step reference (`TODO(yoke): [task 3] …`). One Marker = one unit of future work at that exact spot.
- **New structure** → a compilable skeleton: real files with correct paths, imports, exports, signatures, and types; every body a stub (`throw new Error("TODO")`, `raise NotImplementedError`, `panic("TODO")`, or the language's equivalent) carrying its own Marker.

**The build stays green.** Run the project's type-check/build and fix stubs until it compiles — a working build keeps the LSP alive for the reviewer. Red tests are acceptable; a broken build is not. No implemented logic anywhere — when torn between a stub and a partial implementation, write the stub and a Marker.

Commit the Markup per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`, type `feat` — e.g. `#86 feat(<slug>): mark up <area> for implementation`. Group commits by plan task or area; NO colon after the ticket.

**Transition:** Markup committed, build green → Phase 3.

---

## Phase 3 — Draft artifact

Write `.yoke/ai/<slug>/<slug>-draft.md` — the record a fresh `/do <slug>` session uses to find the Draft. It holds:

- **Draft PR URL(s)** — one per touched repo. Phase 4 creates them, so write the file now with the URLs pending, then update it once the PRs exist.
- **Branch(es)** — the Markup branch in each touched repo.
- **Touched-repo set** — the repos from the flow map this Draft marks.
- **Plan pointer** — the path to `<slug>-plan.md`.

Commit it with the run artifacts (escape-hatch: `.yoke/` gitignored → tell the user and skip the commit).

**Transition:** Draft artifact written → Phase 4.

---

## Phase 4 — Finish (drive to Draft PR)

Hand off to finish.md **§3–§5 and §7**, with `--draft` forced on the pr create call — finish.md §3's "Draft variants" block covers it (`IS_DRAFT: true`, so the PR opens as a GitHub **Draft PR**):

- **Per-repo finish (§3).** For each touched repo: commit remaining run artifacts (including the updated `<slug>-draft.md` once the PR URL exists), push the branch, create the PR **as a draft** through the pr skill's mechanics.
- **Multi-repo order (§4).** Libraries first, then apps; aggregate every Draft PR URL.
- **Ticket comment (§5).** When the tracker ≠ `none`, post one short comment (what was marked + Draft PR links) to the task's ticket.
- **Run-level notify (§7).** Send **one** STAGE_COMPLETE notification, with `--skill draft` and the Draft PR link(s) as the payload:

  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill draft \
    --title "<slug>: Draft PR ready" --body "<Draft PR URL(s)>"
  ```

- **Print the Draft PR link(s)** and stop.

`/draft` never merges and never flips a PR to ready — flipping to ready is `/do` Draft execution's job, after the Markers are implemented and the grep gate passes.

---

## Iteration

A re-run against an existing Draft: the input is a Draft PR URL, or a `<slug>` whose `.yoke/ai/<slug>/<slug>-draft.md` exists (detected in Phase 0). The user commented on the Draft PR; redraw the Markup per the comments. Still no pause.

1. **Read the Draft artifact and the plan** — `<slug>-draft.md` for the PR(s), branch(es), and repo set; `<slug>-plan.md` for the decomposition. Enter the recorded branch(es) per finish.md §2.
2. **Fetch the PR comments** — both kinds:

   ```bash
   gh api repos/{owner}/{repo}/pulls/{pr}/comments   # inline review comments, with ids for replies
   gh pr view <n> --comments                          # top-level conversation comments
   ```

3. **Redraw the Markup in the same branch.** Comments outrank the existing Markers and the plan — the user's latest word wins. Move, rewrite, add, or delete Markers and skeleton per each comment; keep the build green per `reference/markup-format.md`.
4. **Update the plan artifact** when a comment changes the decomposition — `<slug>-plan.md` and the Markup stay one whole. Re-commit it.
5. **Commit and push to the same branch.** The Draft PR updates in place; the pr skill's update path preserves the draft state — never open a second PR.
6. **Reply in every inline review thread** with what changed and where:

   ```bash
   gh api --method POST repos/{owner}/{repo}/pulls/{pr}/comments \
     -f body="<what changed, which file/commit>" -F in_reply_to=<comment-id>
   ```

   Thread resolution stays the user's.

7. **Re-fire the notify** — the same STAGE_COMPLETE call as Phase 4, `--skill draft`, title `<slug>: Draft PR ready`.

Any number of rounds. When the user is ready, `/do <draft-PR-URL>` (or `/do <slug>`) executes the Draft — implements the Markers, replies in threads, flips the PR to ready.

---

## Rules

- **Never pause.** No confirmation gate, no AskUserQuestion — the Draft PR is the pause.
- **Mark, never implement.** No logic anywhere in Markup — Markers plus compilable stubs only, per `reference/markup-format.md`.
- **The build stays green.** Type-check/build must pass on every commit; tests may be red.
- **All artifacts under `.yoke/`.** Plan and Draft artifact both live in `.yoke/ai/<slug>/`.
- **Commits by convention.** Format and ticket ID from `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.
- **Glossary vocabulary.** Draft, Markup, Marker, Draft PR — use the `.yoke/context.md` terms verbatim.
- **Never merge, never flip to ready.** `/draft` ends at the Draft PR; `/do` Draft execution flips it.
- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
