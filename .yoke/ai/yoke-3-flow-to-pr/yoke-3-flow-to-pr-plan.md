# Plan: yoke-3-flow-to-pr

**Ticket:** #28 — https://github.com/yokeloop/yoke/issues/28
**Mode:** sub-agents
**Parallel:** true

Implements the PRD (`yoke-3-flow-to-pr-prd.md`, 9 Implementation Decisions) under
ADR-0006 (flow ends at PR), ADR-0007 (flow.md), ADR-0008 (grill canon). PRD-9
(release/version bump) is out of scope — `yoke-release` runs separately.

## Design decisions

- **DD-1** — `.yoke/flow.md` is hand-editable markdown; `lib/flow-read.sh` parses
  it into a `pr-collect.sh`-style `KEY: value` block with graceful defaults
  (single repo, `pr` policy, no tracker, committed). Rejected: JSON/YAML
  (ADR-0007), per-skill inline parsing (drift, untestable).
- **DD-2** — flow.md schema/template doc lives at
  `skills/bootstrap/reference/flow-md.md` (bootstrap generates it); consumers
  link via `${CLAUDE_PLUGIN_ROOT}`, like `commit-convention.md`. Rejected:
  top-level reference dir (no such convention), per-consumer copies.
- **DD-3** — one shared `skills/do/reference/finish.md` holds the entire finish
  contract (worktree entry, per-repo finish, multi-repo aggregation, ticket
  comment, straight-to-main override, notify, `.yoke/`-only boundary); all three
  do modes and /merge read it. Rejected: four-way inlining (the 307-line-review
  failure mode).
- **DD-4** — worktree entry: harness-native worktree when available, portable
  `git worktree add` otherwise; `git switch -c` allowed for simple single-repo
  cases. Rejected: branch-switch only (breaks multi-repo isolation),
  native-only (not portable). — resolved at the confirmation gate.
- **DD-5** — cold-start-only pause: skip Phase 2 confirmation when the session
  had grill / an approved plan / a `*-plan.md` input; keep it on a bare ticket.
- **DD-6** — "straight to main" is the single ADR-0006 exception: do merges
  through in the same run on that explicit signal. Rejected: a flag (it is a
  natural-language signal), auto-merge (forbidden).
- **DD-7** — /merge is a standalone canon skill + `reference/merge-procedure.md`;
  steps come from flow.md declarations; no dedicated mutating lib script.
- **DD-8** — stack context relocates `.claude/yoke-context.md` →
  `.yoke/yoke-context.md`; domain glossary stays `.yoke/context.md`; the
  two-file split (yoke-context-generator.md:11-16) survives.
- **DD-9** — the "no artifacts outside `.yoke/`" invariant is a stated boundary
  in do/merge/bootstrap + finish.md; no enforcement script (WORKLOG.md has zero
  code references — nothing to hunt).
- **DD-10** — inline mode also finishes (lightest path), stays no-pause.
- **DD-11** — canon line budget via new `bootstrap-pipeline.md`,
  `review-procedure.md`, and moving do's Report template to `report-format.md`.
- **DD-12** — PRD-6 git defaults land as one new section in
  `gca/reference/commit-convention.md` (7 files already link it); flow table
  at line 64 updated for finish-at-PR + /merge.
- **DD-13** — yoke-context path fix split by ownership: mechanical task for
  files not otherwise rewritten; folded into the rewrite tasks elsewhere.
- **DD-14** — legacy planning docs (docs/pi-\*.md etc.) untouched (scope).

## Tasks

### Task 1: flow.md schema + template reference

- **Files:** skills/bootstrap/reference/flow-md.md (new)
- **Depends on:** none
- **Scope:** M
- **What:** Canonical `.yoke/flow.md` format: linked repos + roles (app/library) with checkout paths, per-repo finish policy (`pr | direct-push`), branch cascade, deploy/release commands, tracker + target state, local-only flag; graceful-absence defaults; minimal example.
- **How:** Canon prose per grill-docs reference style; field table + example block.
- **Context:** .yoke/adr/0007-\*.md; PRD decisions 1 and 7; .yoke/context.md terms (flow map, finish policy, local-only).
- **Verify:** grep -E 'direct-push|finish policy|local-only|cascade' hits; example flow.md block present.

### Task 2: flow.md reader script

- **Files:** lib/flow-read.sh (new)
- **Depends on:** Task 1
- **Scope:** M
- **What:** Emit structured block (REPOS, ROLES, FINISH_POLICY per repo, BRANCH_CASCADE, DEPLOY_CMD, RELEASE_CMD, TRACKER, TARGET_STATE, LOCAL_ONLY) from `.yoke/flow.md`; missing file/field → defaults.
- **How:** Mirror lib/pr-collect.sh:85-108 contract; read-only; tolerant grep-based parsing; no jq.
- **Context:** lib/pr-collect.sh:1-108; PRD Testing Decisions.
- **Verify:** bash -n; throwaway repo: no flow.md → `FINISH_POLICY: pr`, `TRACKER: none`, `LOCAL_ONLY: false`; minimal flow.md → declared values parsed.

