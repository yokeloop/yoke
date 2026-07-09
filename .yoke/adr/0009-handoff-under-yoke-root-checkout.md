# 9. Handoff files live in `.yoke/handoff/` of the root checkout

Date: 2026-07-09

## Status

Accepted

## Context

`handoff` wrote its document to the OS temp directory. That made it the only
skill breaking the invariant of ADR 0004 — every yoke artifact lives under
`.yoke/`. It also put the document outside the project it describes: a handoff
is about this work in this repository, yet it landed next to unrelated temp
files, survived only until the next reboot, and could not be found again once
the printed path scrolled out of the terminal.

The user's real use is periodic: dump the conversation, then days later resume a
session from that dump. That demands a stable, discoverable, per-project home.

Alternatives considered:

- **Keep the OS temp directory** — rejected: not discoverable, not durable, and
  the lone exception to the `.yoke/` invariant.
- **`.yoke/ai/<slug>/handoff.md`** — rejected: ties a handoff to a task, but the
  skill is a utility usable in any conversation, including ones with no task.
- **A single overwritten `.yoke/handoff.md`** — rejected: each dump captures a
  distinct moment, and overwriting destroys the earlier one.
- **Write to the current checkout, whatever it is** — rejected: `do` runs inside
  a worktree and `merge` deletes it, so an uncommitted handoff would vanish with
  the worktree that produced it.

## Decision

Each `handoff` run writes one file to `.yoke/handoff/<YYYYMMDD-HHMMSS>-<slug>.md`.

The path resolves against the **root checkout**, never the current worktree —
derived from `git rev-parse --path-format=absolute --git-common-dir`. Outside a
git repository the root is the working directory, and the skill says so.

The `<slug>` falls back in order: the active `.yoke/ai/<slug>/` task, then the
current branch name, then a kebab-case summary of the conversation.

Files accumulate; nothing prunes them. A second handoff of the same conversation
links its predecessor rather than restating it. `.yoke/handoff/` follows the
project's existing committed / local-only choice in `.yoke/flow.md` — it gets no
toggle of its own.

## Consequences

The `.yoke/` invariant now holds for every skill without exception.

A handoff survives `merge` deleting the worktree, and by default it is committed
— so secret redaction stops being a `/tmp` hygiene measure and becomes a
prerequisite for writing to git history.

The path becomes an interface: the planned `warmup` skill reads it, so changing
it later breaks that skill and the user's copied paths.

Because the file no longer lives in a scratch directory, the document itself
grows: it now carries the open task list, the user's verbatim requirements, the
rejected alternatives, and the git state — everything that exists only in the
conversation. Artifacts stay referenced by path, never duplicated.
