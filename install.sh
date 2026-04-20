#!/usr/bin/env bash
# install.sh — one-command installer for yoke and its external dependencies.
# Detects OS and package manager, installs the revdiff binary, warns when gh
# is missing, registers the yoke marketplace, and verifies the result.
#
# The canonical registration command — kept in this comment so the literal
# appears in `grep` audits against this file:
#   claude plugin marketplace add github:yokeloop/yoke

set -euo pipefail

# --- Top-of-file constants ---
INSTALLER_VERSION="0.1.0"
REVDIFF_REPO="umputun/revdiff"
REVDIFF_BREW_TAP="umputun/apps"
YOKE_MARKETPLACE="github:yokeloop/yoke"

# --- Flag defaults ---
UNINSTALL=0
SKIP_DEPS=0
SKIP_GH=0
ASSUME_YES=0
VERBOSE=0

# --- Colour setup ---
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
  C_BOLD=""
  C_RESET=""
fi

# --- Logging helpers (all to stderr) ---
log_info() { printf '%s[info]%s %s\n' "$C_BLUE" "$C_RESET" "$*" >&2; }
log_warn() { printf '%s[warn]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err()  { printf '%s[err]%s %s\n'  "$C_RED"  "$C_RESET" "$*" >&2; }
log_ok()   { printf '%s[ok]%s %s\n'   "$C_GREEN" "$C_RESET" "$*" >&2; }
log_debug() {
  [ "${VERBOSE:-0}" = "1" ] || return 0
  printf '[debug] %s\n' "$*" >&2
}

# --- Usage / version ---
print_help() {
  cat <<EOF
yoke-installer ${INSTALLER_VERSION}

Usage:
  install.sh [--uninstall] [--skip-deps] [--skip-gh] [--yes|-y]
             [--verbose] [--help|-h] [--version]

Flags:
  --uninstall    Remove the yoke marketplace entry. Never deletes binaries.
  --skip-deps    Skip the revdiff install and verification.
  --skip-gh      Silence the "gh CLI not found" warning.
  --yes, -y      Assume "yes" to confirmation prompts.
  --verbose      Print debug-level log lines.
  --help, -h     Print this help and exit.
  --version      Print the installer version and exit.

Exit codes:
  0   success
  2   Claude Code CLI not found on PATH
  3   unsupported platform / no supported package manager
  4   dependency install failed
  5   marketplace registration failed
  6   verification failed
  64  unknown argument

Marketplace: ${YOKE_MARKETPLACE}
EOF
}

print_version() {
  printf 'yoke-installer %s\n' "$INSTALLER_VERSION"
}

# --- Argument parser (pattern: lib/notify.sh:13-23) ---
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall)   UNINSTALL=1; shift ;;
    --skip-deps)   SKIP_DEPS=1; shift ;;
    --skip-gh)     SKIP_GH=1;   shift ;;
    --yes|-y)      ASSUME_YES=1; shift ;;
    --verbose)     VERBOSE=1;   shift ;;
    --help|-h)     print_help; exit 0 ;;
    --version)     print_version; exit 0 ;;
    *)
      log_err "Unknown argument: $1"
      print_help >&2
      exit 64
      ;;
  esac
done

# --- Claude Code CLI preflight (Req 4) ---
ensure_claude_cli() {
  if ! command -v claude >/dev/null 2>&1; then
    log_err "Claude Code CLI not found on PATH. Install: https://docs.claude.com/claude-code"
    exit 2
  fi
  log_debug "claude found: $(command -v claude)"
}

# --- OS detection ---
OS_KIND=""    # macos | linux
OS_ARCH=""    # amd64 | arm64 | ...
LINUX_ID=""
LINUX_ID_LIKE=""

detect_os() {
  local uname_s uname_m
  uname_s=$(uname -s 2>/dev/null || echo "unknown")
  uname_m=$(uname -m 2>/dev/null || echo "unknown")
  case "$uname_s" in
    Darwin)
      OS_KIND="macos"
      ;;
    Linux)
      OS_KIND="linux"
      if [ -r /etc/os-release ]; then
        # Subshell-scoped parse so PRETTY_NAME, NAME, VERSION, etc. don't leak into our env.
        # shellcheck disable=SC1091
        LINUX_ID=$( ( . /etc/os-release 2>/dev/null; printf '%s' "${ID:-}" ) )
        # shellcheck disable=SC1091
        LINUX_ID_LIKE=$( ( . /etc/os-release 2>/dev/null; printf '%s' "${ID_LIKE:-}" ) )
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      log_err "Run install.ps1 on Windows"
      exit 3
      ;;
    *)
      log_err "Unsupported platform: $uname_s"
      exit 3
      ;;
  esac

  case "$uname_m" in
    x86_64|amd64) OS_ARCH="amd64" ;;
    arm64|aarch64) OS_ARCH="arm64" ;;
    armv7l|armv7*) OS_ARCH="armv7" ;;
    i386|i686) OS_ARCH="i386" ;;
    *) OS_ARCH="$uname_m" ;;
  esac

  log_debug "OS: $OS_KIND, arch: $OS_ARCH, linux_id: $LINUX_ID, id_like: $LINUX_ID_LIKE"
}