### Task 3: Git defaults in the shared commit contract

- **Files:** skills/gca/reference/commit-convention.md
- **Depends on:** none
- **Scope:** S
- **What:** New "Git initiative & defaults" section: invocation authorizes git inside do/merge; no agent-initiative git outside skill runs; English default (flow.md / project CLAUDE.md override); no trailer lines ever; never fabricate identity — ask. Update the `/do -> /review` flow table (line 62-70) for finish-at-PR + /merge.
- **How:** Extend existing sections; keep anti-patterns.
- **Context:** commit-convention.md:62-70,145-154; PRD decision 6.
- **Verify:** grep -E 'no trailer|fabricate|/merge' hits; old chain phrasing gone.

### Task 4: Shared finish contract

- **Files:** skills/do/reference/finish.md (new)
- **Depends on:** Tasks 1, 2, 3
- **Scope:** L
- **What:** The finish sequence for all do modes + /merge's post-PR half: (a) worktree entry per DD-4; (b) per-repo finish — `pr` → commit+push+gh pr create; `direct-push` → push + publish + consumer version bump; (c) multi-repo loop + aggregation of PR links/versions; (d) ticket comment, silent skip without tracker; (e) straight-to-main override; (f) report + notify.sh with PR URL(s); (g) `.yoke/`-only artifact boundary.
- **How:** Read flow via ${CLAUDE_PLUGIN_ROOT}/lib/flow-read.sh; delegate commit format to commit-convention.md; reference pr/gp mechanics, don't restate.
- **Context:** PRD decisions 2/3/5; ADR-0006; skills/pr/SKILL.md:81-95; lib/notify.sh.
- **Verify:** grep -E 'direct-push|straight to main|flow-read.sh|notify' hits; worktree-on-default + multi-repo documented; no restated pr-body/staging mechanics.

### Task 5: yoke-context relocation (mechanical, non-rewritten files)

- **Files:** skills/do/agents/{formatter,plan-architect,task-executor,task-investigator,validator}.md, skills/do/reference/plan-format.md, skills/review/agents/code-reviewer.md, docs/bootstrap.md
- **Depends on:** none
- **Scope:** M
- **What:** Replace `.claude/yoke-context.md` → `.yoke/yoke-context.md` in exactly these 8 files.
- **How:** Targeted per-file edits; preserve surrounding wording.
- **Context:** DD-8; yoke-context-generator.md:11-16 (split doc).
- **Verify:** grep -rl '\.claude/yoke-context' over these paths → empty; new path present in all 8.

### Task 6: do SKILL canon rewrite

- **Files:** skills/do/SKILL.md
- **Depends on:** Tasks 3, 4
- **Scope:** M
- **What:** ≤100 lines: intent/principles/boundaries; keep router ladder + input shapes; new principles (grill→do→PR, finish at PR, worktree on default, cold-start-only pause, straight-to-main exception, never merges, .yoke/-only); Report template removed (moves in Task 9).
- **How:** grill shape; Rules point at reference/finish.md + commit-convention.md.
- **Context:** skills/do/SKILL.md:1-151; ADR-0008; PRD decisions 2/8.
- **Verify:** wc -l ≤100; head -1 is ---; router intact; no template.

### Task 7: do sub-agents mode — finish + worktree + cold-start pause

- **Files:** skills/do/reference/mode-sub-agents.md
- **Depends on:** Tasks 4, 6
- **Scope:** M
- **What:** Worktree-entry step at start; Phase 2 pause conditional (cold start only); Phase 7 replaced with finish.md call; multi-repo wiring; back-compat \*-plan.md path preserved.
- **How:** Edit phases in place; delegate mechanics to finish.md.
- **Context:** mode-sub-agents.md:103-122, 236-242, 250.
- **Verify:** grep -E 'cold start|finish.md|worktree' hits; "No worktrees" rule gone; back-compat retained.

### Task 8: do team + inline modes — finish integration

- **Files:** skills/do/reference/mode-team.md, skills/do/reference/mode-inline.md
- **Depends on:** Tasks 4, 6
- **Scope:** M
- **What:** Both modes end with finish.md; inline stays no-pause with lightest finish; team keeps per-sub-issue structure.
- **How:** Append finish step referencing finish.md; adjust inline Rules.
- **Context:** mode-inline.md:53-71; ADR-0006 "always finishes".
- **Verify:** grep finish.md in both; inline still no-pause; team dispatch intact.

