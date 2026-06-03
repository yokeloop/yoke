# Direct Telegram Notifications

**Tracking:** https://github.com/yokeloop/yoke/issues/16

## Problem Statement

Yoke skills can ping the user on Telegram at key moments (a stage finishes, a
question is waiting, something is blocked). Today that ping travels through a
two-layer system: each skill calls `lib/notify.sh`, which writes a single JSON
file to `.yoke/notify-pending.json`; a separate **Stop** hook
(`hooks/notify.sh`) later reads that file and sends it to Telegram.

In practice the notifications are unreliable:

- The Stop hook only fires when the agent **fully stops**. An `ACTION_REQUIRED`
  ping is meant to arrive *before* a question pause — but a question pause is
  not a Stop, so those notifications almost never reach the user.
- The queue is a **single file that gets overwritten**. If a skill emits more
  than one notification before the next Stop, only the last survives; the rest
  are lost silently.
- The mechanism is heavy for "send a line of text": two scripts, a JSON
  contract, atomic file writes, plus a hard dependency on `jq`. Every extra
  moving part is another way for it to silently no-op.

The user wants this either simplified to a reliable direct call, or removed
entirely.

## Solution

Replace the queue + Stop-hook with a **single direct-send script**. Skills call
`lib/notify.sh` at their notification points and it POSTs to the Telegram Bot
API **immediately**, in-line. No queue file, no Stop hook, no `.yoke/`, no
`jq`.

From the user's perspective:

- The phone ping arrives **when the event happens** — a "your turn" ping shows
  up right as the agent reaches a question, not after the session ends (or
  never).
- **No lost notifications** — every call delivers on its own; nothing is
  overwritten.
- Setup is unchanged: export `CC_TELEGRAM_BOT_TOKEN` and `CC_TELEGRAM_CHAT_ID`
  in the shell profile and notifications start flowing; leave them unset and the
  system is a silent no-op. Optionally narrow which event types ping via
  `CC_NOTIFY_LEVELS`.

This decision is recorded in
[ADR 0003](../../adr/0003-direct-telegram-notify.md).

## User Stories

1. As a yoke user running a long skill, I want a Telegram ping the moment a
   stage completes, so that I can step away and still know when work is ready.
2. As a yoke user, I want a Telegram ping *before* the agent asks me a question
   (`ACTION_REQUIRED`), so that I come back exactly when my input is needed
   instead of discovering the pause later.
3. As a yoke user, I want a Telegram ping when a task is blocked (`ALERT`), so
   that I can unblock it promptly.
4. As a yoke user whose skill emits several notifications in one run, I want
   every one of them delivered, so that I don't miss an alert because a later
   "complete" message overwrote it.
5. As a yoke user, I want notifications to arrive at the moment of the event
   rather than only when the agent stops, so that the timing is actually
   useful.
6. As a yoke user without `CC_TELEGRAM_*` set, I want skills to run exactly as
   before with no errors and no output noise, so that notifications stay
   strictly opt-in.
7. As a yoke user without `curl` installed, I want skills to keep working
   silently, so that a missing dependency never breaks a skill run.
8. As a yoke user who finds completion pings noisy, I want to restrict
   notifications to the types I care about via `CC_NOTIFY_LEVELS` (e.g. only
   `ACTION_REQUIRED,ALERT`), so that I'm only interrupted when it matters.
9. As a yoke user with multiple projects, I want each notification to show the
   project name, so that I can tell which repo the ping came from.
10. As a yoke user, I want each notification to show the type and the skill that
    sent it, so that I can read the ping at a glance.
11. As a maintainer, I want a single notification script instead of two plus a
    JSON contract, so that there are fewer places for delivery to fail.
12. As a maintainer, I want to drop the `jq` dependency, so that notifications
    work on machines that only have `curl`.
13. As a maintainer, I want the Stop hook, `hooks.json`, the `hooks/`
    directory, and the `.yoke/notify-pending.json` queue removed, so that no
    dead machinery remains to confuse future readers.
14. As a maintainer, I want every existing call site across the skills updated
    to the simplified flags, so that no skill passes flags the new script
    ignores.
15. As a maintainer, I want `docs/notify.md`, `README.md`, and `CLAUDE.md`
    updated to describe direct send, so that the documentation matches the
    implementation.
16. As a future contributor, I want the motivation for dropping the queue
    captured in an ADR, so that I understand why notifications are sent inline
    and don't reintroduce a hook-based queue.
17. As a yoke user, I want notification delivery to never write stray output to
    a skill's transcript, so that the ping is invisible inside the session.
18. As a yoke user on a flaky network, I want a failed or slow Telegram send to
    be time-bounded and non-fatal, so that a notification problem never stalls
    or breaks the skill.

## Implementation Decisions

**Modules**

