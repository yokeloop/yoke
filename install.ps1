# yoke installer for Windows (PowerShell 5.1+)
# Installs the revdiff binary and registers the yoke marketplace with Claude Code.
# Supports idempotent re-runs and -Uninstall. Never installs the claude CLI or gh.

[CmdletBinding()]
param(
  [switch]$Uninstall,
  [switch]$SkipDeps,
  [switch]$SkipGh,
  # -Yes is reserved for future interactive prompts; currently non-interactive, matching install.sh.
  [switch]$Yes,
  [switch]$Verbose,
  [switch]$Help,
  [switch]$Version
)

$script:INSTALLER_VERSION = "0.1.0"
$script:REVDIFF_REPO = "umputun/revdiff"
$script:REVDIFF_BREW_TAP = "umputun/apps"
$script:YOKE_MARKETPLACE = "github:yokeloop/yoke"
$script:IsVerbose = $PSBoundParameters.ContainsKey('Verbose')

function Test-Color {
  try { return -not [Console]::IsOutputRedirected } catch { return $false }
}

function Write-Stderr {
  param([string]$Message, [string]$Color)
  if ((Test-Color) -and $Color) {
    $orig = [Console]::ForegroundColor
    try {
      [Console]::ForegroundColor = $Color
      [Console]::Error.WriteLine($Message)
    } finally {
      [Console]::ForegroundColor = $orig
    }
  } else {
    [Console]::Error.WriteLine($Message)
  }
}

function Write-LogInfo { param([string]$Message) Write-Stderr "[info] $Message" "Cyan" }
function Write-LogWarn { param([string]$Message) Write-Stderr "[warn] $Message" "Yellow" }
function Write-LogErr  { param([string]$Message) Write-Stderr "[err ] $Message" "Red" }
function Write-LogOk   { param([string]$Message) Write-Stderr "[ ok ] $Message" "Green" }
function Write-LogDebug {
  param([string]$Message)
  if ($script:IsVerbose) { Write-Stderr "[dbg ] $Message" "DarkGray" }
}

function Show-Help {
  $usage = @"
yoke-installer $($script:INSTALLER_VERSION)

Usage: install.ps1 [-Uninstall] [-SkipDeps] [-SkipGh] [-Yes] [-Verbose] [-Help] [-Version]

Flags:
  -Uninstall   Remove the yoke marketplace entry (binaries kept).
  -SkipDeps    Skip the revdiff install / verify step.
  -SkipGh      Suppress the gh-missing warning.
  -Yes         Assume yes to any prompt (reserved).
  -Verbose     Emit debug-level diagnostics.
  -Help        Print this help and exit 0.
  -Version     Print the installer version and exit 0.

Exit codes:
  0   success or idempotent no-op
  2   Claude Code CLI not found on PATH
  3   unsupported platform (PowerShell < 5) or no supported Windows package manager (winget or scoop)
  4   revdiff install failed
  5   claude plugin marketplace add failed
  6   post-install verification failed
"@
  [Console]::Error.WriteLine($usage)
}

function Show-Version {
  [Console]::Error.WriteLine("yoke-installer $($script:INSTALLER_VERSION)")
}

function Test-PsVersion {
  if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-LogErr "PowerShell 5.1 or later required. Detected: $($PSVersionTable.PSVersion)"
    exit 3
  }
}

function Test-ClaudeCli {
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-LogErr "Claude Code CLI not found on PATH. Install: https://docs.claude.com/claude-code"
    exit 2
  }
  Write-LogDebug "claude CLI present"
}

function Get-PackageManager {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-LogDebug "package manager: winget"
    return "winget"
  }
  if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-LogDebug "package manager: scoop"
    return "scoop"
  }
  Write-LogErr "No supported Windows package manager found (winget or scoop)"
  exit 3
}

