# Code Review: 4-install-script

## Summary

### Context and goal

Add a one-command installer for yoke on macOS, Linux, and Windows. `install.sh` bootstraps `revdiff` via brew / apt / dnf / yum / pacman / tarball, warns on missing `gh`, registers the `github:yokeloop/yoke` marketplace through `claude plugin marketplace add`, and verifies; `install.ps1` mirrors the flow for Windows via winget → scoop. README and `skills/hi/SKILL.md` advertise `curl | bash` and `irm | iex` entry points.

### Key code areas for review

1. **`install.sh:193-218` `sudo_prefix` / `sudo_prime`** — opportunistic TTY-gated sudo escalation. Critical for the `curl | bash` flow on Linux where sudo is required.
2. **`install.sh:256-285` `install_revdiff_tarball`** — least-privilege escape hatch with XDG_BIN_HOME writability probe.
3. **`install.sh:297-302` brew tap probe** — pipefail-safe capture-then-filter.
4. **`install.ps1:5-22` param block + `$script:IsVerbose`** — `[CmdletBinding()]` common `-Verbose` correctness.
5. **`install.ps1:127-138` winget fallback** — "already installed" exit-code handling.
6. **`install.ps1:183-190` `Test-MarketplaceRegistered`** — multiline regex against `claude plugin marketplace list` output.
7. **`README.md` / `skills/hi/SKILL.md` Installation blocks** — byte-identical per Req 14, with a new candor note about running remote scripts.

### Complex decisions

1. **CLI subcommand correction (DD-1)** (`install.sh`, `install.ps1`, `README.md`, `skills/hi/SKILL.md`) — use `claude plugin marketplace add/list/remove` instead of the task-file's `claude marketplace add` (not a real subcommand). Slug `github:yokeloop/yoke` preserved.
2. **Opportunistic sudo (DD-5, post-review)** — gate on `[ -t 1 ]` or warm `sudo -n true` cache; resolve once per step into a `$SUDO` local; non-zero return instead of `exit 4` so a subshell can't swallow the escalation failure.
3. **Uninstall scope (ticket constraint)** — remove the marketplace entry only; leave `revdiff` and `gh` binaries alone; print a manual-removal hint instead.

### Questions for the reviewer

1. Is the candor note in the Installation block assertive enough, or should the README recommend a pinned release tag as the default install command?
2. Should `--version` on a release branch emit the git commit SHA alongside `0.1.0`?
3. Is there value in a `scripts/test-install-docker.sh` harness for the apt / dnf smoke cases, or do we defer that to a follow-up CI ticket?

### Risks and impact

- **curl | bash on unknown hosts** — the advertised one-liner still fetches from `main`. Future `main` commits change the install surface for anyone piping the URL. Consider tagging releases.
- **BSD vs GNU tool flags** — `tar --no-same-owner` is GNU; the fallback re-runs on rejection. Confirm on older macOS (pre-10.15) if the shop still supports it.
- **PowerShell 5.1 Windows 10 stock** — Verified statically (no PS7-only syntax); `pwsh` parse check deferred (not on this host).
- **Sudo fragility** — if `sudo` is absent AND not root AND stderr has no TTY, the script exits 4 instead of running unprivileged commands — the right call, but documented only in the error message.

### Tests and manual checks

**Auto-tests:**

- `bash -n install.sh` — green.
- `pnpm run format:check` — green.
- JSON manifest validation — green.
- SKILL.md frontmatter sanity — green.

**Manual scenarios:**

1. Clean macOS with Homebrew → `./install.sh` → exit 0; `claude plugin marketplace list` shows yoke; `revdiff --version` prints a version.
2. Re-run on the same machine → exit 0; stderr contains `revdiff already installed` and `yoke marketplace already registered`; no network connects.
3. `./install.sh --uninstall` → exit 0; marketplace row gone; revdiff binary preserved; manual-removal hint printed.
4. Debian container with mocked `claude` via `curl -fsSL file://.../install.sh | bash` → exit 0; `.deb` path fires; sudo escalation works via the `[ -t 1 ]` gate.
5. Network blocked after marketplace registration → exit 6 with diagnostic naming the failing verify step.
6. Windows 10 stock PS 5.1 → `powershell -NoProfile -Command '. .\install.ps1 -Help'` → exit 0; no reserved-parameter parse error.
7. `winget install` returns "already installed" code → log demotes to debug; Scoop fallback not attempted.

