#!/usr/bin/env bash
# gst-collect.sh — collect git repository status for /gst (read-only).
# Emits a structured block; the orchestrator formats the report and writes the summary.

# --- Branch context ---
BRANCH=$(git branch --show-current)
DETACHED=false
if [ -z "$BRANCH" ]; then
  DETACHED=true
  BRANCH=$(git describe --tags --always --abbrev=8 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

EMPTY_REPO=false
git rev-parse HEAD >/dev/null 2>&1 || EMPTY_REPO=true

# --- Upstream ahead/behind ---
AHEAD=0; BEHIND=0; HAS_UPSTREAM=false
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)
if [ -n "$UPSTREAM" ]; then
  HAS_UPSTREAM=true
  RL=$(git rev-list --left-right --count "HEAD...@{upstream}" 2>/dev/null)
  if [ -n "$RL" ]; then
    AHEAD=$(printf '%s' "$RL" | awk '{print $1}')
    BEHIND=$(printf '%s' "$RL" | awk '{print $2}')
  fi
fi

# --- Default branch ---
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ -z "$DEFAULT_BRANCH" ]; then
  if git rev-parse --verify origin/main >/dev/null 2>&1; then DEFAULT_BRANCH=main
  elif git rev-parse --verify origin/master >/dev/null 2>&1; then DEFAULT_BRANCH=master
  else DEFAULT_BRANCH=main; fi
fi
ON_DEFAULT_BRANCH=false
[ "$BRANCH" = "$DEFAULT_BRANCH" ] && ON_DEFAULT_BRANCH=true

# --- Merge base vs default ---
MERGE_BASE=$(git merge-base HEAD "origin/$DEFAULT_BRANCH" 2>/dev/null || echo "")
[ -z "$MERGE_BASE" ] && MERGE_BASE="NONE"

# --- Working tree counts ---
STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
UNSTAGED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
SHORTSTAT=$(git diff HEAD --shortstat 2>/dev/null | sed 's/^ *//')

# --- Merge conflicts ---
CONFLICTS=$(git diff --name-only --diff-filter=U 2>/dev/null | sed 's/^/  /')

# --- Diff vs merge-base: changed files (status + numstat), hot files, commit count ---
CHANGED_FILES=""; HOT_FILES=""; COMMITS_COUNT=0
if [ "$MERGE_BASE" != "NONE" ]; then
  CHANGED_FILES=$(awk -F'\t' '
    NR==FNR { status[$NF]=substr($1,1,1); next }
    { a=($1=="-"?0:$1); d=($2=="-"?0:$2); s=(status[$3]==""?"M":status[$3]);
      printf "  %s %s (+%s -%s)\n", s, $3, a, d }
  ' <(git diff --no-renames --name-status "$MERGE_BASE"..HEAD 2>/dev/null) \
    <(git diff --no-renames --numstat "$MERGE_BASE"..HEAD 2>/dev/null) | head -50)
  HOT_FILES=$(git diff --no-renames --numstat "$MERGE_BASE"..HEAD 2>/dev/null | awk -F'\t' '
    { a=($1=="-"?0:$1); d=($2=="-"?0:$2); print a+d, a, d, $3 }
  ' | sort -rn | head -3 | awk '{ printf "  %s — +%s -%s\n", $4, $2, $3 }')
  COMMITS_COUNT=$(git rev-list --count "$MERGE_BASE"..HEAD 2>/dev/null || echo 0)
fi

# --- Commits: range from merge-base, else last 5 ---
if [ "$MERGE_BASE" != "NONE" ] && [ "$COMMITS_COUNT" -gt 0 ]; then
  COMMITS=$(git log "$MERGE_BASE"..HEAD --format="%h|%s|%cr|%an" 2>/dev/null | head -20 | sed 's/^/  /')
else
  COMMITS=$(git log --format="%h|%s|%cr|%an" -5 2>/dev/null | sed 's/^/  /')
fi

# --- Stash ---
STASH=$(git stash list 2>/dev/null | head -10 | sed 's/^/  /')
STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF
DETACHED: $DETACHED
EMPTY_REPO: $EMPTY_REPO
BRANCH: $BRANCH
HAS_UPSTREAM: $HAS_UPSTREAM
UPSTREAM: ${UPSTREAM:-none}
AHEAD: $AHEAD
BEHIND: $BEHIND
DEFAULT_BRANCH: $DEFAULT_BRANCH
ON_DEFAULT_BRANCH: $ON_DEFAULT_BRANCH
MERGE_BASE: $MERGE_BASE
STAGED: $STAGED
UNSTAGED: $UNSTAGED
UNTRACKED: $UNTRACKED
SHORTSTAT: ${SHORTSTAT:-none}
COMMITS_COUNT: $COMMITS_COUNT
STASH_COUNT: $STASH_COUNT
CONFLICTS:
$CONFLICTS
CHANGED_FILES:
$CHANGED_FILES
HOT_FILES:
$HOT_FILES
COMMITS:
$COMMITS
STASH:
$STASH
EOF
