# Mode: draft execution

The mode that consumes a **Draft**. `/draft` projected the plan onto the code as Markup — `TODO(yoke):` Markers plus a compilable skeleton — and opened a GitHub Draft PR; the user reviewed it and left comments. This mode implements the Markup per that review, replies in the threads, and flips the **same** PR to ready. One PR carries the whole history from markup to ready — never a second PR (ADR-0011). ADR-0006 stands: the run still ends at a PR; flipping draft → ready is not a merge.

The router (`skills/do/SKILL.md`) delegates here when the input is a Draft PR URL or a slug whose artifacts record a Draft. The Markup contract — Marker format, skeleton rules, grep-gate scope — lives in `${CLAUDE_PLUGIN_ROOT}/skills/draft/reference/markup-format.md`; read it before Phase 1.

**Flow:**

```
0. Resolve   → Draft artifact + gh pr view (isDraft guard) → worktree on the Draft branch (finish.md §2)
1. Gather    → three voices: plan artifact + Markers in code + PR review comments (comments win)
2. Execute   → each Marker = a checklist item → task-executor per Marker, review loop per status-protocol.md
3. Reply     → answer every inline review thread + one summary comment; never resolve threads
4. Grep gate → grep source for TODO(yoke): — any hit blocks the ready flip
5. Validate  → validator + formatter (mode-sub-agents.md Phase 4) → report (its Phase 6, report-format.md)
6. Finish    → finish.md §3: UPDATE the same Draft PR, then gh pr ready → ticket comment §5 → notify §7
```

Track every phase in TodoWrite.

---

## Phase 0 — Resolve

Accept one input from the router: a **Draft PR URL** (contains `/pull/`) or a bare `<slug>` whose `.yoke/ai/<slug>/<slug>-draft.md` exists — the router already discriminated.

**1. Read the Draft artifact** `.yoke/ai/<slug>/<slug>-draft.md`: the Draft PR URL(s), branch(es), repo set, and the plan pointer. With a PR URL input, derive the slug from the head branch, then read the same artifact.

**2. Inspect the PR:**

```bash
gh pr view <url> --json isDraft,number,headRefName,url
```

If `isDraft` is already `false`, warn the user and continue as a plain update run — the flip already happened; a re-run stays idempotent.

**3. Check out the Draft branch.** Enter the worktree per `reference/finish.md` §2 — the branch already exists, so enter or attach a worktree on it. Never work on the default branch.

**4.** Derive `SLUG` and `TICKET_ID` per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`.

**Transition:** Draft resolved, worktree entered → Phase 1.

---

## Phase 1 — Gather the three voices

Collect the three inputs that define the work:

- **(a) The plan artifact** — `.yoke/ai/<slug>/<slug>-plan.md`: design decisions, task decomposition, Verify criteria.
- **(b) The Markers in code** — `grep -rn "TODO(yoke):"` over the repo source. Scope per markup-format.md: exclude `.yoke/` and documentation that mentions the literal.
- **(c) The PR review comments** — inline threads: `gh api repos/{owner}/{repo}/pulls/{pr}/comments`; top-level: `gh pr view <n> --comments`.

**Priority of voices: PR comments > Markers > plan artifact.** A comment is the user's latest will and wins silently over a Marker or a plan step — do not ask, do not reconcile in chat.

**Exception — a comment that overturns the plan's architecture.** Not a local correction but a structural reversal ("different module boundary", "drop the whole approach"): stop and ask via AskUserQuestion instead of silently rewriting the plan:

1. **Re-draft per the comment (Recommended)** — end this run; the user re-runs `/draft` so the Markup is redrawn per the comment.
2. **Proceed as commented** — implement per the comment, treating it as the new plan.
3. **Cancel** — stop; no code changes.

This is the mode's only possible pause.

**Transition:** voices gathered, conflicts resolved by priority → Phase 2.

---

## Phase 2 — Execute the checklist

Read `reference/status-protocol.md` — statuses, the review loop via `agents/task-reviewer.md`, model escalation, parallel dispatch. Do not duplicate its rules here.

Each Marker — adjusted by any overriding comment — is one checklist item. For each, build a task and dispatch `agents/task-executor.md` verbatim:

- **What** = the Marker text + the relevant plan step + the overriding comment, when one exists.
- **Files** = the Marker's file and its skeleton counterparts.
- **Verify** = from the plan.
- **COMMIT_MESSAGE** per `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md` — one commit per task.

The executor deletes each Marker together with its implementation — a Marker is consumed, never left behind.

Dispatch parallel groups when Markers touch disjoint files, sequentially otherwise — per `reference/status-protocol.md`.

**Multi-repo.** Pick up every Draft PR from the Draft artifact; run the checklist per repo, finish order per `reference/finish.md` §4.

**Transition:** checklist done (or BLOCKED recorded) → Phase 3.

---

## Phase 3 — Thread replies

After implementing, reply in **every** inline review thread describing what was done and in which commit:

```bash
gh api --method POST repos/{owner}/{repo}/pulls/{pr}/comments \
  -f body="<what was done + commit>" -F in_reply_to=<comment-id>