### Out of scope

- Homebrew tap / Scoop / winget manifest publication for yoke itself.
- Pinned `revdiff` version (presence-only idempotency stands).
- Interactive `-Yes` / `--yes` prompts (flags reserved, no behaviour today).
- Checksum / signature verification of the remote installer.
- GitHub Actions CI smoke matrix.
- `gh` auto-install.

## Commits

| Hash      | Description                                                         |
| --------- | ------------------------------------------------------------------- |
| `8f79707` | #4 docs(4-install-script): add task definition                      |
| `a30524a` | #4 docs(4-install-script): add implementation plan                  |
| `a2ebc57` | #4 feat(4-install-script): add install.ps1 installer for Windows    |
| `aaaaacf` | #4 feat(4-install-script): add install.sh installer for macOS and Linux |
| `23a3adf` | #4 fix(4-install-script): address spec-review feedback on install.ps1 |
| `62bbcca` | #4 docs(4-install-script): switch install docs to one-command flow  |
| `40be260` | #4 refactor(4-install-script): simplify installer scripts           |
| `51a37cf` | #4 docs(4-install-script): add execution report                     |
| `a6259ab` | #4 fix(4-install-script): fix 14 review issues                      |

## Changed Files

| File                                                           | +/-      | Description                                                               |
| -------------------------------------------------------------- | -------- | ------------------------------------------------------------------------- |
| `install.sh`                                                   | +507     | New bash installer (macOS/Linux); post-review fixes in `a6259ab`          |
| `install.ps1`                                                  | +253     | New PowerShell installer (Windows); post-review fixes in `a6259ab`        |
| `README.md`                                                    | +30 / -4 | Rewrote `## Installation`, trimmed revdiff `### Install`, added candor note |
| `skills/hi/SKILL.md`                                           | +26 / -1 | Installation block synced word-for-word with README                       |
| `docs/ai/4-install-script/4-install-script-task.md`            | +134     | Task artifact                                                             |
| `docs/ai/4-install-script/4-install-script-plan.md`            | +252     | Plan artifact                                                             |
| `docs/ai/4-install-script/4-install-script-report.md`          | +82      | Execution report                                                          |
| `docs/ai/4-install-script/4-install-script-review.md`          | (this)   | Review report                                                             |

## Issues Found

| Severity  | Score | Category      | File:line                                     | Description                                                                                             |
| --------- | ----- | ------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Critical  | 95    | bugs          | `install.ps1:5,12`                            | `[switch]$Verbose` collides with `[CmdletBinding()]` reserved common parameter; parse-time fatal on PS 5.1/7 |
| Critical  | 85    | bugs          | `install.sh:193-203, 327-358`                 | `sudo_prefix` `[ -t 0 ]` gate fails under `curl\|bash`; `$(sudo_prefix)` subshell-only `exit 4` swallowed |
| Important | 70    | security      | `README.md:247`, `skills/hi/SKILL.md:137`     | Piped-curl / irm\|iex one-liners advertised without a candor note or pinned ref                          |
| Important | 60    | bugs          | `install.sh:298`                              | `brew tap \| grep -qx` fragile under `pipefail` — SIGPIPE on early match re-taps every run               |
| Important | 55    | bugs          | `install.sh:268`                              | `install -m 0755` silently fails without sudo when user overrides `XDG_BIN_HOME` to a non-$HOME path     |
| Important | 55    | reliability   | `install.sh:202`                              | `log_err "… Re-run as root: $*"` dangles `$*` (always empty)                                             |
| Important | 55    | bugs          | `install.ps1:137-147`                         | `Test-MarketplaceRegistered` regex runs single-line; relies on undocumented CLI formatting              |
| Minor     | 45    | reliability   | `install.sh:248, 322, 353`                    | No `--connect-timeout` / `--max-time` / `--retry` on internal `curl` downloads                          |
| Minor     | 40    | bugs          | `install.sh:252`                              | `tar -xzf` lacks `--no-same-owner` and has no path-traversal guard                                      |
| Minor     | 40    | bugs          | `install.ps1:97`                              | winget "already installed" / "no applicable update" exit codes misreported as install failure           |
| Minor     | 35    | quality       | `install.sh:212-217`                          | `sudo_prime` silent no-op vs `sudo_prefix` exit 4 — inconsistent gating                                  |
| Minor     | 30    | quality       | `install.sh:128-135`                          | `. /etc/os-release` leaks `PRETTY_NAME`, `NAME`, `VERSION` into installer environment                   |
| Minor     | 25    | quality       | `install.sh:261`                              | `find -maxdepth 3 -quit` — BSD vs GNU portability (both support it; noted only)                         |
| Minor     | 25    | style         | `install.ps1:21`                              | `$script:IsVerbose` source of truth should include `$VerbosePreference`                                 |
| Minor     | 20    | documentation | `README.md:268`, `skills/hi/SKILL.md:148`     | "Uninstall: re-run with `--uninstall`." ambiguous on Windows (`-Uninstall`)                             |

