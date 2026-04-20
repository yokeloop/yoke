# One-command installer for yoke and its external dependencies — implementation plan

**Task:** docs/ai/4-install-script/4-install-script-task.md
**Complexity:** medium
**Mode:** sub-agents
**Parallel:** true

## Design decisions

### DD-1: CLI subcommand path — `claude plugin marketplace`, not `claude marketplace`

**Decision:** The installer, the README rewrite, and `skills/hi/SKILL.md` invoke `claude plugin marketplace add github:yokeloop/yoke`, `claude plugin marketplace list`, and `claude plugin marketplace remove yokeloop/yoke`.
**Rationale:** A live probe of `claude plugin --help` prints the real subcommand tree — `marketplace` sits under `plugin`, with verbs `add <source>`, `list`, `remove|rm <name>`, `update [name]`. The task file's `claude marketplace add` (Req 8, Req 10) and the current `README.md:247` both name a command path that does not exist.
**Contract:** The task-file wording is errata. The plan leaves the committed task file untouched. Req 14's "word-for-word" match holds between `README.md` and `skills/hi/SKILL.md` (both rendered with the corrected verb), not between the task-file template and the rendered output. The slug `github:yokeloop/yoke` stays unchanged (Req 15 preserved).
**Alternative:** Follow the task file verbatim. Rejected — the installer would exit 1 on first run with "unknown command".

### DD-2: Authoring order — installers first, docs second

**Decision:** `install.sh` and `install.ps1` land on `main` before the README and `/hi` rewrite points users at `https://raw.githubusercontent.com/yokeloop/yoke/main/install.sh`.
**Rationale:** Docs that point at a 404 URL fail most visibly. Authoring scripts first also lets T4 replay `curl | bash` against the actual committed file before the docs change ships.
**Alternative:** Docs first with the URL stubbed. Rejected — a 404 window on `main` is user-visible.

### DD-3: Parallel authoring of `install.sh` and `install.ps1`

**Decision:** T1 and T2 dispatch in parallel.
**Rationale:** Zero write overlap; they share only top-of-file constant strings, which review diffs trivially.
**Alternative:** Serialise with `.sh` as reference. Rejected — the PS1 author works from the task spec, not from the bash source.

### DD-4: Docs edits bundled into one task and one commit

**Decision:** T3 edits `README.md:243-252`, `README.md:278-283`, and `skills/hi/SKILL.md:133-137` in one atomic pass.
**Rationale:** Req 14 demands that the README install block and the `/hi` install block match word-for-word. Splitting the edit across commits opens the drift window the Req exists to close.
**Alternative:** One commit per file. Rejected — Req 14 is a verbatim-match invariant.

### DD-5: Sudo policy — opportunistic TTY-gated prepend

**Decision:** A `sudo_prefix()` helper returns empty string when the process runs as root, `"sudo"` when stdin is a TTY and `sudo` sits on PATH, and exits 4 after printing the exact command otherwise. Callers wrap `dpkg -i`, `dnf install`, `yum install`, `pacman -U`, and the tarball `install -m 0755 …` step.
**Rationale:** Matches the "do not re-exec under `sudo` silently" constraint and avoids a cryptic "sudo: command not found" in rootless containers.
**Alternative:** Always prepend `sudo`. Rejected — the rootless-container path needs an explicit Req-specified exit 4, not a sudo-binary miss.

### DD-6: Revdiff release-tarball fallback

**Decision:** Target directory resolves to `${XDG_BIN_HOME:-$HOME/.local/bin}`. Fetch `https://github.com/umputun/revdiff/releases/latest/download/revdiff_<os>_<arch>.tar.gz` with `curl -fsSL`, extract, install with mode 0755. Fires on (a) Linux without a supported package manager, (b) Arch without `yay`, (c) last-resort after a package-manager install fails. When the target sits off PATH, warn with the exact `export PATH=…` line and let the verify pass decide (Req 9 → exit 6).
**Rationale:** Matches Req 6 and Req 9; user picked "install + warn, let verify catch it" in the clarification round.
**Alternative:** Install to `/usr/local/bin` via sudo. Rejected — the tarball branch is the least-privilege escape hatch.