### Task 9: report-format absorbs Report template + multi-repo rows

- **Files:** skills/do/reference/report-format.md
- **Depends on:** Task 6
- **Scope:** S
- **What:** Full Report template (ex do/SKILL.md:88-151) + per-repo PR-links/published-versions rows + status derivation.
- **How:** Move template; extend Post-implementation section.
- **Context:** old do/SKILL.md:87-151; PRD decision 3 (report aggregates).
- **Verify:** grep -E 'PR link|published|Status derivation' hits.

### Task 10: /merge skill (canon)

- **Files:** skills/merge/SKILL.md (new)
- **Depends on:** Tasks 1, 2, 4
- **Scope:** M
- **What:** New canon skill: description (user-triggered finisher per .yoke/flow.md), intent, principles (never без явной команды; reads flow.md; skips undeclared steps), boundaries; points at reference/merge-procedure.md.
- **How:** grill shape; frontmatter name: merge; triggers "merge", "finish the task", "cascade and deploy".
- **Context:** PRD decision 4; ADR-0006; grill/SKILL.md shape.
- **Verify:** head -1 ---; wc -l ≤100; frontmatter parses; grep 'user-triggered|flow.md'.

### Task 11: /merge procedure reference

- **Files:** skills/merge/reference/merge-procedure.md (new)
- **Depends on:** Tasks 4, 10
- **Scope:** L
- **What:** Mechanics: flow-read.sh → gh pr merge (all task PRs) → cascade merges по declared chain → deploy/release commands → ticket transition to target state → worktree cleanup → return to default. Every step guarded by "skip when not declared".
- **How:** Explicit gh/git commands; minimal visible mutations; reuse finish.md post-PR half by reference.
- **Context:** PRD decisions 4/5; lib/gp-push.sh pattern; finish.md.
- **Verify:** grep -E 'gh pr merge|cascade|target state|flow-read.sh' hits; skip-guards present.

### Task 12: bootstrap canon rewrite + flow.md generation + local-only

- **Files:** skills/bootstrap/SKILL.md, skills/bootstrap/reference/bootstrap-pipeline.md (new)
- **Depends on:** Task 1
- **Scope:** L
- **What:** SKILL ≤100 lines; 7 phases + PROJECT_PROFILE yaml move to bootstrap-pipeline.md; generate .yoke/flow.md (repos/roles/tracker via AskUserQuestion); Phase 6a gitignore fork extended to committed-vs-local-only recorded in flow.md; yoke-context path → .yoke/yoke-context.md; commit flow.md + yoke-context.
- **How:** Canon shape; extend, не дублировать Phase 6a AskUserQuestion.
- **Context:** bootstrap/SKILL.md:301-329; PRD decisions 1/7/8.
- **Verify:** wc -l ≤100; grep 'flow.md|local-only|\.yoke/yoke-context'; pipeline reference holds phases; no old path.

### Task 13: bootstrap agents — write flow.md + relocated stack context

- **Files:** skills/bootstrap/agents/yoke-context-generator.md, skills/bootstrap/agents/bootstrap-verifier.md
- **Depends on:** Tasks 1, 12
- **Scope:** M
- **What:** Generator writes .yoke/yoke-context.md + scaffolds .yoke/flow.md from orchestrator answers (two-file split preserved); verifier checks both.
- **How:** Edit write targets + verifier checklist.
- **Context:** bootstrap/SKILL.md contracts (generator/verifier sections); yoke-context-generator.md:11-16.
- **Verify:** grep '\.yoke/flow.md' in both; no `.claude/yoke-context.md`; split doc intact.

### Task 14: review canon rewrite

- **Files:** skills/review/SKILL.md, skills/review/reference/review-procedure.md (new)
- **Depends on:** none
- **Scope:** L
- **What:** 307 → ≤100 lines; 6-phase pipeline moves to review-procedure.md; template stays in review-format.md; description drops "after /do"; standalone utility.
- **How:** Canon shape; SKILL = intent + boundaries + reference links.
- **Context:** review/SKILL.md:33-307; ADR-0008; PRD decision 8.
- **Verify:** wc -l ≤100; description clean; procedure file holds 6 phases.

### Task 15: pr canon polish + flow awareness

- **Files:** skills/pr/SKILL.md
- **Depends on:** Task 2
- **Scope:** S
- **What:** Description drops "or after /gp"; BASE_BRANCH honors flow.md cascade (default DEFAULT_BRANCH when absent).
- **How:** Minimal edits; flow-read note in Step 2.
- **Context:** pr/SKILL.md:3,42.
- **Verify:** description clean; grep flow hits; frontmatter parses.

### Task 16: gca + gp decoupling + flow awareness

