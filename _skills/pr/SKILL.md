---
name: pr
description: 'Commit, push, and create a GitHub PR with automatic ticket prefix from branch name. Use instead of standard /commit-push-pr. Triggers on: /pr, create PR, open pull request, push and create PR.'
argument-hint: '[base-branch]'
---

# PR with Ticket Prefix

Commit pending changes, push to remote, and create a GitHub pull request with automatic ticket prefix from the current branch name.

`$ARGUMENTS` optionally specifies the base branch (default: `main`).

## Process

### Step 1. Gather context

Run these commands in parallel using Bash:

```bash
# Get current branch name
git rev-parse --abbrev-ref HEAD

# Show working tree status (NEVER use -uall flag)
git status

# Show staged and unstaged changes
git diff
git diff --staged

# Check if branch tracks a remote
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "no-upstream"

# Recent commits for style reference
git log --oneline -5

# Full diff from base branch
git diff main...HEAD
```

### Step 2. Extract ticket

From the branch name, extract ticket ID matching the regex `^(R[0-9]+-[0-9]+)`.

Examples:

- `R2-32-add-tiket-to-commit-msg-and-pr` → `R2-32`
- `main` → no ticket

### Step 3. Commit if needed

If there are uncommitted changes (staged or unstaged):

1. Stage relevant files (prefer specific file names over `git add .`)
2. Create commit using the ticket prefix format:

```bash
git commit -m "$(cat <<'EOF'
{TICKET}: {type}: {description}

{optional body}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

If no uncommitted changes, skip to Step 4.

### Step 4. Push to remote

```bash
git push -u origin HEAD
```

### Step 5. Create PR

Analyze ALL commits on the branch (not just the latest) using `git log main...HEAD` and `git diff main...HEAD`.

**With ticket:**

```bash
gh pr create --title "{TICKET}: {description}" --body "$(cat <<'EOF'
## Summary
- bullet points describing changes

## Ticket
https://tracker.flyingfish.ai/issue/{TICKET}

## Test plan
- [ ] testing steps

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Without ticket (main-like branch):**

```bash
gh pr create --title "{description}" --body "$(cat <<'EOF'
## Summary
- bullet points describing changes

## Test plan
- [ ] testing steps

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Step 6. Report

Print the PR URL so the user can review it.

## Important

- Do NOT use `--no-verify` or `--no-gpg-sign` flags
- Do NOT force push (`--force`) unless explicitly asked
- If pre-commit hook fails, fix the issue and create a NEW commit
- The PR title should be concise (under 70 characters)
- The PR body should summarize ALL commits on the branch, not just the last one
