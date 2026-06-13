# Sync the Flutter monorepo + all its engine deps into .\sources\<version>\
# using gclient. Windows counterpart of fetch-sources.sh.
#
# Usage: scripts\fetch-sources.ps1 3.44.0
param([Parameter(Mandatory = $true)][string]$Version)

. "$PSScriptRoot\_common.ps1"
Require-Version $Version
$lock = Load-SdkLock $Version
Ensure-DepotTools

$srcRoot = Sources-Dir $Version
New-Item -ItemType Directory -Force $srcRoot | Out-Null

$gclientFile = Join-Path $srcRoot '.gclient'
if (-not (Test-Path $gclientFile)) {
    Write-Host "[gclient] writing $gclientFile"
    @"
solutions = [
  {
    "managed": False,
    "name": ".",
    "url": "$($lock.ENGINE_REPO)",
    "deps_file": "DEPS",
    "custom_deps": {},
    "safesync_url": "",
  },
]
"@ | Out-File -Encoding ascii $gclientFile
}

$rev = if ($lock.ENGINE_COMMIT) { $lock.ENGINE_COMMIT } else { $lock.ENGINE_REF }
Write-Host "[gclient] syncing $srcRoot at $rev"
Push-Location $srcRoot
try {
    & gclient.bat sync --revision ".@$rev" --no-history --with_tags
    if ($LASTEXITCODE -ne 0) { Write-Error "gclient sync failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

Write-Host ''
Write-Host "Sources synced into $srcRoot"
Write-Host "Next: scripts\apply-patches.ps1 $Version windows"