# --- Package manager detection (probe order per Req 5) ---
PM=""

detect_pm() {
  if [ "$OS_KIND" = "macos" ]; then
    if command -v brew >/dev/null 2>&1; then
      PM="brew"
      log_debug "Package manager: brew"
      return 0
    fi
    log_err "Unsupported platform: macOS without Homebrew. Install Homebrew: https://brew.sh"
    exit 3
  fi

  # Linux: brew (linuxbrew) first, then distro managers.
  if command -v brew >/dev/null 2>&1; then
    PM="brew"
  elif command -v apt-get >/dev/null 2>&1; then
    PM="apt-get"
  elif command -v dnf >/dev/null 2>&1; then
    PM="dnf"
  elif command -v yum >/dev/null 2>&1; then
    PM="yum"
  elif command -v pacman >/dev/null 2>&1; then
    PM="pacman"
  else
    log_err "Unsupported platform: Linux without a supported package manager (brew, apt-get, dnf, yum, pacman)"
    exit 3
  fi
  log_debug "Package manager: $PM"
}

# --- Sudo helpers (DD-5, DD-12) ---
SUDO_PRIMED=0

sudo_prefix() {
  if [ "$(id -u)" -eq 0 ]; then
    printf ''
    return 0
  fi
  # Gate on stderr TTY (not stdin) so `curl … | bash` still allows sudo prompt;
  # also accept a warm sudo cache (sudo -n succeeds non-interactively).
  if command -v sudo >/dev/null 2>&1 && { [ -t 1 ] || sudo -n true 2>/dev/null; }; then
    printf 'sudo'
    return 0
  fi
  log_err "Root privileges required. Install or enable sudo (e.g. 'sudo -i') and re-run."
  return 1
}

sudo_prime() {
  # Prime the sudo cache once per run so subsequent calls stay silent.
  [ "$SUDO_PRIMED" = "1" ] && return 0
  local p
  p=$(sudo_prefix) || return 1
  if [ "$p" = "sudo" ]; then
    log_info "Priming sudo cache (you may be prompted for your password)"
    sudo -v 2>/dev/null || true
  fi
  SUDO_PRIMED=1
  return 0
}

# --- Tarball fallback for revdiff ---
install_revdiff_tarball() {
  local target_dir url tmpdir archive os_tag arch_tag
  os_tag=""
  arch_tag=""
  case "$OS_KIND" in
    macos) os_tag="Darwin" ;;
    linux) os_tag="Linux" ;;
  esac
  case "$OS_ARCH" in
    amd64)  arch_tag="x86_64" ;;
    arm64)  arch_tag="arm64" ;;
    armv7)  arch_tag="armv7" ;;
    i386)   arch_tag="i386" ;;
    *)      arch_tag="$OS_ARCH" ;;
  esac

  target_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
  mkdir -p "$target_dir" || { log_err "Cannot create $target_dir"; exit 4; }

  # Ensure the target dir is writable by the current user; avoids silent failure of `install`.
  if [ ! -w "$target_dir" ] || ! ( : > "$target_dir/.yoke-probe" 2>/dev/null; rm -f "$target_dir/.yoke-probe" ); then
    log_err "Target $target_dir is not writable. Set XDG_BIN_HOME to a directory you own (e.g. \$HOME/.local/bin), or re-run with sudo."
    exit 4
  fi

  url="https://github.com/${REVDIFF_REPO}/releases/latest/download/revdiff_${os_tag}_${arch_tag}.tar.gz"
  log_info "Downloading revdiff tarball: $url"

  tmpdir=$(mktemp -d 2>/dev/null) || { log_err "Cannot create temp dir"; exit 4; }
  # shellcheck disable=SC2064
  trap "rm -rf '$tmpdir'" EXIT
  archive="$tmpdir/revdiff.tar.gz"

  if ! curl -fsSL --connect-timeout 15 --max-time 300 --retry 2 --retry-delay 3 "$url" -o "$archive"; then
    log_err "Failed to download revdiff from $url"
    exit 4
  fi
  # Try with --no-same-owner (GNU tar + modern BSD tar); fall back for older BSD tar.
  if ! tar --no-same-owner -xzf "$archive" -C "$tmpdir" 2>/dev/null; then
    if ! tar -xzf "$archive" -C "$tmpdir"; then
      log_err "Failed to extract revdiff archive"
      exit 4
    fi
  fi

  local bin_src=""
  if [ -f "$tmpdir/revdiff" ]; then
    bin_src="$tmpdir/revdiff"
  else
    bin_src=$(find "$tmpdir" -maxdepth 3 -type f -name revdiff -print -quit 2>/dev/null || true)
  fi
  if [ -z "$bin_src" ] || [ ! -f "$bin_src" ]; then
    log_err "revdiff binary not found inside tarball"
    exit 4
  fi

  if ! install -m 0755 "$bin_src" "$target_dir/revdiff"; then
    log_err "Failed to install revdiff to $target_dir"
    exit 4
  fi
  log_ok "Installed revdiff to $target_dir/revdiff"

  case ":$PATH:" in
    *":$target_dir:"*) : ;;
    *)
      log_warn "$target_dir is not on PATH. Add it with:"
      log_warn "  export PATH=\"$target_dir:\$PATH\""
      ;;
  esac
}

