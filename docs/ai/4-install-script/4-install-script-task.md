# One-command installer for yoke and its external dependencies

**Slug:** 4-install-script
**Ticket:** https://github.com/yokeloop/yoke/issues/4
**Complexity:** medium
**Type:** general

## Task

Add `install.sh` and `install.ps1` at the repo root. Each installer detects the OS and package manager, installs the `revdiff` binary (and warns when `gh` is missing), registers the yoke marketplace through `claude marketplace add github:yokeloop/yoke`, verifies the result, and supports re-runs and `--uninstall`. Update `README.md` and `skills/hi/SKILL.md` to call the new one-command flow.

## Context

### Area architecture

The yoke plugin ships as markdown — no build, no tests, no CI. Two user-facing entry points describe installation today:

- `README.md:243-252` — `## Installation` with a two-command block (`claude marketplace add github:yokeloop/yoke` + `git clone`).
- `skills/hi/SKILL.md:133-137` — a second `## Installation` section that `/hi` surfaces, containing the same `claude marketplace add` line.

`README.md:274-323` (`## Interactive review (revdiff)`) documents the revdiff plugin install (`/plugin marketplace add umputun/revdiff`), terminal requirements, and annotation fold-back. The revdiff **binary** (from https://github.com/umputun/revdiff) is a separate artifact — the installer provisions the binary; the plugin still installs through `/plugin marketplace add umputun/revdiff` out of band.

The only existing shell-script precedent is `lib/notify.sh` (70 lines, bash) — it parses kebab-case long flags, probes tools with `command -v`, and writes files via `mktemp + mv`. It deliberately silences every failure (`exit 0`) because a Stop hook runs it. The installer inverts that stance: user-invoked, it must fail loudly with specific exit codes.

Package managers in scope: `brew` (macOS, linuxbrew), `apt-get`, `dnf`/`yum`, `pacman` (Linux); `winget`, `scoop`, `choco` (Windows). Runtime pins in `.mise.toml` (node 22, pnpm 10) exist only for prettier — the installer must not assume a Node toolchain.

### Files to change

- `install.sh` — new, repo root, mode `100755`. macOS and Linux entry point.
- `install.ps1` — new, repo root. Windows entry point, targets PowerShell 5.1+.
- `README.md:243-252` — rewrite `## Installation` around the piped-curl one-liner with a git-clone fallback.
- `README.md:278-283` — trim the `### Install` subsection inside `## Interactive review (revdiff)` so it points to the yoke installer for the binary while keeping the `/plugin marketplace add umputun/revdiff` line for the plugin.
- `skills/hi/SKILL.md:133-137` — replace the bare `claude marketplace add` command with the new one-command flow.

### Patterns to reuse

- `lib/notify.sh:13-23` — the `while [ $# -gt 0 ]; do case "$1" in --flag) VAR="$2"; shift 2 ;; esac done` argument parser. Reuse the shape; add explicit cases for `--uninstall`, `--skip-deps`, `--skip-gh`, `--yes`, `--verbose`, `--help`.
- `lib/notify.sh:29` — `command -v jq >/dev/null 2>&1 || exit 0` probe form. Reuse the probe; replace the silent `exit 0` with a diagnostic message and a non-zero exit.
- `lib/notify.sh:67-69` — atomic write via `mktemp` + `mv` for any file the installer creates.
- `README.md:247` — the exact marketplace command (`claude marketplace add github:yokeloop/yoke`) lives here. Reuse the string verbatim inside the installer so the two surfaces never drift.
- `skills/gp/SKILL.md:42` — the existing pattern for reporting a missing external CLI (`"Install gh CLI: https://cli.github.com"`). Reuse this phrasing when the installer warns about `gh`.

### Tests

The repo has no automated tests and no CI (`.github/` is absent). Verify manually per the Verification section. A CI smoke matrix is explicitly out of scope for this ticket.

## Requirements

1. Place `install.sh` at the repo root with shebang `#!/usr/bin/env bash`, `set -euo pipefail`, and the executable bit set (committed as mode `100755`).
2. Place `install.ps1` at the repo root. Target PowerShell 5.1+. Gate on `$PSVersionTable.PSVersion.Major -ge 5` and error out on older versions.
3. Parse the same long flags in both installers: `--uninstall`, `--skip-deps`, `--skip-gh`, `--yes` / `-y`, `--verbose`, `--help` / `-h`. PowerShell uses the `[CmdletBinding()] param([switch]$Uninstall, [switch]$SkipDeps, [switch]$SkipGh, [switch]$Yes, [switch]$Verbose)` form.
4. Abort before any side effect when `claude` is missing from PATH. Exit code `2`. Message: `Claude Code CLI not found on PATH. Install: https://docs.claude.com/claude-code`.
5. Detect the OS via `uname -s` (bash) and `$IsWindows` / PS edition (PowerShell). Detect the Linux distro from `/etc/os-release` (`ID`, `ID_LIKE`). Detect the package manager in probe order: macOS → `brew`; Linux → `brew`, `apt-get`, `dnf`, `yum`, `pacman`; Windows → `winget`, `scoop`, `choco`. First hit wins. Exit `3` on unsupported platforms with a one-line message naming the detected platform.
6. Install the `revdiff` binary from the matching channel — Homebrew tap `umputun/apps` on macOS and linuxbrew; `.deb` release asset on apt-based Linux; `.rpm` on dnf/yum; AUR helper (`yay -S revdiff`) on Arch when present, else release-tarball fallback; release-tarball fallback on any Linux without a supported package manager, extracted to `$XDG_BIN_HOME` or `$HOME/.local/bin`; `winget install umputun.revdiff` on Windows (fall back to Scoop when the winget ID is unavailable). Skip this step when `command -v revdiff` already succeeds. Capture the failure reason and exit `4` on any install failure.
7. Handle `gh` as a soft dependency: probe with `command -v gh`. When missing, print `gh CLI not found. /gp, /gca, /pr work without it, but GitHub-backed flows need it. Install: https://cli.github.com` and continue. Never auto-install `gh`. `--skip-gh` silences the warning.
8. Register the marketplace: probe `claude marketplace list 2>/dev/null` with `grep -E '(^|[[:space:]/])yokeloop/yoke([[:space:]]|$)'`. On match, log `yoke marketplace already registered` and continue. Otherwise run `claude marketplace add github:yokeloop/yoke` (exact string). Exit `5` on non-zero return from `claude`.
9. Run a verification pass: `claude marketplace list` contains `yoke`; `command -v revdiff` succeeds (skipped under `--skip-deps`); print a green summary ending with `Next: open Claude Code and run /yoke:hi`. Exit `6` on verification failure.
10. Support `--uninstall`: run `claude marketplace remove yokeloop/yoke`, print one line confirming the removal, and print a hint for removing the `revdiff` / `gh` binaries manually. Never delete `revdiff` or `gh` from `--uninstall`. First probe `claude marketplace --help` at install time and log the detected subcommand name (`remove` / `rm`) so a CLI-flag change surfaces as a single-line diff instead of a silent break.
11. Make the installer idempotent: a second run on the same machine exits `0` with `revdiff already installed` and `yoke marketplace already registered` messages, skipping network calls.
12. Rewrite `README.md:243-252`:

    ```text
    ## Installation

    ### macOS / Linux
    curl -fsSL https://raw.githubusercontent.com/yokeloop/yoke/main/install.sh | bash

    ### Windows
    irm https://raw.githubusercontent.com/yokeloop/yoke/main/install.ps1 | iex

    <details><summary>Manual install</summary>
    git clone https://github.com/yokeloop/yoke.git
    cd yoke && ./install.sh   # or .\install.ps1 on Windows
    </details>

    Uninstall: re-run with `--uninstall`.
    ```

    Keep the piped-curl command on its own line — users copy it verbatim.

13. Trim `README.md:278-283` (`### Install` inside `## Interactive review (revdiff)`) to one line stating that the yoke installer provisions the `revdiff` binary, followed by the existing `/plugin marketplace add umputun/revdiff` + `/plugin install revdiff@umputun-revdiff` lines for the Claude Code plugin itself. Leave every other revdiff subsection (terminal requirements, usage, annotation fold-back, upstream link) untouched.
14. Replace `skills/hi/SKILL.md:133-137` with the one-command flow for macOS/Linux and Windows, matching the README block word-for-word.
15. Name platform-specific channels in top-of-file constants: `REVDIFF_REPO="umputun/revdiff"`, `REVDIFF_BREW_TAP="umputun/apps"`, `YOKE_MARKETPLACE="github:yokeloop/yoke"`. Windows: the same names as PowerShell `$script:` variables. Centralise strings so a channel rename becomes a one-line diff.
16. Route diagnostic output to stderr from the `log_info`, `log_warn`, `log_err`, `log_ok` helpers. Gate colour on `[ -t 2 ] && [ -z "${NO_COLOR:-}" ]` (bash) and on `[Console]::IsOutputRedirected -eq $false` (PowerShell).

## Constraints

- Do not install the `claude` CLI — the ticket lists it under Out of scope.
- Do not touch Telegram env vars, worktrunk setup, or any other project-level configuration — both appear under Out of scope in the ticket.
- Do not add Node, pnpm, or any language runtime to the installer. The repo's `package.json` and `.mise.toml` exist only for prettier; the installer must run on a machine with `bash` (or PowerShell), `curl`, and the OS package manager.
- Do not silence failures with `exit 0` the way `lib/notify.sh` does. The installer is user-invoked — it exits `0` only on success or on the idempotent no-op.
- Do not pin a minimum `revdiff` version. Presence-only idempotency (`command -v revdiff`) is the ticket's AC; version pinning is a follow-up.
- Do not auto-install `gh`. Warn once per run and move on — the user's answer to the gh-policy question.
- Do not publish yoke through Homebrew tap / Scoop / winget in this ticket. The scripts are the delivery mechanism; ecosystem manifests are a separate release-pipeline task.
- Do not delete `revdiff` or `gh` binaries on `--uninstall`. Remove the marketplace entry only; print a hint for manual binary removal.
- Do not add a `GitHub Actions` CI workflow in this ticket. Manual verification on macOS and Docker images suffices; the CI matrix is deferred.
- Do not add checksum or signature verification for the piped-curl flow. A follow-up ticket may add it; do not block this one.
- Do not re-exec under `sudo` silently. On a non-root Linux install that needs root (`dpkg -i`, `dnf install`), prepend `sudo` when stdin is a TTY and `sudo` is on PATH. Otherwise print the exact command to re-run and exit `4`.
- Do not change `.claude-plugin/plugin.json` or `.claude-plugin/marketplace.json`. The manifests stay frozen in this ticket.
- Do not add entries to `.gitignore`. `install.sh` and `install.ps1` belong in the repo. `.prettierignore` needs no change — the prettier glob is `**/*.{md,json}`, so shell and PowerShell files are already excluded.
- Do not alter the revdiff section beyond the trim in Requirement 13. Terminal requirements, usage per integration point, and the upstream link stay verbatim.
- Do not rename the slug in the marketplace command. `github:yokeloop/yoke` matches `README.md:247` verbatim — drift between the two breaks the install instructions.

## Verification

- `bash -n install.sh` — exits `0` (syntax check). `shellcheck install.sh` — exits `0` when shellcheck is installed locally.
- `pwsh -NoProfile -Command 'Set-StrictMode -Version Latest; . ./install.ps1 -Help'` — exits `0` on a machine with PowerShell 7; `powershell -NoProfile -Command '. .\install.ps1 -Help'` — exits `0` on Windows 10 with stock PowerShell 5.1.
- Clean macOS with Homebrew: `./install.sh` — exits `0`; `claude marketplace list` contains a `yoke` row; `revdiff --version` prints a version.
- Second run of `./install.sh` on the same machine — exits `0`; stderr contains `revdiff already installed` and `yoke marketplace already registered`; no network calls (`sudo strace -f -e trace=connect ./install.sh` shows no new outbound connections).
- `./install.sh --uninstall` on an installed machine — exits `0`; `claude marketplace list` no longer shows `yoke`; `command -v revdiff` still succeeds; stderr prints the manual-removal hint for `revdiff` and `gh`.
- `PATH="/tmp/empty:$PATH" ./install.sh` with no `claude` binary reachable — exits `2`; stderr matches `Claude Code CLI not found on PATH`.
- `./install.sh` with the network blocked after marketplace registration — exits `6`; stderr names the failing verification step.
- Docker `debian:12` with a mocked `claude` shell function: `./install.sh` — exits `0`; the `.deb` path fires; `dpkg -l | grep revdiff` returns a match.
- Docker `fedora:40` with a mocked `claude`: `./install.sh` — exits `0`; the `.rpm` path fires.
- `README.md` renders the three-block install (macOS/Linux, Windows, Manual) and keeps the revdiff section intact above `## References`.
- `skills/hi/SKILL.md:133` — `## Installation` matches the README block word-for-word.
- `rg 'marketplace add github:yokeloop/yoke' README.md skills/` — returns one match per surface only (no drift).
- `pnpm run format:check` — exits `0` on all changed markdown files.

## Materials

- [GitHub issue #4 — Add one-command install and activation script for yoke and its dependencies](https://github.com/yokeloop/yoke/issues/4)
- [revdiff upstream (MIT)](https://github.com/umputun/revdiff)
- [Homebrew tap `umputun/apps`](https://github.com/umputun/homebrew-apps)
- [Claude Code install docs](https://docs.claude.com/claude-code)
- [GitHub CLI install](https://cli.github.com)
- `README.md:243-252` — current `## Installation` block to replace
- `README.md:274-323` — `## Interactive review (revdiff)` section to trim, not rewrite
- `skills/hi/SKILL.md:133-137` — second install surface to keep in sync
- `lib/notify.sh:1-70` — bash style reference (arg parser, probe pattern, atomic write)
- `.claude-plugin/marketplace.json` — marketplace manifest (owner `Heliotic`, plugin name `yoke`, source `./`)
- `.claude-plugin/plugin.json` — plugin manifest (version 1.0.0, source of truth)
- `.mise.toml` — runtime pins; the installer must not assume Node
- `skills/gp/SKILL.md:42` — reference phrasing for a missing external CLI