### DD-7: `--help` / `--version` short-circuit before preflight

**Decision:** `--help` / `-h` prints the usage block (synopsis, flags, exit-code legend) and exits 0. `--version` prints `yoke-installer 0.1.0` and exits 0. Both short-circuit before the `claude`-on-PATH check.
**Rationale:** CI and Docker images without `claude` installed must still inspect the installer. The version constant `INSTALLER_VERSION="0.1.0"` lives apart from `plugin.json.version`.
**Alternative:** Run preflight inside `--help`. Rejected — breaks inspect-without-claude.

### DD-8: Uninstall-subcommand probe

**Decision:** At install and uninstall time, run `claude plugin marketplace --help 2>&1` once, detect `remove|rm`, prefer `remove` when both appear. Log the chosen verb on stderr via `log_info`.
**Rationale:** Req 10 demands the probe so a future CLI-flag rename surfaces as a one-line diff. The live probe confirms both `remove` and `rm` work today.
**Alternative:** Hard-code `remove`. Rejected by Req 10.

### DD-9: `install.sh` stays monolithic

**Decision:** One ~350-line `install.sh`. No sourced modules.
**Rationale:** `curl -fsSL … | bash` drives the primary delivery path (Req 12). Sourced `lib/install/*.sh` files break piped-curl because the sibling tree never lands on disk. The monolith also matches `lib/notify.sh` (70 lines, single file) — the established repo style.
**Alternative:** Split into `install.sh` + `lib/install/{detect,revdiff,marketplace}.sh`. Rejected — piped-curl can't source siblings.

### DD-10: `install.ps1` V1 scope — winget → scoop only