```

Address top-level PR comments in one summary comment (`gh pr comment`).

Thread resolution stays the user's — **never resolve threads**.

**Transition:** every thread answered → Phase 4.

---

## Phase 4 — Grep gate (hard block)

Before finishing, grep the source for `TODO(yoke):` — scope per `${CLAUDE_PLUGIN_ROOT}/skills/draft/reference/markup-format.md` (exclude `.yoke/` and docs mentioning the literal).

**Any hit = unfinished work.** Implement it or mark the task BLOCKED. The ready flip is blocked until the grep is clean — this gate is hard, with no override.

**Transition:** grep clean → Phase 5.

---

## Phase 5 — Validate + report

Run `reference/mode-sub-agents.md` Phase 4: validator + formatter in parallel. Then its Phase 6: write `.yoke/ai/<slug>/<slug>-report.md` per `reference/report-format.md`. Reuse both by citation — do not restate them here.

**Transition:** validated, report written → Phase 6.

---

## Phase 6 — Finish (flip to ready)

Execute `reference/finish.md` §3: the pr mechanics **UPDATE the existing Draft PR** — never create a second one; the update path keeps the draft state. Then flip:

```bash
gh pr ready <number>
```

- **Ticket comment (§5)** — when a tracker is configured, one short comment: what was done + the now-ready PR URL.
- **Finish block + notify (§7)** — append the per-repo table to the report and commit it; send the **single** STAGE_COMPLETE notification, title `<slug>: PR ready`, body = the now-ready PR URL(s).
- **Mark the Draft consumed.** Update the status line in `.yoke/ai/<slug>/<slug>-draft.md` to executed and commit it, so a router re-run treats the slug as consumed. The artifact stays for history.

Print the PR link(s) and stop.

---

## Rules

- **PR comments > Markers > plan.** The user's latest will wins silently.
- **One pause only.** An architecture-overturning comment (Phase 1); everything else runs without stops.
- **Every Marker deleted with its implementation.** A Marker is consumed, never left behind.
- **The grep gate blocks the ready flip.** A clean `TODO(yoke):` grep is a hard precondition for `gh pr ready`.
- **Never a second PR.** Implement in the same branch and same Draft PR (ADR-0011).
- **Never merge.** Flipping draft → ready ends the run at a PR; it is not a merge (ADR-0006).
- **All artifacts under `.yoke/`.** The Draft artifact, plan, and report live in `.yoke/ai/<SLUG>/`.
- **Context isolation.** A task-executor receives only its own task text, not the whole plan or comment set.
- Language: match the ticket/input language, or follow the project-level definition in CLAUDE.md / AGENTS.md.
