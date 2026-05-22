#!/usr/bin/env bash
# gp-precheck.sh — collect git repository state before push (read-only).
# Emits a structured block for the gp orchestrator to consume. Only collects; decides nothing.

BRANCH=$(git branch --show-current)
[ -z "$BRANCH" ] && BRANCH="DETACHED"

REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

if git rev-parse --verify "@{upstream}" >/dev/null 2>&1; then
  HAS_UPSTREAM=true
else
  HAS_UPSTREAM=false
fi

if [ "$HAS_UPSTREAM" = true ]; then
  UNPUSHED_COUNT=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo 0)
else
  UNPUSHED_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo 0)
fi

UNCOMMITTED_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
UNCOMMITTED_LIST=$(git status --porcelain 2>/dev/null | head -50)

if [ "$BRANCH" = "DETACHED" ]; then
  SLUG="UNKNOWN"
else
  SLUG=$(printf '%s' "$BRANCH" | sed -E 's@^(feature|fix|hotfix|bugfix|release)/@@')
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then GH_AUTH=ok; else GH_AUTH=not_authenticated; fi
else
  GH_AUTH=not_installed
fi

ERRORS=""
[ "$BRANCH" = "DETACHED" ] && ERRORS="detached HEAD"
[ -z "$REMOTE_URL" ] && ERRORS="${ERRORS:+$ERRORS, }no remote"

cat <<EOF
BRANCH: $BRANCH
HAS_UPSTREAM: $HAS_UPSTREAM
REMOTE_URL: ${REMOTE_URL:-empty}
GH_AUTH: $GH_AUTH
UNPUSHED_COMMITS: $UNPUSHED_COUNT
UNCOMMITTED_FILES: $UNCOMMITTED_COUNT
UNCOMMITTED_LIST:
$UNCOMMITTED_LIST
SLUG: $SLUG
ERRORS: ${ERRORS:-empty}
EOF
