#!/usr/bin/env bash
# gp-push.sh — run git push and emit a structured push report.
# Usage: gp-push.sh <BRANCH> <PUSH_MODE>
# PUSH_MODE: normal | set-upstream | force-with-lease
# The only mutation is `git push`; everything else is read-only.

BRANCH="$1"
PUSH_MODE="$2"

BEFORE_SHA=$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo "NEW")
LOCAL_HEAD=$(git rev-parse HEAD)

case "$PUSH_MODE" in
  set-upstream)     PUSH_OUT=$(git push -u origin "$BRANCH" 2>&1); RC=$? ;;
  force-with-lease) PUSH_OUT=$(git push --force-with-lease 2>&1); RC=$? ;;
  *)                PUSH_OUT=$(git push 2>&1); RC=$? ;;
esac

if [ "$RC" -ne 0 ]; then
  cat <<EOF
PUSH_STATUS: FAILED
PUSH_ERROR: $PUSH_OUT
EOF
  exit 0
fi

if [ "$BEFORE_SHA" != "NEW" ]; then
  RANGE="$BEFORE_SHA..$LOCAL_HEAD"
  PUSHED_COUNT=$(git rev-list --count "$RANGE" 2>/dev/null || echo 0)
  PUSHED_LIST=$(git log "$RANGE" --format="  %h %s" 2>/dev/null | head -20)
  DIFF_STAT=$(git diff --shortstat "$RANGE" 2>/dev/null)
else
  PUSHED_COUNT=$(git rev-list --count "$LOCAL_HEAD" 2>/dev/null || echo 0)
  PUSHED_LIST=$(git log "$LOCAL_HEAD" --format="  %h %s" -20 2>/dev/null)
  DIFF_STAT=$(git diff --shortstat "$LOCAL_HEAD" 2>/dev/null)
fi

BRANCH_URL=""
PR_EXISTS=false
PR_URL=""; PR_TITLE=""; PR_NUMBER=""
if command -v gh >/dev/null 2>&1; then
  BRANCH_URL=$(gh browse -n --branch "$BRANCH" 2>/dev/null || echo "")
  PR_META=$(gh pr view --json number,url,title --jq '"\(.number)\t\(.url)\t\(.title)"' 2>/dev/null)
  if [ -n "$PR_META" ]; then
    PR_EXISTS=true
    PR_NUMBER=$(printf '%s' "$PR_META" | cut -f1)
    PR_URL=$(printf '%s' "$PR_META" | cut -f2)
    PR_TITLE=$(printf '%s' "$PR_META" | cut -f3)
  fi
fi

cat <<EOF
PUSH_STATUS: OK
PUSHED_COMMITS: $PUSHED_COUNT
PUSHED_LIST:
$PUSHED_LIST
DIFF_STAT: ${DIFF_STAT:-none}
BRANCH_URL: ${BRANCH_URL:-empty}
PR_EXISTS: $PR_EXISTS
PR_URL: ${PR_URL:-empty}
PR_TITLE: ${PR_TITLE:-empty}
PR_NUMBER: ${PR_NUMBER:-empty}
EOF
