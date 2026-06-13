# Common helpers dot-sourced by the other Windows scripts. Not executed directly.
# PowerShell counterpart of _common.sh for Windows host engine builds.

$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:SourcesRoot = Join-Path $RepoRoot 'sources'
$script:OutRoot = Join-Path $RepoRoot 'out'

function Require-Version([string]$Version) {
    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-Error 'version arg required (e.g. 3.44.0)'
    }
}

# Parse versions/<v>/sdk.lock (KEY=VALUE lines, bash-sourceable) into a hashtable.
function Load-SdkLock([string]$Version) {
    $lock = Join-Path $RepoRoot "versions\$Version\sdk.lock"
    if (-not (Test-Path $lock)) {
        Write-Error "no sdk.lock at $lock"
    }
    $vars = @{}
    foreach ($line in Get-Content $lock) {
        if ($line -match '^\s*([A-Z_][A-Z0-9_]*)=(.*)$') {
            $vars[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return $vars
}

function Sources-Dir([string]$Version) { Join-Path $SourcesRoot $Version }
function Engine-SrcDir([string]$Version) { Join-Path (Sources-Dir $Version) 'engine\src\flutter' }
function Dart-SrcDir([string]$Version) { Join-Path (Engine-SrcDir $Version) 'third_party\dart' }

function Patches-Dir([string]$Version, [string]$Platform, [string]$Component) {
    Join-Path $RepoRoot "versions\$Version\patches\$Platform\$Component"
}

# Put depot_tools on PATH (cloning into ./depot_tools if needed) and set the
# env vars Windows engine builds require. depot_tools bootstraps its own
# pinned git + python on first use, so the user's git config can't corrupt
# the checkout (line endings etc.).
function Ensure-DepotTools {
    $dt = Join-Path $RepoRoot 'depot_tools'
    if (-not (Get-Command gclient.bat -ErrorAction SilentlyContinue)) {
        if (-not (Test-Path $dt)) {
            Write-Host "[depot_tools] not on PATH - cloning into $dt"
            git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git $dt
        }
        $env:PATH = "$dt;$env:PATH"
    }
    # Use the locally installed Visual Studio, not Google's internal toolchain.
    $env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
}
