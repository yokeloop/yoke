# yoke 3.0 — Flow to PR

**Tracking:** https://github.com/yokeloop/yoke/issues/28

> **Epic.** This PRD is a parent for a set of sub-issues. Break it down with
> `/yoke:issues`. Sequencing and dependencies are in
> [Implementation Decisions](#implementation-decisions).

## Problem Statement

A month of real usage (78 sessions, 17 projects, 287 skill invocations, logged
2026-06-08 → 2026-07-08) shows the flow works brilliantly up to a point and
then collapses into manual dictation:

- **The funnel gap.** grill-docs → do is the dominant chain (65 occurrences),
  but of 45 sessions with `do`, only 6 reached git-finish through skills. In
  22 sessions the user closed the task by dictating the same tail by voice:
  "commit, push, PR", "merge to main, cascade staging, run the deploy, move
  the ticket, close the worktree" — almost verbatim in 20+ sessions.
- **Per-project rules live in the user's head.** Each project has its own
  finish rules (velvetnet: app via PR, ui-kit via direct push + publish +
  consumer bump; TB-FF: three repos, PR everywhere, then release both; branch
  cascades master → staging → develop; YouTrack as tracker). Nothing in yoke
  stores them, so the user re-dictates every session — and violations of the
  library rule caused visible frustration in at least 5 sessions.
- **Multi-repo work is unsupported.** Two recurring patterns — app + npm
  library, and server + client + shared — require worktrees in several repos
  and several PRs per task. yoke has no concept of this; the user conducts it
  manually ("gca + gp + pr in both apps, if shared changed — push and publish
  the package").
- **Flow gaps leak into agent memory.** 23 process-patch rules accumulated
  across project memories; at least 8 systematic gaps repeat across projects
  (git-initiative boundaries in 5 projects, "don't park on an open PR",
  release chains codified by hand in 3 orgs, local-only `.yoke/` override,
  worktree conventions built entirely outside yoke).
- **Skill form drifted from what works.** grill is 52 lines of intent and
  delivers the plugin's best results; review is 307 lines of step-by-step
  mechanics and never once triggered automatically. Procedural skills go
  stale and get bypassed.

## Solution

Make the default path exactly two verbs, with a clean boundary at the pull
request:

**grill → do → PR.** `do` finishes what it starts: enters a worktree when on
the default branch, implements, commits, pushes, opens the PR(s) per each
repo's finish policy, comments on the ticket — and stops. The user reviews
and decides on GitHub. A single **`/merge`** finisher executes the entire
post-PR tail on explicit command. Project-specific rules move out of the
user's head into a committed, declarative **`.yoke/flow.md`** that every
skill reads instead of asking. All skills are rewritten to the **grill
canon**: compact intent, principles, and boundaries — not scripts.

Decisions are recorded in ADR-0006 (flow ends at PR), ADR-0007 (flow.md),
ADR-0008 (grill canon); vocabulary in `.yoke/context.md`.

## User Stories

1. As a developer, I want `/do` to end with a ready pull request, so that I never dictate "commit, push, PR" again.
2. As a developer, I want `/do` started on the default branch to enter a native worktree by itself, so that "switch to the worktree" stops being a manual step between grill and do.
3. As a developer, I want the plan-confirmation pause skipped when the plan was already agreed in a grill session, so that grill → do runs without a redundant stop.
4. As a developer, I want the plan-confirmation pause kept when `/do` starts cold from a bare ticket, so that I keep one control point when nobody has seen the plan.
5. As a developer, I want each repo's finish policy (PR vs direct push + publish) declared once in `.yoke/flow.md`, so that I never again explain "ui-kit goes straight to master" in every session.
6. As a developer, I want `/do` to orchestrate all repos a task touches — worktrees, edits, and finish per policy in each — so that app + library changes produce their PRs and published versions in one run.
7. As a developer, I want a library's direct-push finish to include publishing the package and bumping its version in consumer repos, so that the integration step stops being manual.
8. As a developer, I want the `/do` report to list every PR link and published version across all touched repos, so that I have one place to start my review from.
9. As a developer, I want `/do` to post a short comment with PR links to the task's ticket, so that teammates see progress without me writing it.
10. As a developer, I want a `/merge` command that merges the task's PR(s), runs cascade merges, deploy/release, moves the ticket, cleans up worktrees, and returns to the default branch — all per `.yoke/flow.md`, so that closing a task is one word instead of a paragraph.
11. As a developer, I want merging to never happen without my explicit command, so that the merge decision stays mine.
12. As a developer, I want an explicit "straight to main" request to carry the change all the way through without parking on an open PR, so that urgent fixes don't stall on ceremony.
13. As a developer, I want git operations inside `/do` and `/merge` authorized by the invocation itself, so that the agent never asks "commit?" mid-run.
14. As a developer, I want the agent to never commit or push on its own initiative outside skill runs, so that unrequested git activity stops appearing.
15. As a developer, I want commit messages in English by default with no trailer lines and no fabricated identity, so that I stop re-writing these rules into every project's memory.
16. As a developer, I want bootstrap to ask once whether `.yoke/` is committed or local-only and record the choice, so that private projects need no memory patches.
17. As a developer, I want every yoke artifact to live strictly under `.yoke/`, so that nothing (WORKLOG.md, yoke-context.md) leaks into my repo root.
18. As a developer, I want review, gca, gp, and pr to remain standalone utilities, so that quick manual commits and targeted reviews still work outside the main flow.
19. As a developer, I want every skill written as compact intent and principles (the grill canon), so that skills stay smart and flexible instead of brittle scripts.
20. As a developer, I want every decision fork inside any skill to be one AskUserQuestion with a recommended option, so that interaction feels like grill everywhere.
21. As a team member, I want flow rules in a committed `.yoke/flow.md` rather than personal agent memory, so that the whole team's agents behave the same way.
22. As a developer, I want `/do` to notify me with the PR URL(s) when the run finishes, so that I start the run and return on notification.

## Implementation Decisions

Grounded in ADR-0006, ADR-0007, ADR-0008. Modules in build order:

1. **`.yoke/flow.md` (new artifact — build first, everything reads it).**
   Declarative per-project flow map: linked repos and roles (app/library),
   finish policy per repo (`pr` | `direct-push`), branch cascade, deploy and
   release commands, ticket tracker, local-only flag for `.yoke/`. Generated
   by bootstrap, refined by grill, consumed by do/merge/gca/gp/pr. A missing
   flow.md degrades gracefully: single-repo, `pr` policy, no tracker steps.
   Parsing must tolerate hand edits — it is a markdown document, not JSON.
2. **`do` finishes at PR.** After the existing per-task review, `do` commits,
   pushes, and opens the PR(s); ends by printing PR links and sending the
   notify with PR URL(s). On the default branch it first enters a native
   worktree named from the slug/ticket; on a feature branch or existing
   worktree it works in place. The plan-confirmation pause fires only on
   cold start (no grill in session, no approved plan). An explicit
   "straight to main" signal from the user overrides the finish policy and
   carries the change through merge in the same run. `do` never merges
   otherwise.
3. **Multi-repo orchestration in `do`.** When the task touches several repos
   from flow.md, `do` drives all of them: worktrees where needed, edits,
   then finish each per its policy — apps via PR, libraries via direct push +
   publish + version bump in consumer repos. Report aggregates all PRs and
   published versions.
4. **`/merge` (new skill, the finisher).** User-triggered only. Reads
   flow.md and executes: merge the task's PR(s) → cascade merges → deploy /
   release commands → ticket transition to the target state → worktree
   cleanup → return to the default branch. Skips any step flow.md does not
   declare.
5. **Ticket integration.** `do` posts a short ticket comment (summary + PR
   links) after creating PRs; `/merge` moves the ticket state. Both silently
   skip when flow.md declares no tracker.
6. **Git defaults in skill conventions** (shared commit-convention
   reference): skill invocation authorizes git inside do/merge; outside
   skill runs, no commit/push on the agent's initiative; commit messages in
   English by default (flow.md / project CLAUDE.md may override); no
   trailer lines ever; never fabricate identity — ask when it is missing.
7. **Local-only mode.** bootstrap asks once: `.yoke/` committed (default) or
   local-only (adds the `.gitignore` line); records the choice in flow.md.
   Invariant regardless of mode: no skill writes artifacts outside `.yoke/`
   (WORKLOG.md and yoke-context.md relocate under `.yoke/`).
8. **Grill canon rewrite.** review, bootstrap, do, pr rewritten to intent +
   principles + boundaries, target ≤100 lines of SKILL.md, mechanics in
   `reference/`. AskUserQuestion-with-recommended-option becomes the
   plugin-wide convention for any fork. review/gca/gp/pr stay in the catalog
   as standalone utilities; their descriptions drop the "after /do" chaining.
   prd/issues are kept, reshaped to the canon, and receive no new features.
9. **Release.** One major release, 3.0 — the flow changes as a whole
   (do → PR is unusable without flow.md; /merge likewise). Work may be
   staged internally, but ships as one version.

## Testing Decisions

The plugin is markdown skills plus `lib/` shell scripts, so "tests" are
validations and sandbox walkthroughs of external behavior, not unit suites:

- Manifest and frontmatter validation as in CLAUDE.md (JSON manifests parse;
  every `SKILL.md` starts with `---`), plus `/yoke-validate` (Strunk +
  skill-development conventions) over every rewritten skill.
- `lib/` scripts (pr-collect.sh, notify.sh, and any new flow.md reader) are
  the deep, isolation-testable modules: exercise them in a throwaway git repo
  — no flow.md, minimal flow.md, multi-repo flow.md, local-only mode — and
  assert on their stdout contracts, following the existing structured-output
  style of `pr-collect.sh`.
- End-to-end sandbox walkthroughs per mode: cold start (pause fires),
  post-grill (no pause), default-branch start (worktree created), feature
  branch (in place), multi-repo app+library (two finishes, one report),
  `/merge` with and without tracker. Verify externally observable results:
  branches, PRs, published dry-run versions, files strictly under `.yoke/`.
- `sync-docs --check` guards the catalog after descriptions change.

## Out of Scope

- Auto-merge or any merge without an explicit user command (ADR-0006).
- Deploy/release orchestration beyond running the commands flow.md declares.
- Reworking prd/issues around YouTrack or any new prd/issues features.
- The git memory layer (commit trailers — issue #2) and the planned /polish,
  /qa, /memorize skills.
- Changes to grill/grill-docs behavior — they already work as intended.
- Enforcing "stage only own files" (declined; worktrees make it moot).

## Further Notes

- Sources: session-log mining (78 sessions, 17 projects, 287 invocations) and
  a sweep of 23 process-patch rules across ~15 project memories, 2026-07-08.
  Decisions: `.yoke/adr/0006-flow-ends-at-pr.md`,
  `0007-flow-md-declarative-flow-map.md`, `0008-skill-form-grill-canon.md`;
  vocabulary in `.yoke/context.md` (flow map, finish policy, cold start,
  local-only mode, finisher).
- This PRD effectively absorbs open issue #6 (`/autopilot` — run the full
  flow end-to-end): the answer is not a wrapper command but `do` finishing
  its own run. Close or link #6 when breaking this down.
- Telemetry from the same logs worth rechecking after 3.0: share of
  do-sessions reaching PR through skills (baseline 6/45), and the count of
  new git-related memory patches (baseline: 5 projects).