**Decision:** The Windows installer probes `winget` first (`winget install umputun.revdiff`), falls back to `scoop` (`scoop install revdiff`), and emits a warn-and-exit when neither is present. No choco, no zip-extract fallback.
**Rationale:** Req 6 names only winget and scoop. Keeps V1 tight.
**Alternative:** Add choco probe and zip-extract to `%LOCALAPPDATA%\Programs\revdiff\`. Rejected — revdiff skips choco, and the zip path needs a PATH-registry write that V1 does not justify.

### DD-11: `--verbose` implementation via `log_debug`

**Decision:** A `log_debug()` helper gated on `VERBOSE=1`. The script never uses `set -x`.
**Rationale:** `set -x` leaks every expanded command, including URLs that may carry tokens in future iterations, and produces output users paste into bug reports verbatim.
**Alternative:** `set -x`. Rejected — unsafe and noisy.

### DD-12: Sudo session — `sudo -v` once, then per-command

**Decision:** When any step needs root, call `sudo -v` once up front to prime the sudo cache; subsequent `sudo …` calls within the same run stay silent.
**Rationale:** One password prompt per run with per-command audit trail. Matches the UX the user picked in the clarification round.
**Alternative:** Per-command only (multiple prompts) or a single `sudo bash -c` wrapping the whole root block (opaque audit). Rejected — the former adds friction, the latter hides the steps.

## Tasks

### Task 1: Author `install.sh`

- **Files:** `install.sh` (create, mode 100755)
- **Depends on:** none
- **Scope:** L
- **What:** Monolithic bash installer for macOS and Linux covering Req 1, 3–11, 15–16.
- **How:**
  1. Header: shebang `#!/usr/bin/env bash`, `set -euo pipefail`, file comment, top-of-file constants `INSTALLER_VERSION="0.1.0"`, `REVDIFF_REPO="umputun/revdiff"`, `REVDIFF_BREW_TAP="umputun/apps"`, `YOKE_MARKETPLACE="github:yokeloop/yoke"`.
  2. Argument parser in the `while [ $# -gt 0 ]; do case "$1" in …` shape (pattern: `lib/notify.sh:13-23`). Long and short flags: `--uninstall`, `--skip-deps`, `--skip-gh`, `--yes|-y`, `--verbose`, `--help|-h`, `--version`.
  3. `log_info`, `log_warn`, `log_err`, `log_ok`, `log_debug` — all write to stderr. Colour on when `[ -t 2 ] && [ -z "${NO_COLOR:-}" ]`. `log_debug` no-ops unless `VERBOSE=1`.
  4. `--help` and `--version` short-circuit with exit 0 before any side effect (DD-7).
  5. `ensure_claude_cli` — `command -v claude >/dev/null 2>&1` or exit 2 with the Req-4 message.
  6. `detect_os` (via `uname -s` + `/etc/os-release`) and `detect_pm` (probe order: macOS→brew; Linux→brew, apt-get, dnf, yum, pacman). On Windows-like env (`MINGW*`, `MSYS*`, `CYGWIN*`) exit 3 with "Run install.ps1 on Windows".
  7. `sudo_prefix()` helper (DD-5). `sudo_prime()` helper that calls `sudo -v` once when the cache is cold (DD-12).
  8. `install_revdiff`: branches for brew / apt (`.deb` via `curl -fsSL` to a `mktemp` target then `$(sudo_prefix) dpkg -i`) / dnf / yum / pacman (prefer `yay -S revdiff` when present, else tarball fallback) / tarball fallback to `${XDG_BIN_HOME:-$HOME/.local/bin}` (DD-6). Skip when `command -v revdiff` already succeeds. Exit 4 on install failure.
  9. `warn_gh`: probe `command -v gh`, print the `skills/gp/SKILL.md:42` phrasing when missing unless `--skip-gh`. Never auto-install.
  10. `detect_marketplace_subcmd`: run `claude plugin marketplace --help 2>&1`, grep `remove|rm`, prefer `remove`, log the chosen verb (DD-8).
  11. `register_marketplace`: probe `claude plugin marketplace list 2>/dev/null | grep -E '(^|[[:space:]/])yokeloop/yoke([[:space:]]|$)'`. On miss, run `claude plugin marketplace add github:yokeloop/yoke`. Exit 5 on non-zero from `claude`.
  12. `verify_install`: re-run `list`, confirm the `yoke` row; `command -v revdiff` succeeds unless `--skip-deps`. Exit 6 on miss with a diagnostic naming the failing step.
  13. `uninstall`: `claude plugin marketplace <subcmd> yokeloop/yoke`, print one-line confirmation, print manual-removal hint for `revdiff` / `gh`. Never delete binaries.
  14. Idempotent second run: the `list` grep and `command -v revdiff` checks skip network calls on a warm machine (Req 11).
- **Context:** `docs/ai/4-install-script/4-install-script-task.md` (spec of record), `lib/notify.sh:1-70` (style reference), `hooks/notify.sh:52-58` (inline helper pattern), `skills/gp/SKILL.md:42` (phrasing), `README.md:247` (marketplace slug reference — note the verb correction per DD-1), `.claude-plugin/marketplace.json`.
- **Verify:**
  - `bash -n install.sh` → exit 0.
  - `./install.sh --help` → exit 0, no preflight run.
  - `./install.sh -h` → exit 0 (short-flag alias).
  - `./install.sh --version` → prints `yoke-installer 0.1.0` and exits 0.
  - `PATH="/tmp/empty:$PATH" ./install.sh` → exit 2.
  - `grep -c 'claude plugin marketplace add github:yokeloop/yoke' install.sh` ≥ 1.
  - `grep -cE '^\s*claude marketplace add' install.sh` → 0 (no old verb).
  - `shellcheck install.sh` → exit 0 (when shellcheck is available locally).

### Task 2: Author `install.ps1`