function Install-Revdiff {
  param([string]$PackageManager)
  if ($SkipDeps) {
    Write-LogInfo "Skipping revdiff install (-SkipDeps)"
    return
  }
  if (Get-Command revdiff -ErrorAction SilentlyContinue) {
    Write-LogInfo "revdiff already installed"
    return
  }

  $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
  $hasScoop  = [bool](Get-Command scoop  -ErrorAction SilentlyContinue)
  $installed = $false

  if ($hasWinget) {
    Write-LogInfo "Installing revdiff via winget"
    & winget install --id umputun.revdiff --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0) {
      $installed = $true
    } else {
      Write-LogWarn "winget install failed (exit $LASTEXITCODE)"
    }
  }

  if (-not $installed -and $hasScoop) {
    Write-LogInfo "Installing revdiff via scoop"
    & scoop install revdiff
    if ($LASTEXITCODE -eq 0) {
      $installed = $true
    } else {
      Write-LogWarn "scoop install failed (exit $LASTEXITCODE)"
    }
  }

  if (-not $installed) {
    Write-LogErr "Failed to install revdiff via winget or scoop"
    exit 4
  }
  Write-LogOk "revdiff installed"
}

function Show-GhWarning {
  if ($SkipGh) { return }
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-LogWarn "gh CLI not found. /gp, /gca, /pr work without it, but GitHub-backed flows need it. Install: https://cli.github.com"
  } else {
    Write-LogDebug "gh CLI present"
  }
}

function Get-MarketplaceSubcommand {
  $helpOutput = ""
  try {
    $helpOutput = (& claude plugin marketplace --help 2>&1 | Out-String)
  } catch {
    $helpOutput = ""
  }
  $verb = "remove"
  if ($helpOutput -match '\bremove\b') {
    $verb = "remove"
  } elseif ($helpOutput -match '\brm\b') {
    $verb = "rm"
  }
  Write-LogInfo "Detected marketplace subcommand: $verb"
  return $verb
}

function Test-MarketplaceRegistered {
  $listOutput = ""
  try {
    $listOutput = (& claude plugin marketplace list 2>$null | Out-String)
  } catch {
    $listOutput = ""
  }
  return ($listOutput -match '(^|\s|/)yokeloop/yoke(\s|$)')
}

function Register-Marketplace {
  if (Test-MarketplaceRegistered) {
    Write-LogInfo "yoke marketplace already registered"
    return
  }
  Write-LogInfo "Registering yoke marketplace"
  & claude plugin marketplace add github:yokeloop/yoke
  if ($LASTEXITCODE -ne 0) {
    Write-LogErr "claude plugin marketplace add failed (exit $LASTEXITCODE)"
    exit 5
  }
  Write-LogOk "yoke marketplace registered"
}

function Test-Install {
  $failures = @()
  if (-not (Test-MarketplaceRegistered)) {
    $failures += "marketplace list missing yokeloop/yoke"
  }
  if (-not $SkipDeps) {
    if (-not (Get-Command revdiff -ErrorAction SilentlyContinue)) {
      $failures += "revdiff not on PATH"
    }
  }
  if ($failures.Count -gt 0) {
    Write-LogErr ("Verification failed: " + ($failures -join "; "))
    exit 6
  }
  Write-LogOk "Installation verified"
  Write-LogInfo "Next: open Claude Code and run /yoke:hi"
}

function Invoke-Uninstall {
  $verb = Get-MarketplaceSubcommand
  Write-LogInfo "Removing yoke marketplace entry"
  & claude plugin marketplace $verb yokeloop/yoke
  if ($LASTEXITCODE -ne 0) {
    Write-LogWarn "claude plugin marketplace $verb returned exit $LASTEXITCODE"
  } else {
    Write-LogOk "yoke marketplace entry removed"
  }
  Write-LogInfo "Remove revdiff manually: winget uninstall umputun.revdiff / scoop uninstall revdiff. Remove gh similarly."
}

function main {
  if ($Help)    { Show-Help;    exit 0 }
  if ($Version) { Show-Version; exit 0 }

  Test-PsVersion
  Test-ClaudeCli

  if ($Uninstall) {
    Invoke-Uninstall
    exit 0
  }

  $pm = Get-PackageManager
  Install-Revdiff -PackageManager $pm
  Show-GhWarning
  Register-Marketplace
  Test-Install
  exit 0
}

main
