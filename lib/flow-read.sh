#!/usr/bin/env bash
# flow-read.sh — read .yoke/flow.md and emit a structured block (read-only).
# Parses the declarative flow map (repos, cascade, deploy, tracker, artifacts,
# conventions) with graceful defaults when the file or any field is missing.
# Tolerates hand edits; malformed lines are skipped with a warning, never fatal.
# Always exits 0 — a missing or broken flow.md never fails the orchestrator.
# Usage: flow-read.sh [project-root]   (default project root: .)

ROOT="${1:-.}"
FLOW_PATH="$ROOT/.yoke/flow.md"

REPOS="  current | role: app | path: . | finish: pr | publish: none | consumers: none"
REPO_COUNT=1
BRANCH_CASCADE=none
CASCADE_STEPS="  none"
DEPLOY_COMMANDS="  none"
TRACKER=none
TRACKER_TARGET_STATE=none
COMMIT_LANGUAGE=English
ARTIFACTS=committed
WARNINGS=""
FLOW_FILE_OUT=NOT_FOUND

warn() { WARNINGS="${WARNINGS:+$WARNINGS; }$1"; }

section() { # $1 = lowercase heading regex; prints the section body
  awk -v pat="$1" '
    /^#/ {
      hdr = $0
      sub(/^#+[ \t]*/, "", hdr)
      insec = (tolower(hdr) ~ pat) ? 1 : 0
      next
    }
    insec { print }
  ' "$FLOW_PATH"
}

if [ -f "$FLOW_PATH" ]; then
  FLOW_FILE_OUT="$FLOW_PATH"

  KNOWN_SECTIONS=$(awk '
    /^#/ {
      hdr = $0; sub(/^#+[ \t]*/, "", hdr); h = tolower(hdr)
      if (h ~ /^repos/ || h ~ /^branch cascade/ || h ~ /^deploy/ || \
          h ~ /^tracker/ || h ~ /^artifacts/ || h ~ /^conventions/) c++
    }
    END { print c + 0 }
  ' "$FLOW_PATH")
  [ "$KNOWN_SECTIONS" = 0 ] && warn "no recognizable flow sections; using defaults"

  HAS_REPOS=$(awk '
    /^#/ { hdr = $0; sub(/^#+[ \t]*/, "", hdr); if (tolower(hdr) ~ /^repos/) { print "yes"; exit } }
  ' "$FLOW_PATH")

  REPOS_PARSED=$(section '^repos' | awk '
    function fval(s, key, greedy,   val, re) {
      re = greedy ? key "[ \t]*:[ \t]*.*" : key "[ \t]*:[ \t]*[^,]*"
      if (match(s, re)) {
        val = substr(s, RSTART, RLENGTH)
        sub(key "[ \t]*:[ \t]*", "", val)
        gsub(/[ \t]+$/, "", val)
        return val
      }
      return ""
    }
    function emit(   ) {
      if (name == "") name = "repo"
      printf "  %s | role: %s | path: %s | finish: %s | publish: %s | consumers: %s\n", \
        name, role, path, finish, publish, consumers
    }
    BEGIN { have = 0 }
    /^[ \t]*[-*][ \t]+/ {
      if ($0 ~ /^[-*][ \t]+/) {
        if (have) emit()
        have = 1
        name = ""; role = "app"; path = "."; finish = "pr"; publish = "none"; consumers = "none"
        if (match($0, /\*\*[^*]+\*\*/)) {
          name = substr($0, RSTART + 2, RLENGTH - 4)
        } else {
          n = $0
          sub(/^[ \t]*[-*][ \t]+/, "", n)
          sub(/[ \t]*—.*$/, "", n)
          sub(/[ \t]*,.*$/, "", n)
          gsub(/[ \t]+$/, "", n)
          name = n
        }
        v = fval($0, "role", 0);   if (v != "") role = v
        v = fval($0, "path", 0);   if (v != "") path = v
        v = fval($0, "finish", 0); if (v != "") finish = v
      } else if (have) {
        v = fval($0, "publish", 1);   if (v != "") { gsub(/`/, "", v); publish = v }
        v = fval($0, "consumers", 1); if (v != "") consumers = v
      }
      next
    }
    END { if (have) emit() }
  ')

  if [ -n "$REPOS_PARSED" ]; then
    REPOS="$REPOS_PARSED"
    REPO_COUNT=$(printf '%s\n' "$REPOS_PARSED" | grep -c .)
  elif [ -n "$HAS_REPOS" ]; then
    warn "repos section present but no repos parsed; using default single repo"
  fi

  CASCADE_BODY=$(section '^branch cascade')
  CHAIN=$(printf '%s\n' "$CASCADE_BODY" | awk 'NF && $0 !~ /^[ \t]*[-*]/ { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit }')
  [ -n "$CHAIN" ] && BRANCH_CASCADE="$CHAIN"
  STEPS=$(printf '%s\n' "$CASCADE_BODY" | awk '/^[ \t]*[-*][ \t]+/ { sub(/^[ \t]*/, "  "); print }')
  [ -n "$STEPS" ] && CASCADE_STEPS="$STEPS"

  DEPLOY_BODY=$(section '^deploy')
  DCMDS=$(printf '%s\n' "$DEPLOY_BODY" | awk '/^[ \t]*[-*][ \t]+/ { sub(/^[ \t]*/, "  "); print }')
  [ -n "$DCMDS" ] && DEPLOY_COMMANDS="$DCMDS"

  TRACKER_LINE=$(section '^tracker' | awk 'NF { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit }')
  if [ -n "$TRACKER_LINE" ]; then
    T=$(printf '%s' "$TRACKER_LINE" | sed 's/,.*//; s/[ \t]*$//' | tr '[:upper:]' '[:lower:]')
    case "$T" in
      github | youtrack | none) TRACKER="$T" ;;
      *) warn "unknown tracker '$T'; using none" ;;
    esac
    ST=$(printf '%s' "$TRACKER_LINE" | sed -n 's/.*[Tt]arget [Ss]tate:[ \t]*//p' | sed 's/[ \t]*$//')
    [ -n "$ST" ] && TRACKER_TARGET_STATE="$ST"
  fi

  ART_LINE=$(section '^artifacts' | awk 'NF { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit }')
  if [ -n "$ART_LINE" ]; then
    AL=$(printf '%s' "$ART_LINE" | tr '[:upper:]' '[:lower:]')
    case "$AL" in
      *local-only*) ARTIFACTS=local-only ;;
      *committed*) ARTIFACTS=committed ;;
      *) warn "unknown artifacts value '$ART_LINE'; using committed" ;;
    esac
  fi

  CL=$(section '^conventions' | sed -n 's/.*commit language:[ \t]*//p' | head -1 | sed 's/`//g; s/[ \t]*$//')
  [ -n "$CL" ] && COMMIT_LANGUAGE="$CL"
fi

cat <<EOF
FLOW_FILE: $FLOW_FILE_OUT
REPO_COUNT: $REPO_COUNT
REPOS:
$REPOS
BRANCH_CASCADE: $BRANCH_CASCADE
CASCADE_STEPS:
$CASCADE_STEPS
DEPLOY_COMMANDS:
$DEPLOY_COMMANDS
TRACKER: $TRACKER
TRACKER_TARGET_STATE: $TRACKER_TARGET_STATE
COMMIT_LANGUAGE: $COMMIT_LANGUAGE
ARTIFACTS: $ARTIFACTS
ERRORS: ${WARNINGS:-none}
EOF

exit 0