- **Files:** `install.ps1` (create)
- **Depends on:** none
- **Scope:** M
- **What:** PowerShell 5.1+ installer for Windows covering Req 2–11, 15–16.
- **How:**
  1. `[CmdletBinding()] param([switch]$Uninstall, [switch]$SkipDeps, [switch]$SkipGh, [switch]$Yes, [switch]$Verbose, [switch]$Help, [switch]$Version)`.
  2. Gate on `$PSVersionTable.PSVersion.Major -ge 5`; error out below that.
  3. `$script:INSTALLER_VERSION`, `$script:REVDIFF_REPO`, `$script:REVDIFF_BREW_TAP` (unused on Windows but kept for parity), `$script:YOKE_MARKETPLACE`.
  4. `Write-LogInfo`, `Write-LogWarn`, `Write-LogErr`, `Write-LogOk`, `Write-LogDebug` → all write to `$Host.UI.WriteErrorLine` / stderr. Colour on when `-not [Console]::IsOutputRedirected`.
  5. `-Help` / `-Version` short-circuit with exit 0 before any side effect.
  6. `Test-ClaudeCli`: `Get-Command claude -ErrorAction SilentlyContinue` or exit 2.
  7. `Get-PackageManager`: probe `winget` then `scoop`; no match → exit 3 (DD-10).
  8. `Install-Revdiff`: `winget install --id umputun.revdiff --silent --accept-source-agreements --accept-package-agreements`; on non-zero exit, fall back to `scoop install revdiff`; on both failing, exit 4. Skip entirely when `Get-Command revdiff` already returns. Honour `-SkipDeps`.
  9. `Warn-Gh`: probe `Get-Command gh`; print the Req-7 message when missing, stay silent under `-SkipGh`.
  10. `Register-Marketplace`: probe `claude plugin marketplace list 2>$null` with regex match on `yokeloop/yoke`. On miss, run `claude plugin marketplace add github:yokeloop/yoke`. Exit 5 on non-zero.
  11. `Verify-Install`: re-run list; `Get-Command revdiff` unless `-SkipDeps`. Exit 6 on miss.
  12. `Invoke-Uninstall`: probe `claude plugin marketplace --help` once, prefer `remove`, run `claude plugin marketplace remove yokeloop/yoke`, print manual-removal hint, never delete binaries.
- **Context:** `docs/ai/4-install-script/4-install-script-task.md`, `install.sh` (T1 output, for constant-string parity only), `.editorconfig` (LF + final newline).
- **Verify:**
  - `pwsh -NoProfile -Command '. ./install.ps1 -Help'` → exit 0 on PS 7.
  - `powershell -NoProfile -Command '. .\install.ps1 -Help'` → exit 0 on Windows 10 stock PS 5.1.
  - Mock `Get-Command winget`/`scoop` as absent → exit 3.
  - Mock `winget install` returning non-zero → exit 4.
  - `grep -c 'claude plugin marketplace add github:yokeloop/yoke' install.ps1` ≥ 1.
  - `grep -cE 'claude marketplace add' install.ps1` → 0.

### Task 3: Docs sync — README install, README revdiff trim, `/hi`

- **Files:** `README.md` (rewrite `:243-252`; trim `:278-283`), `skills/hi/SKILL.md` (replace `:133-137`)
- **Depends on:** Task 1, Task 2
- **Scope:** S
- **What:** Replace the `## Installation` block with the Req-12 three-subsection layout, trim the `### Install` subsection inside `## Interactive review (revdiff)`, and sync the `/hi` install block with the README word-for-word.
- **How:**
  1. Replace `README.md:243-252` verbatim with the Req-12 block: `## Installation` → `### macOS / Linux` (`curl -fsSL https://raw.githubusercontent.com/yokeloop/yoke/main/install.sh | bash`) → `### Windows` (`irm https://raw.githubusercontent.com/yokeloop/yoke/main/install.ps1 | iex`) → `<details><summary>Manual install</summary>` block with `git clone https://github.com/yokeloop/yoke.git` and `cd yoke && ./install.sh   # or .\install.ps1 on Windows` → `Uninstall: re-run with \`--uninstall\`.` The three-line piped-curl / irm / manual-install commands stay on their own lines.
  2. Trim `README.md:278-283`: replace the current four-line `/plugin marketplace add …` + `/plugin install …` block with one leading line stating that the yoke installer provisions the revdiff binary, followed by both existing plugin lines preserved verbatim: `/plugin marketplace add umputun/revdiff` AND `/plugin install revdiff@umputun-revdiff` (per Req 13). Leave every other revdiff subsection (terminal requirements, usage, annotation fold-back, upstream link) untouched.
  3. Replace `skills/hi/SKILL.md:133-137` with the same three-subsection block as the README, word-for-word (Req 14).
