# Draft marking step

**Tracking:** https://github.com/yokeloop/yoke/issues/32

## Problem Statement

The yoke flow gives the user two control points: the plan (grill, or the
cold-start pause in `do`) and the finished pull request. Between them the user
is blind — the plan artifact describes intent in prose, but only the final
diff shows where the change actually lands in the code. By the time the diff
exists, the implementation is done: reviewing it means accepting or rejecting
a finished product, not steering it.

For users who care about the correctness of the logic placement — which
modules change, where new code lives, how the work decomposes — this is too
late. They want to see the picture _from the code's side_ before any
implementation runs, comment on it remotely (from GitHub, from a phone), and
only then release the agent to implement. Today the only workaround is
dictating the structure by hand in chat, which defeats the flow.

The idea follows the marking technique shown by ThePrimeagen
(https://www.youtube.com/watch?v=Aie0nYktsNA): ask the agent to mark the code
with draft comments and TODOs describing what will be written where, instead
of generating the implementation outright.

## Solution

A new optional skill `/draft` — the marking step between grill and do. Draft
is a do-shaped run: it accepts the same inputs as `do` (the result of a grill
session, an issue, any task) and reuses the same finish machinery, but instead
of implementing it projects the plan onto the code as **markup** — `TODO(yoke): …`
markers in existing files plus a skeleton of new files, signatures, and types
with compilable stub bodies — commits, pushes, and opens a GitHub **draft
pull request**.

The user reviews the draft PR remotely and leaves inline comments. Then either
`/draft` runs again to re-mark per the comments (iteration), or `/do` executes
the draft: it implements the markers as a checklist in the same branch and
same PR, treats the user's PR comments as the strongest voice, replies in
every comment thread with what it did, verifies no marker survived, and flips
the PR to ready.

The default path stays grill → do → PR (ADR-0006 stands); draft slots in as a
voluntary control point: grill → draft → PR review → do → ready PR.

## User Stories

1. As a yoke user, I want to run `/draft` after a grill session, so that I see the agreed plan projected onto the actual code before any implementation runs.
2. As a yoke user, I want to run `/draft` on a GitHub issue or a plain chat task, so that the marking step works even when I skipped grill.
3. As a yoke user, I want draft to produce TODO markers in existing files, so that I see exactly which places in the current code will change and why.
4. As a yoke user, I want draft to scaffold new files, signatures, and types with compilable stub bodies, so that I can judge the future structure of the change, not only the touched lines.
5. As a yoke user, I want the skeleton to compile (stubs like `throw new Error('TODO')` / `raise NotImplementedError`), so that types are checked and the draft PR is reviewable with a working LSP; red tests on a draft are acceptable, a broken build is not.
6. As a yoke user, I want draft to commit, push, and open a GitHub draft PR without ever pausing in chat, so that I can start it and walk away — the draft PR itself is the pause.
7. As a yoke user, I want a notification with the draft PR link when marking finishes, so that I can review it from anywhere.
8. As a reviewer, I want to leave inline comments on the draft PR ("not here — extract a module", "no retries, fail fast"), so that I steer the implementation before it exists.
9. As a yoke user, I want to re-run `/draft` on the same slug or PR after commenting, so that the markup is redrawn per my comments in the same branch and PR — as many rounds as I need.
10. As a yoke user, I want to run `/do <draft-PR-URL>` (or `/do <slug>`) from a fresh session, so that the implementation starts from the reviewed draft without me re-explaining anything.
11. As a yoke user, I want my PR comments to outrank the markers and the plan artifact when they conflict, so that my latest word wins without me editing the plan.
12. As a yoke user, I want `do` to stop and ask when a comment overturns the architecture of the plan, so that a fundamental change is not silently improvised.
13. As a reviewer, I want `do` to reply in every comment thread describing what it did and where, so that I can verify each remark was honored without diffing by hand; resolving the threads stays mine.
14. As a yoke user, I want every marker deleted together with its implementation and a final check that none survived, so that no draft comment ever leaks into the ready PR or main.
15. As a yoke user, I want `do` to flip the same PR from draft to ready when the implementation is complete, so that the whole history — markup, my comments, implementation — lives in one place and one diff evolution.
16. As a yoke user, I want draft to write the standard plan artifact under `.yoke/ai/<slug>/`, so that the overall picture (step order, risks, validation) is preserved and `do` gets both the plan and its projection.
17. As a yoke user, I want the draft step to stay optional, so that quick tasks keep the short grill → do path untouched.

## Implementation Decisions

- **A separate skill `/draft`, not a `do` flag.** `do`'s contract is "drive to
  a ready PR"; a `--draft` flag would invert its semantics and is easy to
  forget. Draft is an explicit flow step, mirroring `do`'s architecture
  (router → mode references → finish), and reuses `do`'s finish conventions
  the way `do` reuses gca/gp conventions. Decided in ADR-0011.
- **Same input contract as `do`.** Empty input / plain chat description /
  issue URL / bare slug / task path. Draft auto-detects the shape with the
  same router logic; the grill → draft chain is the primary scenario but not
  a precondition.
- **Draft writes the plan artifact.** Same planning pipeline as `do`'s
  sub-agents mode (investigate → plan), saved under `.yoke/ai/<slug>/`. The
  markup is the plan's projection onto the code; they are one whole, and `do`
  later consumes both.
- **Markup = markers + compilable skeleton.** Markers are single comments in
  the unified format `TODO(yoke): <what will be written here>` (optionally
  carrying the plan step reference). New structure appears as real files,
  signatures, and types whose bodies are stubs that compile. Draft does not
  implement logic — a fully typed scaffold was explicitly rejected as
  "half the implementation accepted blind".
- **Draft never pauses.** No cold-start pause: the result is safe (markup
  only) and the draft PR is the control point. Draft always drives to the
  draft PR and the notify.
- **One PR, draft → ready.** `/draft` opens the PR with `gh pr create
--draft`; `/do` implements in the same branch and PR and flips it with
  `gh pr ready`. A fresh implementation PR was rejected: review comments
  would detach from the code they anchor to.
- **`do` learns one new input shape: the draft.** A draft PR URL routes `do`
  into draft execution; a bare slug whose `.yoke/ai/<slug>/` artifacts record
  a draft PR resolves the same way. The draft artifact (written by `/draft`)
  stores the PR link, branch, and repo set.
- **Priority of voices: PR comments > markers > plan artifact.** Comments are
  the user's latest will and win silently. A comment that overturns the
  architecture (not a local correction) stops the run with a question instead
  of a silent plan rewrite.
- **Marker lifecycle: checklist + final gate.** `do` walks the markers as a
  checklist, deleting each together with its implementation. Before finish, a
  grep for the marker prefix must return nothing; a leftover marker means
  unfinished work and blocks the ready flip.
- **Thread replies.** After implementing, `do` replies in every inline comment
  thread of the draft PR: what was done, in which commit/file. Thread
  resolution is left to the user.
- **Draft iteration.** Re-running `/draft` against the existing draft (slug or
  PR URL) reads the PR comments, updates the markup in the same branch, pushes,
  and replies in the threads. Any number of rounds before `/do`.
- **Multi-repo tasks follow the finish machinery.** Like `do`, draft finishes
  every touched repo per its finish policy from the flow map — one draft PR
  per repo; `do`'s draft execution picks all of them up.
- **Docs already updated.** The glossary (`.yoke/context.md`, "Draft" section
  and flow) and ADR-0011 were written during the grill session that produced
  this PRD. Implementation must also extend the `do` skill docs, the shipped
  skill catalog (sync-docs), README, and CLAUDE.md.

## Testing Decisions

- The repo is a marketplace of markdown skills — there is no unit-test
  harness; quality gates are structural and behavioral, matching prior art
  (yoke 3.0 PRD):
  - `/yoke-validate` on every new or changed `SKILL.md` (Strunk prose +
    plugin-dev conventions).
  - JSON manifest validation (`plugin.json`, `marketplace.json`) stays green.
  - `pnpm run format:check` passes.
- Behavioral acceptance is scenario-driven, exercised via `claude
--plugin-dir .` on a sandbox project:
  - grill → draft produces a draft PR containing only markers + compilable
    stubs (no implemented logic).
  - Comment on the draft PR → `/draft` re-run updates markup and replies in
    threads.
  - `/do <draft-PR-URL>` implements, replies in threads, leaves zero markers
    (grep gate), flips the same PR to ready.
  - `/do` on a conflicting comment vs. marker follows the comment; an
    architecture-overturning comment stops with a question.
- Good tests assert external behavior (PR state, markup presence/absence,
  thread replies), never the internal prompt wording of the skills.

## Out of Scope

- Making draft the default or recommended path — grill → do stays the canon;
  ADR-0006 is not revisited.
- Any `/merge` changes — a ready PR merges exactly as today.
- Auto-resolving PR comment threads or auto-merging.
- Enforcing green CI (tests) on draft PRs; only the build/type gate applies
  to the skeleton.
- CI configuration in target projects (skipping checks for draft PRs etc.).
- The planned `/polish`, `/qa`, `/memorize` skills and the warmup skill.
- Cross-repo fact-owner mechanics beyond what the finish machinery already
  provides.

## Further Notes

- Origin: ThePrimeagen's marking technique
  (https://www.youtube.com/watch?v=Aie0nYktsNA), adapted from "total manual
  control" to yoke's "remote control point" philosophy: the user steers
  logic placement, the agent still implements.
- The user's global zero-comments rule makes the marker lifecycle strict by
  design: markup is a temporary artifact living only between draft and do;
  the grep gate guarantees nothing leaks.
- Glossary terms introduced: **Draft**, **Markup**, **Marker**, **Draft PR**
  (see `.yoke/context.md`); decision record: `.yoke/adr/0011-draft-optional-marking-step.md`.
