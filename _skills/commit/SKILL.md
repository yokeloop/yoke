---
name: commit
description: 'Create a git commit with automatic ticket prefix extracted from branch name. Use instead of standard /commit when working in this project. Triggers on: /commit, commit changes, create commit.'
---

# Commit with Ticket Prefix

Create a well-formatted git commit with automatic ticket prefix from the current branch name.

## Process

### Step 1. Gather context

Run these commands in parallel using Bash:

```bash
# Get current branch name
git rev-parse --abbrev-ref HEAD

# Show working tree status (NEVER use -uall flag)
git status

# Show staged changes
git diff --staged

# Recent commits for style reference
git log --oneline -5
```

### Step 2. Extract ticket

From the branch name, extract ticket ID matching the regex `^(R[0-9]+-[0-9]+)`.

Examples:

- `R2-32-add-tiket-to-commit-msg-and-pr` → `R2-32`
- `R2-8-update-from-wat` → `R2-8`
- `main` → no ticket

### Step 3. Analyze changes and draft message

Review all staged and unstaged changes. Draft a commit message:

**With ticket:**

```
{TICKET}: {type}: {description}
```

**Without ticket (main, dev, etc.):**

```
{type}: {description}
```

Where `{type}` is one of: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `test`, `ci`.

Guidelines:

- Keep the first line under 72 characters
- Use imperative mood ("add", "fix", "update", not "added", "fixed", "updated")
- Focus on "why" not "what"
- Add a body paragraph only for non-obvious changes

### Step 4. Stage files

Stage relevant files. **Prefer specific file names** over `git add .` or `git add -A`.

Do NOT stage:

- `.env` files or credentials
- Large binary files
- Files unrelated to the current change

### Step 5. Create commit

Use a HEREDOC for the commit message to ensure proper formatting:

```bash
git commit -m "$(cat <<'EOF'
{TICKET}: {type}: {description}

{optional body}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### Step 6. Verify

Run `git status` to confirm the commit was created successfully.

## Important

- Do NOT push to remote — this skill only creates local commits
- Do NOT use `--no-verify` or `--no-gpg-sign` flags
- If a pre-commit hook fails, fix the issue and create a NEW commit (do not amend)
- If there are no changes to commit, inform the user — do not create empty commits