- **Context:** `README.md:243-252`, `README.md:274-323` (full revdiff section for context), `skills/hi/SKILL.md:125-138`, `docs/ai/4-install-script/4-install-script-task.md` (Req 12-14 spec).
- **Verify:**
  - `rg -F 'curl -fsSL https://raw.githubusercontent.com/yokeloop/yoke/main/install.sh | bash' README.md skills/hi/SKILL.md` → 2 matches.
  - `rg -F 'irm https://raw.githubusercontent.com/yokeloop/yoke/main/install.ps1 | iex' README.md skills/hi/SKILL.md` → 2 matches.
  - `rg -F '/plugin marketplace add umputun/revdiff' README.md` → 1 match.
  - `rg -F '/plugin install revdiff@umputun-revdiff' README.md` → 1 match.
  - `rg -F 'claude plugin marketplace add github:yokeloop/yoke' README.md skills/hi/SKILL.md` → 2 matches (one per surface).
  - `rg -F 'claude marketplace add github:yokeloop/yoke' README.md skills/hi/SKILL.md` → 0 matches (old verb gone).
  - Extract `## Installation` through the next `##` from `README.md` and from `skills/hi/SKILL.md`; `diff` of the two extractions is empty.

### Task 4: Manual verification pass

- **Files:** — (no writes)
- **Depends on:** Task 1, Task 2, Task 3
- **Scope:** S
- **What:** Run every Verification bullet from the task file plus the two execution-mode checks flagged in review (piped-bash and network-blocked-post-registration), then produce a pass report.
- **How:** execute checks in this order, recording pass/fail:
  - `bash -n install.sh` → 0; `shellcheck install.sh` → 0 when available.
  - `pwsh -NoProfile -Command 'Set-StrictMode -Version Latest; . ./install.ps1 -Help'` → 0 on PS 7; `powershell -NoProfile -Command '. .\install.ps1 -Help'` → 0 on PS 5.1 (manual smoke).
  - `curl -fsSL "file://$(pwd)/install.sh" | bash -s -- --help` → 0 (the piped-bash path); then `grep -nE '\$0|BASH_SOURCE|\./lib/' install.sh` returns no repo-relative references (no sibling-file reliance).
  - Clean macOS with Homebrew: `./install.sh` → 0; `claude plugin marketplace list` contains `yoke`; `revdiff --version` prints a version.
  - Second run of `./install.sh` on the same machine → 0; stderr contains `revdiff already installed` and `yoke marketplace already registered`.
  - `./install.sh --uninstall` → 0; `claude plugin marketplace list` no longer shows `yoke`; `command -v revdiff` still succeeds; stderr prints the manual-removal hint for `revdiff` / `gh`.
  - `PATH="/tmp/empty:$PATH" ./install.sh` → exit 2 with the Req-4 message.
  - Network-blocked-post-registration: run `./install.sh`, block outbound traffic after `claude plugin marketplace add` succeeds, confirm that verify fails with exit 6 and a diagnostic naming the failing step.
  - Docker `debian:12` with a mocked `claude` shell function → exit 0; `dpkg -l | grep revdiff` returns a match.
  - Docker `fedora:40` with a mocked `claude` → exit 0; `.rpm` path fires.
  - `README.md` renders the three-block install and keeps the revdiff section intact above `## References`.
  - `diff` of the `## Installation` block between `README.md` and `skills/hi/SKILL.md` → empty.