- **Files:** skills/gca/SKILL.md, skills/gp/SKILL.md
- **Depends on:** Tasks 2, 3
- **Scope:** S
- **What:** gca description drops "after /task, /plan, /do, /review" + commit-language-override note; gp description drops "after running /do and /review".
- **How:** Description edits + one Rules line each.
- **Context:** gca/SKILL.md:3; gp/SKILL.md:1-7.
- **Verify:** no old-chain phrases; grep -i flow in gca.

### Task 17: prd + issues canon reshape

- **Files:** skills/prd/SKILL.md, skills/issues/SKILL.md
- **Depends on:** none
- **Scope:** S
- **What:** Reshape to canon shape; no behavior change; trim old-chain phrasing.
- **How:** Light structural edits.
- **Context:** prd/SKILL.md; issues/SKILL.md; PRD decision 8.
- **Verify:** wc -l ≤100 each; frontmatter parses; substance unchanged.

### Task 18: help rewrite + README/CLAUDE manual narrative

- **Files:** skills/help/SKILL.md, README.md, CLAUDE.md
- **Depends on:** Tasks 4, 6, 10, 12, 14
- **Scope:** L
- **What:** help: Full cycle → grill → do → PR (+ /merge); /merge из Planned в актуальные; yoke-context path. README: mermaid flowchart, How to use, Full cycle, Planned — hand-edit вне sentinel-блоков. CLAUDE.md: manual sections (Implemented/Planned skills prose).
- **How:** Only out-of-sentinel content; sentinel blocks остаются Task 21 (sync-docs).
- **Context:** README.md:3-14,33-50,114-158,229; help/SKILL.md:142-165.
- **Verify:** merge в flow-описаниях; Planned без /merge; mermaid = grill→do→PR; sentinels untouched.

### Task 19: detail docs — notify map + docs/merge + docs/do

- **Files:** docs/notify.md, docs/merge.md (new), docs/do.md
- **Depends on:** Tasks 4, 10
- **Scope:** S
- **What:** notify map: do Complete row carries PR URL(s); new /merge rows. docs/merge.md с `**Output:**`. docs/do.md — flow до PR.
- **How:** Table edits; merge doc по образцу docs/pr.md.
- **Context:** docs/notify.md:79-90; sync-docs Output column source.
- **Verify:** grep 'merge|PR URL' в notify.md; Output line в docs/merge.md.

### Task 20: sync-docs count bump 13 → 14

- **Files:** .claude/skills/sync-docs/SKILL.md
- **Depends on:** Task 10
- **Scope:** S
- **What:** "13" → "14" at lines 36, 71, 204, 231; merge in catalog list.
- **How:** Targeted edits.
- **Context:** sync-docs/SKILL.md:36,71-72,204,231.
- **Verify:** counts updated; merge listed.

### Task 21: Validation

- **Files:** tooling run; sync-docs regenerates README/CLAUDE sentinel blocks + site/src/content/docs/skills/\*.mdx (incl. merge.mdx)
- **Depends on:** all
- **Scope:** L
- **What:** (1) JSON manifests + frontmatter checks; (2) yoke-validate over rewritten/new SKILL.md; (3) lib/flow-read.sh in throwaway repo (4 сценария); (4) sandbox mode walkthrough checklist documented; (5) /sync-docs write + --check clean; (6) pnpm run format:check.
- **How:** Per PRD Testing Decisions.
- **Context:** CLAUDE.md Validation; sync-docs check mode.
- **Verify:** all green; wc -l ≤100 on every rewritten SKILL.md; no `.claude/yoke-context.md` in skills/; 14 MDX pages.

## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** one issue, one plan; DAG-driven parallel waves; disjoint file ownership per task (see DD-13); team mode не подходит — нет GitHub sub-issues.
- **Order:**
  - Wave A ‖ T1, T3, T5, T14, T17
  - Wave B ‖ T2, T12
  - Wave C ‖ T4, T13, T15, T16
  - Wave D ‖ T6, T10
  - Wave E ‖ T7, T8, T9, T11
  - Wave F ‖ T18, T19, T20
  - Wave G — T21 (validation, last)
- Critical path: T1 → T2 → T4 → T6/T10 → T18 → T21.

## Verification

- Every rewritten SKILL.md ≤ ~100 lines, frontmatter valid, canon shape.
- `lib/flow-read.sh` contract: defaults without flow.md; declared values with it.
- No `.claude/yoke-context.md` references in shipped skills.
- README/help/CLAUDE describe grill → do → PR (+ /merge); no stale chain.
- `/sync-docs --check` clean; 14 MDX pages; `pnpm run format:check` green.
- PRD decisions 1-8 each traceable to at least one merged change (PRD-9 deferred to yoke-release).
