# Telegram notifications

Skills call `${CLAUDE_PLUGIN_ROOT}/lib/notify.sh` inline and it POSTs directly to the Telegram Bot API via `curl`. No queue file, no stop hook, no `jq` required. Notifications are opt-in — without the env vars the system silently skips sending.

---

## Setup

### 1. Create a bot

- Open [@BotFather](https://t.me/BotFather) in Telegram
- Send `/newbot` and follow the prompts
- Save the resulting token (format `123456789:ABC...`)

### 2. Get the chat_id

- Send any message to your bot
- Call the API:
  ```bash
  curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates"
  ```
  Look for `.result[0].message.chat.id` in the JSON response and save the value.

### 3. Set environment variables

Add to `~/.zshrc` (or `~/.bashrc`):

```bash
export CC_TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
export CC_TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
```

Then reload the shell: `source ~/.zshrc`

### 4. Filter by level (optional)

By default all three notification types are sent. To receive only a subset, set:

```bash
export CC_NOTIFY_LEVELS="ACTION_REQUIRED,ALERT"
```

Any type not in the list is silently suppressed.

---

## Notification types

| Type            | Marker | When it fires                              |
| --------------- | ------ | ------------------------------------------ |
| ACTION_REQUIRED | ❓     | Before questions that require an answer    |
| STAGE_COMPLETE  | ✅     | Task, plan, PR, or other artifact is ready |
| ALERT           | 🚨     | Block, scope guard, critical situation     |

---

## Behavior

- **Silent**: `notify.sh` never prints output; always exits 0.
- **No-op conditions**: missing `CC_TELEGRAM_BOT_TOKEN` or `CC_TELEGRAM_CHAT_ID`, `curl` not found, or the notification type filtered out by `CC_NOTIFY_LEVELS`.
- **Bounded**: the `curl` call runs with `--max-time 10`. If the request times out or fails, the script exits 0 and the session continues normally.
- **Message meta line**: `project / skill` where `project` is `basename "$PWD"`.

---

## Flags

| Flag      | Required | Values                                           |
| --------- | -------- | ------------------------------------------------ |
| `--type`  | yes      | `ACTION_REQUIRED` \| `STAGE_COMPLETE` \| `ALERT` |
| `--title` | yes      | Short heading shown in the notification          |
| `--body`  | yes      | Detail text                                      |
| `--skill` | yes      | Skill name (e.g. `do`, `pr`, `review`)           |

---

## Notification point map

| Skill     | Phase    | Type            | Description                                                       |
| --------- | -------- | --------------- | ----------------------------------------------------------------- |
| bootstrap | Confirm  | ACTION_REQUIRED | Bootstrap ready — confirm phase                                   |
| bootstrap | Complete | STAGE_COMPLETE  | Bootstrap complete                                                |
| do        | Execute  | ALERT           | Task blocked                                                      |
| do        | Finish   | STAGE_COMPLETE  | `<slug>: PR ready` — PR URL(s) as the payload                     |
| merge     | Finish   | STAGE_COMPLETE  | `<slug>: merged` — merged / cascade / deploy / transition summary |
| pr        | Decide   | ACTION_REQUIRED | Choose PR type (draft/ready)                                      |
| pr        | Complete | STAGE_COMPLETE  | PR created or updated                                             |
| review    | Scope    | ACTION_REQUIRED | Found N issues — select scope                                     |
| review    | Complete | STAGE_COMPLETE  | Review complete                                                   |
| sync-docs | Complete | STAGE_COMPLETE  | Skill catalog regenerated                                         |

`do` fires its completion notify from the finish contract (`skills/do/reference/finish.md` §7),
not from the Finalize phase — the PR link(s) are the payload the developer returns on. `/merge`
fires its own STAGE_COMPLETE from the merge procedure (`skills/merge/reference/merge-procedure.md` §7)
once the post-PR tail is done.

---

## Example call

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh \
  --type STAGE_COMPLETE \
  --skill do \
  --title "112-password-reset: PR ready" \
  --body "https://github.com/org/repo/pull/42"
```

---

## Dependencies

- **curl** — for HTTP requests to the Telegram Bot API (required; if missing, script exits 0)

No `jq` dependency. The script constructs the JSON payload with plain shell string substitution.

---

## Security

The bot token is part of the Telegram API URL, so it appears in curl's process arguments for the duration of the request. Load it from the `CC_TELEGRAM_BOT_TOKEN` environment variable (never inline it) and avoid shared shell history.

---

## Troubleshooting

| Problem                    | Check                                                                                           |
| -------------------------- | ----------------------------------------------------------------------------------------------- |
| Notifications don't arrive | Verify `CC_TELEGRAM_BOT_TOKEN` and `CC_TELEGRAM_CHAT_ID` are set: `echo $CC_TELEGRAM_BOT_TOKEN` |
| curl not found             | Install curl: `sudo apt install curl` / `brew install curl`                                     |
| 401 from Telegram          | Bad bot token — recreate it via @BotFather                                                      |
| 400 (chat not found)       | Bad chat_id — message the bot and rerun getUpdates                                              |
| Telegram unreachable       | `curl` bounded by `--max-time 10`; timeout is a silent no-op                                    |