- **Context:** `install.sh`, `install.ps1`, `README.md`, `skills/hi/SKILL.md`, `docs/ai/4-install-script/4-install-script-task.md` (Verification section).
- **Verify:** Every check in the list above passes; each failure gets reported with its exit code and remediation note.

### Task 5: Validation

- **Files:** —
- **Depends on:** Task 3
- **Scope:** S
- **What:** Full-repo validation gate.
- **How:** run the commands below and confirm the expected output.
- **Context:** —
- **Verify:**
  - `pnpm run format:check` → exit 0.
  - `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('OK')"` → `OK`.
  - `head -1 skills/*/SKILL.md commands/*.md` → every first line reads `---` (command files absent — the glob is a no-op and must not count as a failure).
  - `rg -F 'marketplace add github:yokeloop/yoke' README.md skills/` → 2 matches (task-file invariant preserved).
  - `rg -F 'claude plugin marketplace add github:yokeloop/yoke' README.md skills/hi/SKILL.md install.sh install.ps1` → 4 matches (one per surface).
  - `rg -FE 'claude marketplace add' README.md skills/ install.sh install.ps1` → 0 matches (old verb gone).

## Execution

- **Mode:** sub-agents
- **Parallel:** true
- **Reasoning:** 5 tasks with no write-write intersections and no cross-layer spread; T1 and T2 create independent new files; T4 and T5 verify only and share no writes.
- **Order:**
  ```
  Group 1 (parallel):
    Task 1: install.sh
    Task 2: install.ps1
  ─── barrier ───
  Group 2 (sequential):
    Task 3: Docs sync
  ─── barrier ───
  Group 3 (parallel):
    Task 4: Manual verification pass
    Task 5: Validation
  ```

## Verification

- `bash -n install.sh` — exits 0. `shellcheck install.sh` — exits 0 when available.
- `pwsh -NoProfile -Command 'Set-StrictMode -Version Latest; . ./install.ps1 -Help'` — exits 0 on PS 7; `powershell -NoProfile -Command '. .\install.ps1 -Help'` — exits 0 on PS 5.1.
- Clean macOS with Homebrew: `./install.sh` — exits 0; `claude plugin marketplace list` contains `yoke`; `revdiff --version` prints a version.
- Second run of `./install.sh` — exits 0; stderr contains `revdiff already installed` and `yoke marketplace already registered`; no new outbound connects.
- `./install.sh --uninstall` — exits 0; `claude plugin marketplace list` no longer shows `yoke`; `command -v revdiff` still succeeds; manual-removal hint printed.
- `PATH="/tmp/empty:$PATH" ./install.sh` — exits 2 with `Claude Code CLI not found on PATH. Install: https://docs.claude.com/claude-code`.
- `./install.sh` with outbound traffic blocked after marketplace registration — exits 6 with a diagnostic naming the failing verification step.
- Docker `debian:12` with a mocked `claude` function — exits 0; `dpkg -l | grep revdiff` matches.
- Docker `fedora:40` with a mocked `claude` — exits 0; the `.rpm` path fires.
- `README.md` renders the three-block install section and keeps `## Interactive review (revdiff)` intact above `## References`.
- The `## Installation` block at `skills/hi/SKILL.md:133` matches the `README.md:243` block word-for-word.
- `pnpm run format:check` — exits 0 on all changed markdown files.

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
- `hooks/notify.sh:52-58` — inline helper-function pattern
- `skills/gp/SKILL.md:42` — reference phrasing for the missing-CLI warn
- `.claude-plugin/marketplace.json` — marketplace manifest (owner `Heliotic`, plugin name `yoke`, source `./`)
- `.claude-plugin/plugin.json` — plugin manifest (version 1.0.0, source of truth)
- `.editorconfig` — LF, 2-space indent, final newline
