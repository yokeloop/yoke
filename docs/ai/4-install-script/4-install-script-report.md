# Report: 4-install-script

**Plan:** docs/ai/4-install-script/4-install-script-plan.md
**Mode:** sub-agents (parallel T1+T2 → sequential T3 → parallel T4+T5)
**Status:** ✅ complete

## Tasks

| #   | Task                          | Status                | Commit                 | Concerns                                                           |
| --- | ----------------------------- | --------------------- | ---------------------- | ------------------------------------------------------------------ |
| 1   | Author `install.sh`           | ✅ DONE               | `aaaaacf`              | 5 low-severity style notes (see below)                             |
| 2   | Author `install.ps1`          | ✅ DONE (after fix)   | `a2ebc57`, `23a3adf`   | 1 critical exit-code + 2 major issues fixed in `23a3adf`           |
| 3   | Docs sync (README + /hi)      | ✅ DONE               | `62bbcca`              | Plan-level grep-count bug caught (Task 5 expected 0, not 2)        |
| 4   | Manual verification pass      | ⚠️ DONE_WITH_CONCERNS | —                      | shellcheck + pwsh absent on host; Group G checks MANUAL by design  |
| 5   | Validation                    | ✅ DONE               | —                      | All 9 gate checks green                                            |

## Post-implementation

| Step          | Status                | Commit    |
| ------------- | --------------------- | --------- |
| Polish        | ✅ done               | `40be260` |
| Validate      | ✅ pass               | —         |
| Documentation | ✅ no updates needed  | —         |
| Format        | ✅ clean (format:check) | —       |

## Concerns

### Task 1: install.sh (low-severity, non-blocking)

- `install.sh:244` — `trap "rm -rf '$tmpdir'" EXIT` inside `install_revdiff_tarball` overrides any prior EXIT trap. Cosmetic given no prior trap is set.
- `install.sh:326,328,357` — `$(sudo_prefix)` used in command position. Works under `set -euo pipefail`; a `SUDO=$(sudo_prefix); $SUDO cmd` pattern would be clearer. Polish rejected the rewrite because `sudo_prefix` calls `exit 4` on failure and the refactor changes error semantics.
- apt/dnf/yum branches in `install_revdiff` share ~90% shape. Polish intentionally skipped extraction: a helper would obscure per-manager semantics (`dpkg -f install` fallback vs rpm direct).
- `install.sh` help text now documents exit 64 (unknown arg) — addressed in polish commit `40be260`.
- `detect_marketplace_subcmd` moved from `main` into `uninstall` only — addressed in polish commit `40be260`.

### Task 2: install.ps1 (fixed in `23a3adf`)

- **Critical:** PS-version gate used `exit 1`, outside the contract set `0/2/3/4/5/6`. Fixed to `exit 3` (unsupported platform).
- **Major:** `Write-LogDebug` read function-scope `$Verbose` (always false). Fixed to `$script:IsVerbose = $PSBoundParameters.ContainsKey('Verbose')` at entry.
- **Major:** `Warn-Gh` used a non-approved PowerShell verb. Renamed to `Show-GhWarning`.
- **Not a defect:** reviewer asked for an interactive y/n prompt on `-Uninstall`. Deliberately not added — the plan's "one confirmation line" means "post-action status line" (parallel with `install.sh`); `-Yes` now carries a `(reserved)` note in the help text.

### Task 3: plan-level grep-count bug

- Plan Task 5 expected `rg -F 'marketplace add github:yokeloop/yoke' README.md skills/` → 2 matches. After the Req-12 rewrite the docs no longer mention the marketplace-add command directly (the installer invokes it internally), so the actual count is 0. The Validation task was dispatched with the corrected expectation (0 matches), and it passed. The plan file retains the original check — future readers should interpret it in light of this report.

### Task 4: host-limited checks

- `shellcheck` not installed on the macOS host — the `bash -n install.sh` syntax check passed; static-analysis coverage relies on CI or a local install.
- `pwsh` not installed on the macOS host — `install.ps1` parse check skipped. Static greps for PS 7-only syntax (`??`, `?.`, `ForEach-Object -Parallel`, ternary) returned 0 matches. Final check on a PowerShell 5.1 Windows 10 host remains MANUAL.
- Group G (real macOS brew smoke, Docker debian:12 / fedora:40 smoke, Windows PS 5.1 parse, network-blocked-post-registration exit-6 smoke) is MANUAL by design — these require disposable VMs / Docker and would mutate host state.
- README Installation block has one trailing blank line not present in `skills/hi/SKILL.md`. Block bodies are byte-identical; the diff is a section-boundary artifact.

## Validation

- `pnpm run format:check` ✅ "All matched files use Prettier code style!"
- `bash -n install.sh` ✅ rc=0
- `python3` JSON manifest validation ✅ OK (`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`)
- `head -1 skills/*/SKILL.md` ✅ every SKILL.md starts with `---`
- `rg -F 'claude marketplace add'` across repo ✅ 0 matches (no old-verb drift)
- `rg -F 'claude plugin marketplace add github:yokeloop/yoke' install.sh install.ps1` ✅ 2 matches (one per installer)
- `rg -F '/plugin marketplace add umputun/revdiff' README.md` ✅ 1 match (preserved)
- `rg -F '/plugin install revdiff@umputun-revdiff' README.md` ✅ 1 match (preserved)

Lint / type-check / test / build: N/A (markdown-only plugin; no scripts beyond `format:check`).

## Changes summary

| File                            | Action   | Description                                                                                  |
| ------------------------------- | -------- | -------------------------------------------------------------------------------------------- |
| `install.sh`                    | created  | Monolithic bash installer, mode 100755, ~485 lines; constants, log helpers, preflight, detect_pm, revdiff matrix (brew/apt/dnf/yum/pacman/tarball), gh warn, `claude plugin marketplace` register + verify + uninstall |
| `install.ps1`                   | created  | PowerShell 5.1+ installer, ~255 lines; mirrors install.sh feature set for Windows (winget → scoop fallback)                                                                   |
| `README.md`                     | modified | Rewrote `## Installation` as three-subsection one-liner flow; trimmed `## Interactive review (revdiff)` `### Install` subsection to note the installer provisions the binary  |
| `skills/hi/SKILL.md`            | modified | Replaced `## Installation` block with word-for-word copy of the README block                 |

## Commits

- `a2ebc57` #4 feat(4-install-script): add install.ps1 installer for Windows
- `aaaaacf` #4 feat(4-install-script): add install.sh installer for macOS and Linux
- `23a3adf` #4 fix(4-install-script): address spec-review feedback on install.ps1
- `62bbcca` #4 docs(4-install-script): switch install docs to one-command flow
- `40be260` #4 refactor(4-install-script): simplify installer scripts