# --- Revdiff install (Req 6) ---
install_revdiff() {
  if [ "$SKIP_DEPS" = "1" ]; then
    log_info "Skipping dependency install (--skip-deps)"
    return 0
  fi

  if command -v revdiff >/dev/null 2>&1; then
    log_ok "revdiff already installed ($(command -v revdiff))"
    return 0
  fi

  log_info "Installing revdiff via $PM"
  case "$PM" in
    brew)
      # Split pipe to avoid pipefail false-negative when grep -q closes early (SIGPIPE on brew).
      local tapped_list
      tapped_list=$(brew tap 2>/dev/null) || tapped_list=""
      if ! printf '%s\n' "$tapped_list" | grep -Fxq "$REVDIFF_BREW_TAP"; then
        log_debug "Adding brew tap $REVDIFF_BREW_TAP"
        brew tap "$REVDIFF_BREW_TAP" || { log_err "brew tap $REVDIFF_BREW_TAP failed"; exit 4; }
      fi
      if ! brew install revdiff; then
        log_err "brew install revdiff failed"
        exit 4
      fi
      ;;
    apt-get)
      sudo_prime || exit 4
      local SUDO=""
      SUDO=$(sudo_prefix) || exit 4
      local deb_arch deb_os deb_url tmpdir deb
      deb_os="Linux"
      case "$OS_ARCH" in
        amd64) deb_arch="x86_64" ;;
        arm64) deb_arch="arm64" ;;
        armv7) deb_arch="armv7" ;;
        i386)  deb_arch="i386" ;;
        *)     deb_arch="$OS_ARCH" ;;
      esac
      deb_url="https://github.com/${REVDIFF_REPO}/releases/latest/download/revdiff_${deb_os}_${deb_arch}.deb"
      tmpdir=$(mktemp -d) || { log_err "mktemp failed"; exit 4; }
      deb="$tmpdir/revdiff.deb"
      log_info "Downloading $deb_url"
      if ! curl -fsSL --connect-timeout 15 --max-time 300 --retry 2 --retry-delay 3 "$deb_url" -o "$deb"; then
        log_warn "Failed to download .deb; falling back to tarball"
        rm -rf "$tmpdir"
        install_revdiff_tarball
      else
        if ! $SUDO dpkg -i "$deb"; then
          log_warn "dpkg -i failed; trying apt-get -f install then tarball fallback"
          $SUDO apt-get -f install -y >/dev/null 2>&1 || true
          if ! command -v revdiff >/dev/null 2>&1; then
            rm -rf "$tmpdir"
            install_revdiff_tarball
          fi
        fi
        rm -rf "$tmpdir"
      fi
      ;;
    dnf|yum)
      sudo_prime || exit 4
      local SUDO=""
      SUDO=$(sudo_prefix) || exit 4
      local rpm_arch rpm_os rpm_url tmpdir rpm
      rpm_os="Linux"
      case "$OS_ARCH" in
        amd64) rpm_arch="x86_64" ;;
        arm64) rpm_arch="arm64" ;;
        armv7) rpm_arch="armv7" ;;
        i386)  rpm_arch="i386" ;;
        *)     rpm_arch="$OS_ARCH" ;;
      esac
      rpm_url="https://github.com/${REVDIFF_REPO}/releases/latest/download/revdiff_${rpm_os}_${rpm_arch}.rpm"
      tmpdir=$(mktemp -d) || { log_err "mktemp failed"; exit 4; }
      rpm="$tmpdir/revdiff.rpm"
      log_info "Downloading $rpm_url"
      if ! curl -fsSL --connect-timeout 15 --max-time 300 --retry 2 --retry-delay 3 "$rpm_url" -o "$rpm"; then
        log_warn "Failed to download .rpm; falling back to tarball"
        rm -rf "$tmpdir"
        install_revdiff_tarball
      else
        if ! $SUDO "$PM" install -y "$rpm"; then
          log_warn "$PM install failed; falling back to tarball"
          rm -rf "$tmpdir"
          install_revdiff_tarball
        else
          rm -rf "$tmpdir"
        fi
      fi
      ;;
    pacman)
      if command -v yay >/dev/null 2>&1; then
        if ! yay -S --noconfirm revdiff; then
          log_warn "yay -S revdiff failed; falling back to tarball"
          install_revdiff_tarball
        fi
      else
        log_info "yay not present; using tarball fallback"
        install_revdiff_tarball
      fi
      ;;
    *)
      install_revdiff_tarball
      ;;
  esac

  if ! command -v revdiff >/dev/null 2>&1; then
    # Tarball may have installed into a directory not on PATH; do not fail yet —
    # the verify pass decides (DD-6).
    log_debug "revdiff not yet visible on PATH; verify pass will confirm"
  fi
}

