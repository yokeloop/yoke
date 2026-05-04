# Add a --version flag handler to lib/notify.sh

**Slug:** test-baseline
**Ticket:** —
**Complexity:** trivial
**Type:** general

## Task

Add a `--version` flag to `lib/notify.sh` that prints the script's version
(read from a single `VERSION="x.y.z"` line at the top of the file) and exits 0.

## Context

### Area architecture

`lib/notify.sh` is invoked by skills via `bash ${CLAUDE_PLUGIN_ROOT}/lib/notify.sh ...`.
The script currently parses flags via getopts and supports `--type`, `--skill`,
`--phase`, `--slug`, `--title`, `--body`.

### Files to change

- `lib/notify.sh` — add VERSION constant + `--version` flag handler

### Patterns to reuse

- Existing flag parsing pattern in the same file (use the same getopts loop).

### Tests

- No automated tests cover `lib/notify.sh`. Verify manually with a curl-style command.

## Requirements

1. `lib/notify.sh --version` prints exactly `notify.sh <version>` and exits 0.
2. Other flags continue to work unchanged.

## Constraints

- Do not change the existing notification behavior.
- Do not add external dependencies.

## Verification

- `bash lib/notify.sh --version` → prints `notify.sh 1.0.0`, exit code 0.
- `bash lib/notify.sh --type STAGE_COMPLETE --skill task --title "x" --body "y"` →
  same behavior as before (sends notification or no-op if env vars unset).

## Materials

- `lib/notify.sh`
