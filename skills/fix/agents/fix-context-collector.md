---
name: fix-context-collector
description: >-
  Collects context for fix: mode (post-flow/standalone), slug,
  ticket ID, fix number, paths to yoke flow artifacts.
tools: Bash, Glob, LS
model: haiku
color: cyan
---

# fix-context-collector

Collect fix context and return a structured report.

## Data collection

All commands are read-only. Run them in order.

### Step 1 — Branch

```bash
BRANCH=$(git branch --show-current)
if [ -z "$BRANCH" ]; then
  BRANCH="DETACHED"
fi
```

Determine the default branch via a cascade (analogous to `gp/agents/git-pre-checker.md`):

```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ -z "$DEFAULT_BRANCH" ]; then
  git rev-parse --verify origin/main >/dev/null 2>&1 && DEFAULT_BRANCH="main" || DEFAULT_BRANCH="master"
fi
```

Compare BRANCH with DEFAULT_BRANCH → `IS_DEFAULT_BRANCH: true | false`.

### Step 2 — Mode and slug

Check for yoke flow artifacts:

```bash
# Latest directory in docs/ai/
LATEST_DIR=$(ls -td docs/ai/*/ 2>/dev/null | head -1)
if [ -n "$LATEST_DIR" ]; then
  SLUG=$(basename "$LATEST_DIR")
  MODE="post-flow"
  SLUG_SOURCE="docs_ai"
else
  # From the branch name
  SLUG=$(echo "$BRANCH" | sed -E 's@^(feature|fix|hotfix|bugfix|release)/@@')
  MODE="standalone"
  SLUG_SOURCE="branch"
fi
```

If SLUG is empty or the branch is `main`/`master`/`develop`:

- `SLUG: UNKNOWN`
- `SLUG_SOURCE: none`

### Step 3 — Ticket ID

Extract from slug via a cascade:

- `86-feature-name` → `#86` (regex: `^(\d+)-`)
- `R2-50-feature` → `R2-50` (regex: `([A-Z]\d*-\d+)`)
- `PROJ-123-feature` → `PROJ-123` (regex: `([A-Z]+-\d+)`)
- Otherwise → `none`

### Step 4 — Fix number and fix-log

```bash
FIX_LOG="docs/ai/$SLUG/$SLUG-fixes.md"

if [ -f "$FIX_LOG" ]; then
  # Count ## Fix N: entries
  FIX_COUNT=$(grep -c '^## Fix [0-9]' "$FIX_LOG" 2>/dev/null || echo "0")
  FIX_NUMBER=$((FIX_COUNT + 1))

  # Short list of previous fixes: number + description
  FIX_LOG_SUMMARY=$(grep '^## Fix [0-9]' "$FIX_LOG" 2>/dev/null)
else
  FIX_NUMBER=1
fi
```

### Step 5 — Artifact paths

```bash
TASK_FILE="docs/ai/$SLUG/$SLUG-task.md"
PLAN_FILE="docs/ai/$SLUG/$SLUG-plan.md"
REPORT_FILE="docs/ai/$SLUG/$SLUG-report.md"

# Check existence
[ -f "$TASK_FILE" ] && echo "TASK_FILE: $TASK_FILE" || echo "TASK_FILE: NOT_FOUND"
[ -f "$PLAN_FILE" ] && echo "PLAN_FILE: $PLAN_FILE" || echo "PLAN_FILE: NOT_FOUND"
[ -f "$REPORT_FILE" ] && echo "REPORT_FILE: $REPORT_FILE" || echo "REPORT_FILE: NOT_FOUND"
```

---

## Structured Output

Return data strictly in this format:

```
BRANCH: <branch name | DETACHED>
IS_DEFAULT_BRANCH: <true | false>

MODE: <post-flow | standalone>
SLUG: <value | UNKNOWN>
SLUG_SOURCE: <docs_ai | branch | none>
TICKET_ID: <extracted ID | none>

FIX_NUMBER: <N>
FIX_LOG_EXISTS: <true | false>
FIX_LOG_SUMMARY: <short list of previous fixes: number + description, if any>

TASK_FILE: <path | NOT_FOUND>
PLAN_FILE: <path | NOT_FOUND>
REPORT_FILE: <path | NOT_FOUND>
```

## Rules

- Read-only. Do not modify the repository.
- Command error — record it and continue.
- Return data. The orchestrator makes decisions.
