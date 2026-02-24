---
name: close-worktree
description: Use when done with a feature branch worktree and need to clean it up, merge, or create a PR. Inverse of use-worktree.
user-invocable: true
---

# Close Worktree

Closes a git worktree and handles the associated branch — merge, PR, keep, or discard.

**Usage:** `/close-worktree <worktree-name>`

## Steps

**All commands must run from the project root**, not from inside the worktree. If CWD is inside `.worktrees/<worktree-name>/`, change to the project root first.

### 1. Verify the worktree exists

```bash
git worktree list
```

Confirm `.worktrees/<worktree-name>` appears in the list. If not, tell the user and stop.

### 2. Detect the branch name

```bash
git -C .worktrees/<worktree-name> branch --show-current
```

The branch name usually matches `<worktree-name>`, but verify from git to be safe.

### 3. Check for uncommitted changes

```bash
git -C .worktrees/<worktree-name> status --porcelain
```

If output is non-empty, there are uncommitted changes. Show them to the user and ask via `AskUserQuestion`:

- **Commit them now** — create a commit in the worktree before proceeding
- **Continue anyway** — uncommitted changes will be lost when the worktree is removed

Do not proceed silently — the user must acknowledge uncommitted work.

### 4. Check for changes relative to main

```bash
git log main..<branch> --oneline
```

Count the commits. This determines the next step.

### 4a. No changes — silent cleanup

If `git log` returns **zero commits**, the branch has no work. Remove without asking:

```bash
git worktree remove .worktrees/<worktree-name>
git branch -d <branch>
```

Report:

```
Worktree closed:
  Path:     .worktrees/<worktree-name> (removed)
  Branch:   <branch> (deleted, no changes)
```

**Done.** Skip remaining steps.

### 4b. Changes exist — show commits and ask

Display the commit list to the user, then use `AskUserQuestion` with these 4 options:

1. **Merge into main locally** — merge branch into main, delete branch and worktree
2. **Push and create Pull Request** — push branch, open PR via `gh`, remove worktree (branch stays for PR)
3. **Keep as-is** — leave worktree and branch untouched
4. **Discard branch and all changes** — force-delete branch and worktree (requires confirmation)

### 5. Execute the chosen option

#### Option 1: Merge into main locally

Merge first, clean up after — so on failure the worktree stays intact.

```bash
git checkout main
git pull
git merge <branch>
```

**If merge has conflicts**, abort — the worktree is still alive:

```bash
git merge --abort
```

Tell the user: "Merge conflicts with main. Recommend creating a PR instead (Option 2) where conflicts can be resolved in review."

If merge succeeded, remove worktree and branch:

```bash
git worktree remove .worktrees/<worktree-name>
git branch -d <branch>
```

Report:

```
Worktree closed:
  Merged:   <branch> → main (<N> commits)
  Path:     .worktrees/<worktree-name> (removed)
  Branch:   <branch> (deleted)
```

#### Option 2: Push and create Pull Request

```bash
git -C .worktrees/<worktree-name> push -u origin <branch>
```

Create PR using `gh`:

```bash
gh pr create --head <branch> --base main --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets from commit messages>

## Test plan
- [ ] Verification steps

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Then remove the worktree only (branch must stay for the PR):

```bash
git worktree remove .worktrees/<worktree-name>
```

Report:

```
Worktree closed:
  PR:       <PR URL>
  Path:     .worktrees/<worktree-name> (removed)
  Branch:   <branch> (pushed, kept for PR)
```

#### Option 3: Keep as-is

Do nothing. Report:

```
Worktree kept:
  Path:     .worktrees/<worktree-name>
  Branch:   <branch> (<N> commits ahead of main)
```

#### Option 4: Discard branch and all changes

**Require explicit confirmation** via a second `AskUserQuestion`:

> This will permanently delete **<N> commits** on branch `<branch>`. This cannot be undone. Are you sure?

Options: **Yes, discard everything** / **No, cancel**

If confirmed:

```bash
git worktree remove --force .worktrees/<worktree-name>
git branch -D <branch>
```

Report:

```
Worktree closed:
  Path:     .worktrees/<worktree-name> (removed)
  Branch:   <branch> (force-deleted, <N> commits discarded)
```

If cancelled, fall back to Option 3 (keep as-is).

## Quick Reference

| Option | Merge | Push | Worktree removed | Branch deleted |
|--------|-------|------|------------------|----------------|
| 1. Merge locally | yes | — | yes | yes (`-d`) |
| 2. Create PR | — | yes | yes | no (kept for PR) |
| 3. Keep as-is | — | — | no | no |
| 4. Discard | — | — | yes (`--force`) | yes (`-D`) |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Worktree not in `git worktree list` | Check spelling; run `ls .worktrees/` to see available names |
| `error: branch is not fully merged` on `-d` | Branch wasn't merged — use `-D` only if user chose Option 4 |
| `fatal: '<path>' is a main working tree` | You're targeting the main repo, not a worktree — use `.worktrees/<name>` path |
| Worktree has uncommitted changes | Step 3 should catch this — ask user to commit or acknowledge loss |
| Merge conflicts in Option 1 | Abort merge (`git merge --abort`), suggest Option 2 (PR) instead |
| `gh pr create` fails | Ensure `gh auth status` is logged in and branch is pushed |
| Branch already has an open PR | Show the existing PR URL instead of creating a duplicate |