## Fixed Issues

| Issue                                                | Commit    | Description                                                                              |
| ---------------------------------------------------- | --------- | ---------------------------------------------------------------------------------------- |
| `[switch]$Verbose` collision                         | `a6259ab` | Removed custom switch; `$script:IsVerbose = ($VerbosePreference -ne 'SilentlyContinue') -or $PSBoundParameters.ContainsKey('Verbose')` |
| sudo_prefix TTY gate + subshell exit                 | `a6259ab` | Gate on `[ -t 1 ]` or warm `sudo -n true`; return non-zero; callers resolve `SUDO=$(sudo_prefix) \|\| exit 4` once per step |
| Piped-curl candor note                               | `a6259ab` | Added "inspect-then-run" note to README and `/hi`, preserved word-for-word                |
| brew tap pipefail fragility                          | `a6259ab` | Captured `brew tap` output first, then grepped — no SIGPIPE false negative                |
| XDG_BIN_HOME writability probe                       | `a6259ab` | `[ -w ]` + probe-file create/remove; exit 4 with actionable message                       |
| Dangling `$*` in sudo error                          | `a6259ab` | Message rewritten to suggest `sudo -i` re-run; `$*` dropped                               |
| Multiline regex in Test-MarketplaceRegistered        | `a6259ab` | `[regex]::new('(?m)...')` for proper per-line anchors                                     |
| Missing curl timeouts                                | `a6259ab` | `--connect-timeout 15 --max-time 300 --retry 2 --retry-delay 3` on every internal download |
| Tar hardening                                        | `a6259ab` | Tries `--no-same-owner` first; falls back to plain extraction for older BSD tar           |
| winget already-installed exit codes                  | `a6259ab` | Re-probe `Get-Command revdiff` on non-zero; downgrade warn to debug if binary present     |
| sudo_prime / sudo_prefix gating consistency          | `a6259ab` | `sudo_prime` now returns non-zero when `sudo_prefix` fails; callers `sudo_prime \|\| exit 4` |
| `/etc/os-release` env leak                           | `a6259ab` | Parse in subshells: `LINUX_ID=$( ( . /etc/os-release 2>/dev/null; echo "${ID:-}" ) )`     |
| `--uninstall` / `-Uninstall` ambiguity               | `a6259ab` | Clarified: "Uninstall: re-run with `--uninstall` (macOS/Linux) or `-Uninstall` (Windows)." |
| `$script:IsVerbose` source of truth                  | `a6259ab` | Folded into the `[switch]$Verbose` fix (same line)                                        |

## Skipped Issues

| Issue                                        | Reason                                                                                      |
| -------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `find -maxdepth 3 -quit` BSD vs GNU          | Both macOS BSD find and GNU find support this; the review note is informational, no action needed. |

## Recommendations

- **Before merge:** run the manual scenarios on (a) a clean macOS host with Homebrew, (b) a fresh Debian 12 container via the piped-curl flow with `sudo` available, and (c) a Windows 10 host with stock PowerShell 5.1 calling `. .\install.ps1 -Help`. The `[ -t 1 ]` sudo gate fix is only fully validated by the Debian run.
- **Follow-up ticket candidates:** pinned-release install URLs (`/releases/download/v0.1.0/install.sh`) replacing the `main` ref in the README one-liner; a `scripts/test-install.sh` harness that runs the apt / dnf smokes in Docker; a GitHub Actions workflow that runs shellcheck + `pwsh -Command '[scriptblock]::Create(...)'` + the Docker smoke matrix on every PR.
- **Documentation:** the candor note recommends inspect-then-run; if adoption of that flow is a goal, mention it in the repo-top `README.md` intro rather than only in `## Installation`.
- **Security posture:** consider publishing a GPG-signed `install.sh.sig` alongside tagged releases to unlock a future `curl … | gpg --verify … | bash` flow.
