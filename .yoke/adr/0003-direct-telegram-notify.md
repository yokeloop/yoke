# 3. Direct Telegram send instead of a queued Stop-hook

Date: 2026-05-29

## Status

Accepted

## Context

The original notification system was two layers:

1. `lib/notify.sh` — skills call it at notification points; it writes a single
   JSON object to `.yoke/notify-pending.json` (built and escaped via `jq`,
   written atomically via `mktemp` + `mv`).
2. `hooks/notify.sh` — a **Stop** hook registered in `hooks/hooks.json`. When
   the agent stops, it reads the pending JSON, formats an HTML message, and
   POSTs it to the Telegram Bot API with `curl`. Credentials reach the hook via
   `allowedEnvVars` (`CC_TELEGRAM_BOT_TOKEN`, `CC_TELEGRAM_CHAT_ID`).

This was unreliable in practice:

- **The Stop hook only fires when the agent fully stops.** An
  `ACTION_REQUIRED` notification is meant to ping _before_ an `AskUserQuestion`
  pause — but a question pause is not a Stop, so those notifications almost
  never arrived.
- **The queue is a single file that gets overwritten.** When a skill emits more
  than one notification before the next Stop, only the last survives; the rest
  are silently lost.
- **Two scripts plus a JSON contract plus `jq`** is a lot of moving parts and
  failure points for "send a line of text to Telegram."

Alternatives considered:

- **Keep the queue, fix the Stop-only firing** (e.g. add more hook events) —
  rejected: still clobbers multiple notifications, still depends on `jq` and the
  JSON contract, still indirect.
- **Remove notifications entirely** — considered; rejected because the
  Telegram ping is genuinely useful at `ACTION_REQUIRED` / `STAGE_COMPLETE` /
  `ALERT` points. The problem was the delivery mechanism, not the feature.

## Decision

Collapse to a **single direct-send script** that skills call inline.

- One script at `lib/notify.sh`. It POSTs to the Telegram Bot API
  **immediately** on each call. No queue file, no Stop hook, no `.yoke/`.
- **Drop `jq`.** The payload is form-encoded with
  `curl --data-urlencode text="$MSG"`; `project_name` is `basename "$PWD"`.
  `curl` is the only external dependency.
- **Flags:** `--type`, `--title`, `--body`, `--skill`. (`--slug` is dropped —
  it was never rendered; `--phase` is dropped from the meta line.) The meta
  line is `project / skill`.
- **Credentials** are read straight from the environment
  (`CC_TELEGRAM_BOT_TOKEN`, `CC_TELEGRAM_CHAT_ID`). Skills invoke the script via
  the Bash tool, whose shell is initialized from the user profile, so the
  exported vars are present — no `allowedEnvVars` plumbing needed.
- **Level filter** via optional `CC_NOTIFY_LEVELS` env (e.g.
  `ACTION_REQUIRED,ALERT`); unset means all three types send.
- **Always silent, always exit 0.** Missing credentials, missing `curl`, a
  filtered-out level, or a failed POST never break the calling skill.

Removed: `hooks/notify.sh`, `hooks/hooks.json`, the `hooks/` directory, the
`.yoke/notify-pending.json` queue, and the `jq` dependency. The 14 call sites
across the skills keep calling `lib/notify.sh` but drop `--slug`/`--phase`.

## Consequences

Positive:

- `ACTION_REQUIRED` notifications now actually arrive — the script runs right
  before the question, not on a Stop that may never come.
- No lost notifications: each call delivers independently, nothing is
  overwritten.
- One script, one dependency (`curl`), no JSON contract — far fewer failure
  points.

Negative / costs:

- Notifications now fire from explicit skill call sites only. There is no
  generic "the agent stopped" ping for a plain chat session with no skill
  running (this was an accepted trade for removing the noisy Stop hook).
- Each notification is a synchronous `curl` (bounded by `--max-time`); a slow
  Telegram response adds a small delay at the call site instead of at session
  end.
- Special characters rely on form-encoding rather than `jq`'s JSON escaping;
  `--data-urlencode` handles this for the Bot API.
