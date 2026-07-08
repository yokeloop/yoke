# Merge procedure

The finisher mechanics `/merge` routes to — merge, cascade, deploy, transition,
clean up. Runs **only on the explicit user command**. Each numbered step runs
**only when the flow map declares its data**; otherwise skip it silently (omission
means "apply the default", never "fail"). On any `index.lock` contention during a
git step, wait briefly and retry the same command — never abandon the finish over a
transient lock.

---

## 0. Resolve the task's PRs

From `$ARGUMENTS`:

- **PR URL(s)** → those are the PRs to merge.
- **A `<slug>`** → find the open PR(s) by branch:
  `gh pr list --head <branch> --json number,url,state`.
- **Empty** → the current branch/worktree's task. Per repo run
  `gh pr view --json number,url,state`; multi-repo → resolve each repo's PR from the
  flow map's `REPOS` list, using each repo's `path`.

Report what will be merged **before** acting. When more than one PR, or any
ambiguity (unclear branch, several open PRs, an unclear target), ask once — one
AskUserQuestion with a recommended **"Merge all listed"** option first. A single
unambiguous PR needs no question: the `/merge` invocation is itself the command.

---

## 1. Read the flow map

At the project root, run once:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/flow-read.sh
```

Parse the emitted `KEY: value` block — keys as in `finish.md` §1 (`FLOW_FILE`,
`REPOS`, `CASCADE_STEPS`, `DEPLOY_COMMANDS`, `TRACKER`, `TRACKER_TARGET_STATE`, …).
`FLOW_FILE: NOT_FOUND` means the script already emitted the defaults; use them and
never nag about a missing file or field. Every step below reads its guard from this
block.

---

## 2. Merge PR(s)

Runs on the PR set resolved in §0. Merge each and wait for it to complete before
the next step:

```bash
gh pr merge <n> --merge --delete-branch
```

Multi-repo → merge every one of the task's PRs. **Libraries have no PRs** — `do`
direct-pushed them; skip them, there is nothing to merge there.

---

## 3. Cascade

Runs **only when `CASCADE_STEPS` ≠ `none`**; otherwise skip. For each step in
`CASCADE_STEPS`, run its declared command verbatim, in order — the steps encode the
branch advancement (e.g. master → staging → develop). On a merge conflict: **stop
the cascade, report, do not force** — never a merge strategy override, never
`--force`.

---

## 4. Deploy / release

Runs **only when `DEPLOY_COMMANDS` ≠ `none`**; otherwise skip. Run each command in
`DEPLOY_COMMANDS` verbatim, in order. Never infer, synthesize, or reorder a
command — run exactly what the flow map declares, nothing else.

---

## 5. Ticket transition

Runs **only when `TRACKER` ≠ `none`**; otherwise skip silently. Move the task's
ticket to `TRACKER_TARGET_STATE`, then add a one-line comment `merged: <PR URLs>`:

- `github` → close the issue when the target state is closure
  (`gh issue close <id>`), else apply the state label; then
  `gh issue comment <id> --body "merged: <PR URLs>"`.
- `youtrack` → transition the state via the YouTrack MCP tools, then add the same
  comment.

No tracker configured, or the tools unavailable → skip silently.

---

## 6. Worktree cleanup + return to the default branch

Skip when the task used no worktree. For each worktree the task used:

- Remove it — the harness-native `ExitWorktree` when available, else
  `git worktree remove <path>`.
- **Never remove a worktree with uncommitted changes** — report it and leave it in
  place.

Then land the main checkout on the default branch and sync the merged state:

```bash
git switch <default-branch>
git pull
```

Multi-repo → repeat per repo, taking each checkout `path` from `REPOS`.

---

## 7. Report + notify

Print what was merged / cascaded / deployed / transitioned — one line each. Then
send the terminal notification:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill merge \
  --title "<slug>: merged" --body "<merged PR(s) + cascade + deploy/release summary>"
```

---

## Boundaries

- **Runs only on the explicit user command.** No auto-trigger after `do` — the
  merge decision stays the user's.
- **Every step is skip-guarded by a flow-map declaration.** A step whose data the
  flow map does not declare is skipped without nagging.
- **Git authorization** comes from the `/merge` invocation itself — see "Git
  initiative and defaults" in
  `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`. Do not restate
  it; do not ask "merge?" mid-run.
- **On any failed step — stop, report, and never improvise recovery that rewrites
  history** (no force-push, no reset, no conflict-strategy override).