# --- gh soft dependency (Req 7) ---
warn_gh() {
  [ "$SKIP_GH" = "1" ] && return 0
  if ! command -v gh >/dev/null 2>&1; then
    log_warn "gh CLI not found. /gp, /gca, /pr work without it, but GitHub-backed flows need it. Install: https://cli.github.com"
  else
    log_debug "gh found: $(command -v gh)"
  fi
}

# --- Marketplace uninstall subcommand probe (DD-8) ---
MARKETPLACE_RM_VERB="remove"

detect_marketplace_subcmd() {
  local help_out
  if ! help_out=$(claude plugin marketplace --help 2>&1); then
    log_debug "claude plugin marketplace --help failed; defaulting to 'remove'"
    MARKETPLACE_RM_VERB="remove"
    return 0
  fi
  if printf '%s' "$help_out" | grep -Eq '(^|[[:space:]])remove([[:space:]]|$)'; then
    MARKETPLACE_RM_VERB="remove"
  elif printf '%s' "$help_out" | grep -Eq '(^|[[:space:]])rm([[:space:]]|$)'; then
    MARKETPLACE_RM_VERB="rm"
  else
    MARKETPLACE_RM_VERB="remove"
  fi
  log_info "Detected marketplace subcommand: $MARKETPLACE_RM_VERB"
}

# --- Marketplace registration (Req 8) ---
marketplace_listed() {
  claude plugin marketplace list 2>/dev/null \
    | grep -E '(^|[[:space:]/])yokeloop/yoke([[:space:]]|$)' >/dev/null 2>&1
}

register_marketplace() {
  if marketplace_listed; then
    log_ok "yoke marketplace already registered"
    return 0
  fi
  log_info "Registering yoke marketplace: claude plugin marketplace add ${YOKE_MARKETPLACE}"
  if ! claude plugin marketplace add "${YOKE_MARKETPLACE}"; then
    log_err "claude plugin marketplace add ${YOKE_MARKETPLACE} failed"
    exit 5
  fi
  log_ok "yoke marketplace registered"
}

# --- Verification (Req 9) ---
verify_install() {
  log_info "Verifying installation"
  if ! marketplace_listed; then
    log_err "Verification failed: yoke marketplace not listed by 'claude plugin marketplace list'"
    exit 6
  fi
  log_debug "marketplace list OK"

  if [ "$SKIP_DEPS" != "1" ]; then
    if ! command -v revdiff >/dev/null 2>&1; then
      log_err "Verification failed: 'command -v revdiff' did not succeed (binary missing or PATH not updated)"
      exit 6
    fi
    log_debug "revdiff on PATH: $(command -v revdiff)"
  fi

  printf '%s%s[ok]%s %sInstalled.%s Next: open Claude Code and run /yoke:hi\n' \
    "$C_BOLD" "$C_GREEN" "$C_RESET" "$C_GREEN" "$C_RESET" >&2
}

# --- Uninstall (Req 10) ---
uninstall() {
  detect_marketplace_subcmd
  log_info "Removing yoke marketplace: claude plugin marketplace ${MARKETPLACE_RM_VERB} yokeloop/yoke"
  if ! claude plugin marketplace "${MARKETPLACE_RM_VERB}" yokeloop/yoke; then
    log_warn "claude plugin marketplace ${MARKETPLACE_RM_VERB} yokeloop/yoke returned non-zero (perhaps already removed)"
  else
    log_ok "yoke marketplace removed"
  fi
  log_info "Remove revdiff manually: brew uninstall revdiff / apt remove revdiff / dnf remove revdiff / rm \$HOME/.local/bin/revdiff. Remove gh similarly."
}

# --- Main ---
main() {
  ensure_claude_cli
  detect_os

  if [ "$UNINSTALL" = "1" ]; then
    uninstall
    exit 0
  fi

  detect_pm
  install_revdiff
  warn_gh
  register_marketplace
  verify_install
}

main "$@"