- **`lib/notify.sh` (deep module, rewritten).** The single notification
  primitive: a flag-based interface in, a Telegram delivery out. It is the only
  surviving piece of notification machinery. Behavior:
  - Reads credentials from the environment: `CC_TELEGRAM_BOT_TOKEN`,
    `CC_TELEGRAM_CHAT_ID`. Skills invoke it via the Bash tool, whose shell is
    initialized from the user profile, so exported vars are present — no
    `allowedEnvVars` plumbing is required.
  - POSTs to the Telegram Bot API **immediately** on each call. No queue file,
    no atomic write, no `.yoke/`.
  - **Drops `jq`.** The payload is form-encoded via
    `curl --data-urlencode text="$MSG"`. `curl` is the only external
    dependency.
  - **Flags:** `--type`, `--title`, `--body`, `--skill`. `--slug` is removed
    (it was never rendered) and `--phase` is removed from the meta line.
  - `project_name` is auto-detected as `basename "$PWD"`.
  - **Message format:** an emoji chosen by `--type`
    (`ACTION_REQUIRED` ⏸, `STAGE_COMPLETE` ✅, `ALERT` ⚠️) and a bold type
    header; a meta line `project / skill`; the title; the body. The tmux line
    is dropped.
  - **Level filter:** optional `CC_NOTIFY_LEVELS` env (comma-separated, e.g.
    `ACTION_REQUIRED,ALERT`). Unset → all three types send. A filtered-out type
    is a silent no-op.
  - **Always silent, always exit 0.** Missing credentials, missing `curl`, a
    filtered-out level, or a failed/timed-out POST never write to stdout and
    never break the calling skill. The `curl` call is time-bounded
    (`--max-time`).

- **Deletions.** Remove `hooks/notify.sh`, `hooks/hooks.json`, the now-empty
  `hooks/` directory, and the `.yoke/notify-pending.json` queue mechanism. The
  plugin ships no hooks after this change.

- **Call-site edits.** 14 call sites across 9 skills keep calling
  `lib/notify.sh` but drop `--slug`/`--phase`: `task` (1), `plan` (1), `do`
  (2), `fix` (3), `review` (2), `bootstrap` (2), `pr` (1), `sync-docs` (1), and
  `.claude/skills/yoke-release` (1). The `--type`, `--title`, `--body`, and
  `--skill` values are preserved.

- **Docs.** Rewrite `docs/notify.md` (remove the two-layer / queue / `jq` /
  Stop-hook story; document direct send, the flag set, `CC_NOTIFY_LEVELS`, and
  the `curl`-only dependency). Update `README.md` (notifications section and
  the architecture diagram entry for `hooks/`) and `CLAUDE.md` (the
  project-structure comment and the `docs/notify.md` reference). ADR 0003 is
  already written.

**Notification type → meaning** (unchanged semantics): `ACTION_REQUIRED` fires
before a question that needs an answer; `STAGE_COMPLETE` when an artifact is
ready; `ALERT` on a block, scope guard, or critical situation.

**Trade-off accepted:** notifications now fire only from explicit skill call
sites. There is no generic "the agent stopped" ping for a plain chat session
with no skill running — this is the deliberate consequence of removing the Stop
hook.

## Testing Decisions

The repository has **no automated test harness** (only Prettier formatting via
`pnpm run format` / `format:check`; no `bats`, no test runner). Per the user's
decision, this change adds **no automated tests**; verification is manual and
behavior-focused.

A good check here exercises only the script's external behavior — what reaches
Telegram and what the exit code is — never its internals:

- **Happy path:** with `CC_TELEGRAM_BOT_TOKEN` / `CC_TELEGRAM_CHAT_ID` set,
  calling `lib/notify.sh --type STAGE_COMPLETE --skill task --title ... --body
  ...` delivers a correctly formatted message to the Telegram chat.
- **Opt-out:** with the credentials unset, the call exits 0, sends nothing, and
  writes no output.
- **Level filter:** with `CC_NOTIFY_LEVELS=ACTION_REQUIRED,ALERT`, a
  `STAGE_COMPLETE` call is a silent no-op while an `ACTION_REQUIRED` call still
  delivers.
- **Missing `curl`:** the call exits 0 silently.
- **Special characters** in `--title` / `--body` arrive intact (form-encoding
  via `--data-urlencode`).

Prior art for the manual check: the "Testing" section of `docs/notify.md`
(updated as part of this change to call the script and confirm the Telegram
message arrives, instead of inspecting a queue file).

## Out of Scope

- Removing notifications entirely — rejected; the feature is kept, only the
  delivery mechanism changes.
- Any non-Telegram delivery channel (Slack, desktop, email, the `pi`/`pi-intercom`
  experiments referenced in `docs/pi-*.md`).
- A generic Stop-hook "agent finished" ping for skill-less sessions —
  intentionally dropped with the hook.
- Adding an automated test framework (`bats` or otherwise) to the repo.
- Changing the set of notification points or their types/semantics — the same
  events fire; only how they are delivered changes.
- Retry/queueing of failed sends — a failed `curl` is silently dropped, as
  before.

## Further Notes

- The whole approach assumes `CC_TELEGRAM_BOT_TOKEN` / `CC_TELEGRAM_CHAT_ID`
  are exported in the user's shell profile so the Bash tool inherits them.
  Worth confirming in the target shell (`echo $CC_TELEGRAM_BOT_TOKEN`) before
  relying on delivery, so the script doesn't silently no-op.
- Telegram `sendMessage` accepts form-encoded params, which is what lets us drop
  `jq`; if richer formatting is ever needed, `parse_mode` can be re-added as a
  form field without reintroducing a JSON builder.
- To break this PRD into implementation tickets, hand off to `/yoke:issues`.
