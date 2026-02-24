---
name: use-worktree
description: Create an isolated git worktree for a feature branch with full project setup (submodules, deps, env files, .claude folders)
user-invocable: true
---

# Use Worktree

Creates an isolated git worktree with all project-specific setup: submodules, dependencies, env files.

**Usage:** `/use-worktree <branch-name>`

## Steps

### 1. Verify `.worktrees/` is gitignored

```bash
git check-ignore -q .worktrees
```

If NOT ignored, add `.worktrees` to `.gitignore` and tell the user before proceeding.

### 2. Create the worktree from main

**Always branch from `main`**, regardless of current shell CWD or checked-out branch:

```bash
git worktree add .worktrees/<branch-name> -b <branch-name> main
```

If the branch already exists:

```bash
git worktree add .worktrees/<branch-name> <branch-name>
```

### 3. Trust mise config

The project uses `mise` for tool versions (`.mise.toml`). Worktrees get a new path that mise doesn't trust by default:

```bash
mise trust .worktrees/<branch-name>/.mise.toml
```

### 4. Initialize submodules

The project has three submodules: `api/`, `schema/`, `relay/`. They must be initialized in the worktree:

```bash
cd .worktrees/<branch-name>
git submodule update --init --recursive
```

Verify non-empty:

```bash
ls api/package.json schema/ relay/package.json
```

### 5. Copy gitignored config files

The `.claude/` directory (skills, settings) and dev `.env` files are gitignored and must be copied from the main worktree:

```bash
cp -r .claude .worktrees/<branch-name>/.claude
cp api/.env .worktrees/<branch-name>/api/.env
cp relay/.env .worktrees/<branch-name>/relay/.env
```

Use absolute paths from the project root (not from inside the worktree) to avoid copying from another worktree.

### 6. Install dependencies

```bash
cd .worktrees/<branch-name>
just install
```

This runs `pnpm install` for the frontend and API workspace.

For the relay submodule (uses Bun):

```bash
cd .worktrees/<branch-name>/relay
bun install
```

### 7. Verify build

```bash
cd .worktrees/<branch-name>
pnpm build
```

Expected: clean build, zero errors.

### 8. Report

```
Worktree ready:
  Path:       .worktrees/<branch-name>
  Branch:     <branch-name> (from main)
  Submodules: api, schema, relay initialized
  Config:     .claude/ copied
  Env files:  api/.env, relay/.env copied
  Build:      passing
```

## Cleanup

To remove a worktree when done:

```bash
git worktree remove .worktrees/<branch-name>
git branch -d <branch-name>
```

Or if the branch was merged, just remove the worktree — the branch can be deleted after PR merge.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `fatal: '<branch>' already exists` | Branch exists — use `git worktree add .worktrees/<name> <branch>` without `-b` |
| Empty `api/` or `relay/` | Run `git submodule update --init --recursive` inside the worktree |
| Missing `.claude/` skills | Copy from main worktree root: `cp -r .claude .worktrees/<name>/.claude` |
| `api/.env` missing | Copy from main worktree root: `cp api/.env .worktrees/<name>/api/.env` |
| `mise ERROR Config files ... not trusted` | Run `mise trust .worktrees/<name>/.mise.toml` |
| `pnpm: command not found` | Ensure Node.js 22+ and pnpm 10+ are available (check `.mise.toml`) |
| `bun: command not found` | Install Bun: `curl -fsSL https://bun.sh/install \| bash` |
