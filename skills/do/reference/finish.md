# Finish contract

The shared finish path for every `/do` mode and for `/merge`. A mode calls in here
**after** its tasks are implemented and per-task commits are made; it drives the run
to its pull request(s) and stops. Encodes ADR-0006: `do` drives every run to PR and
never merges — the single exception is §6.

On any `index.lock` contention during a git step, wait briefly and retry the same
command; never abandon the finish over a transient lock.

---

## 1. Read the flow map

At the project root, run once:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/flow-read.sh
```

Parse the emitted `KEY: value` block. Keys: `FLOW_FILE`, `REPO_COUNT`, `REPOS`
(one line per repo: `name | role: … | path: … | finish: … | publish: … | consumers: …`),
`BRANCH_CASCADE`, `CASCADE_STEPS`, `DEPLOY_COMMANDS`, `TRACKER`,
`TRACKER_TARGET_STATE`, `COMMIT_LANGUAGE`, `ARTIFACTS`, `ERRORS`.

`FLOW_FILE: NOT_FOUND` means no flow.md — the script already emitted the defaults
(single repo, `finish: pr`, `TRACKER: none`, committed artifacts). Use them and
**never nag** about a missing file or field.

---

## 2. Worktree entry (run start)

The modes reference this at the start of a run, before touching code.

- **On the repo's default branch** → isolate first:
  - prefer the harness-native worktree (Claude Code `EnterWorktree`) when available;
  - otherwise `git worktree add` under the repo, branch named from the slug;
  - a plain `git switch -c <slug>` is acceptable for a simple single-repo change
    where isolation is not needed.
- **Already on a feature branch or inside a worktree** → work in place.
- **Multi-repo** → enter or create a worktree per repo the task will touch; take
  each repo's checkout `path` from the flow map.

---

## 3. Per-repo finish

After implementation and per-task commits, finish each repo by its `finish` policy:

- **`pr`** — push the branch, then create or update the PR:

  ```bash
  git push -u origin <branch>
  ```

  Create/update the PR through the pr skill's mechanics —
  `${CLAUDE_PLUGIN_ROOT}/skills/pr/SKILL.md`. Do not restate its body generation
  here; invoke its steps.

- **`direct-push`** — commit to the repo's default branch, push, run the declared
  `publish` command, then bump the published version in each repo named in
  `consumers` — as part of that consumer's own change set (i.e. inside the
  consumer's branch and PR, not a stray commit).

---

## 4. Multi-repo orchestration

Order matters. Finish **libraries (`direct-push`) first** so consumers can pin the
freshly published version, **then apps**. Aggregate every PR URL and every published
version across all touched repos for the report (§7).

---

## 5. Ticket comment

When `TRACKER` ≠ `none`, post one short comment (what was done + PR links) to the
task's ticket:

- `github` → `gh issue comment <id> --body "<summary + PR URLs>"`
- `youtrack` → the YouTrack MCP tools when available.
- No tracker, or the tools are unavailable → skip silently.

Status transitions belong to `/merge`, not `do`. Do not move the ticket state here.

---

## 6. Straight-to-main override

The single exception to "never merge" (ADR-0006). When the user **explicitly** asked
for "straight to main" (or equivalent) up front, carry the change all the way through
in the **same run**:

branch → push → `gh pr merge --merge --delete-branch` (or a direct push when the
repo's policy is `direct-push`) → sync the local default branch.

No parking on an open PR, no re-asking. Absent that explicit up-front signal, never
merge — finish at the PR.

---

## 7. Report + notify

Every mode appends this finish block to its report — a per-repo table:

| repo | branch | PR URL / published version |
| ---- | ------ | -------------------------- |

Then send the final notification. The PR link(s) are the payload — the developer
returns on the notification:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh --type STAGE_COMPLETE --skill do \
  --title "<slug>: PR ready" --body "<PR URL(s)>"
```

---

## 8. Boundaries

- `do` never merges, except §6.
- Never run deploy or release commands — those are `/merge`, driven from
  `DEPLOY_COMMANDS` in the flow map.
- Write artifacts only under `.yoke/`.
- Git authorization comes from the skill invocation itself — see "Git initiative and
  defaults" in `${CLAUDE_PLUGIN_ROOT}/skills/gca/reference/commit-convention.md`. Do
  not restate it; do not ask "commit?" mid-run.
