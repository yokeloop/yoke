#!/usr/bin/env bash
# notify.sh — send a Telegram notification directly, inline, on each call.
# Usage: notify.sh --type TYPE --title TITLE --body BODY --skill SKILL
#
# Reads CC_TELEGRAM_BOT_TOKEN and CC_TELEGRAM_CHAT_ID from the environment.
# Optional CC_NOTIFY_LEVELS (comma-separated, e.g. "ACTION_REQUIRED,ALERT")
# filters which types send; unset means all three send.
# Always silent, always exits 0 — a missing dependency, missing credentials,
# a filtered level, or a failed POST never breaks the calling skill.

TYPE=""
TITLE=""
BODY=""
SKILL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --type)  TYPE="$2";  shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --body)  BODY="$2";  shift 2 ;;
    --skill) SKILL="$2"; shift 2 ;;
    --slug | --phase) shift 2 ;; # dropped flags — ignore for back-compat
    *) shift ;;
  esac
done

# Credentials must be present.
[ -n "$CC_TELEGRAM_BOT_TOKEN" ] && [ -n "$CC_TELEGRAM_CHAT_ID" ] || exit 0

# curl is the only external dependency.
command -v curl >/dev/null 2>&1 || exit 0

# Optional level filter.
if [ -n "$CC_NOTIFY_LEVELS" ]; then
  case ",$CC_NOTIFY_LEVELS," in
    *",$TYPE,"*) : ;;
    *) exit 0 ;;
  esac
fi

PROJECT_NAME=$(basename "$PWD")

# Type prefix.
case "$TYPE" in
  ACTION_REQUIRED) ICON="❓" ;;
  STAGE_COMPLETE)  ICON="✅" ;;
  ALERT)           ICON="🚨" ;;
  *)               ICON="🔔" ;;
esac

# Message: "<icon> <title>" / "<project> / <skill>" / "<body>".
MSG="${ICON} ${TITLE}
${PROJECT_NAME} / ${SKILL}"
[ -n "$BODY" ] && MSG="${MSG}
${BODY}"

curl -s --max-time 10 \
  --data-urlencode "chat_id=${CC_TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  "https://api.telegram.org/bot${CC_TELEGRAM_BOT_TOKEN}/sendMessage" \
  >/dev/null 2>&1

exit 0
