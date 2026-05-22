#!/usr/bin/env bash
# pr-collect.sh — collect data for a PR (read-only). Emits a structured block.
# Emits file PATHS, not contents; pr-body-generator reads them directly,
# so large artifact content never enters the orchestrator context.

BRANCH=$(git branch --show-current)

DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ -z "$DEFAULT_BRANCH" ]; then
  if git rev-parse --verify origin/main >/dev/null 2>&1; then DEFAULT_BRANCH=main
  elif git rev-parse --verify origin/master >/dev/null 2>&1; then DEFAULT_BRANCH=master
  else DEFAULT_BRANCH=main; fi
fi

SLUG=$(printf '%s' "$BRANCH" | sed -E 's@^(feature|fix|hotfix|bugfix|release)/@@')

TICKET_ID=none
if printf '%s' "$SLUG" | grep -qE '^[0-9]+-'; then
  TICKET_ID="#$(printf '%s' "$SLUG" | grep -oE '^[0-9]+')"
elif printf '%s' "$SLUG" | grep -qE '^[A-Z]+-[0-9]+'; then
  TICKET_ID=$(printf '%s' "$SLUG" | grep -oE '^[A-Z]+-[0-9]+')
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then GH_AUTH=ok; else GH_AUTH=not_authenticated; fi
else
  GH_AUTH=not_installed
fi

PR_EXISTS=false; PR_NUMBER=empty; PR_URL=empty; PR_TITLE=empty
PR_HAS_YOKE_MARKERS=false; PR_BODY_FILE=empty
if [ "$GH_AUTH" = ok ]; then
  PR_META=$(gh pr view --json number,url,title --jq '"\(.number)\t\(.url)\t\(.title)"' 2>/dev/null)
  if [ -n "$PR_META" ]; then
    PR_EXISTS=true
    PR_NUMBER=$(printf '%s' "$PR_META" | cut -f1)
    PR_URL=$(printf '%s' "$PR_META" | cut -f2)
    PR_TITLE=$(printf '%s' "$PR_META" | cut -f3)
    PR_BODY=$(gh pr view --json body --jq .body 2>/dev/null)
    if [ -n "$PR_BODY" ]; then
      PR_BODY_FILE=$(mktemp "${TMPDIR:-/tmp}/yoke-pr-body.XXXXXX")
      printf '%s' "$PR_BODY" > "$PR_BODY_FILE"
      printf '%s' "$PR_BODY" | grep -q '<!-- yoke:start -->' && PR_HAS_YOKE_MARKERS=true
    fi
  fi
fi

find_artifact() { # $1 = suffix (review|report)
  local suffix="$1" latest f
  if [ -f "docs/ai/$SLUG/$SLUG-$suffix.md" ]; then
    printf '%s' "docs/ai/$SLUG/$SLUG-$suffix.md"; return
  fi
  latest=$(ls -td docs/ai/*/ 2>/dev/null | head -1)
  if [ -n "$latest" ]; then
    f=$(ls "${latest}"*-"$suffix".md 2>/dev/null | head -1)
    [ -n "$f" ] && { printf '%s' "$f"; return; }
  fi
  printf 'NOT_FOUND'
}
REVIEW_FILE=$(find_artifact review)
REPORT_FILE=$(find_artifact report)

PR_TEMPLATE=NOT_FOUND
for t in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md docs/pull_request_template.md; do
  [ -f "$t" ] && { PR_TEMPLATE="$t"; break; }
done

RANGE="origin/$DEFAULT_BRANCH..HEAD"
COMMITS_COUNT=$(git rev-list --count "$RANGE" 2>/dev/null || echo 0)
COMMITS=$(git log "$RANGE" --format="  %h %s" 2>/dev/null | head -30)
DIFF_STAT=$(git diff --stat "$RANGE" 2>/dev/null | tail -1 | sed 's/^ *//')
COMMIT_TYPES=$(git log "$RANGE" --format="%s" 2>/dev/null | grep -oE '^[a-z]+' | sort -u | paste -sd, -)

AVAILABLE_LABELS=""
if [ "$GH_AUTH" = ok ]; then
  AVAILABLE_LABELS=$(gh label list --limit 100 --json name --jq '.[].name' 2>/dev/null | sed 's/^/  /')
fi

ERRORS=""
[ -z "$BRANCH" ] && ERRORS="no branch"
[ -n "$BRANCH" ] && [ "$BRANCH" = "$DEFAULT_BRANCH" ] && ERRORS="${ERRORS:+$ERRORS, }on default branch"
[ "$GH_AUTH" != ok ] && ERRORS="${ERRORS:+$ERRORS, }gh: $GH_AUTH"
[ "$COMMITS_COUNT" = 0 ] && [ "$PR_EXISTS" = false ] && ERRORS="${ERRORS:+$ERRORS, }no commits"

cat <<EOF
BRANCH: ${BRANCH:-empty}
DEFAULT_BRANCH: $DEFAULT_BRANCH
SLUG: ${SLUG:-UNKNOWN}
TICKET_ID: $TICKET_ID
GH_AUTH: $GH_AUTH
PR_EXISTS: $PR_EXISTS
PR_NUMBER: $PR_NUMBER
PR_URL: $PR_URL
PR_TITLE: $PR_TITLE
PR_HAS_YOKE_MARKERS: $PR_HAS_YOKE_MARKERS
PR_BODY_FILE: $PR_BODY_FILE
REVIEW_FILE: $REVIEW_FILE
REPORT_FILE: $REPORT_FILE
PR_TEMPLATE: $PR_TEMPLATE
COMMITS_COUNT: $COMMITS_COUNT
COMMITS:
$COMMITS
DIFF_STAT: ${DIFF_STAT:-none}
COMMIT_TYPES: ${COMMIT_TYPES:-none}
AVAILABLE_LABELS:
$AVAILABLE_LABELS
ERRORS: ${ERRORS:-empty}
EOF
