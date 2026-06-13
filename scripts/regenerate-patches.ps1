# Capture the current state of .\sources\<version>\ back into
# versions\<version>\patches\<platform>\ as a fresh git-format-patch series.
# Windows counterpart of regenerate-patches.sh.
#
# IMPORTANT: regenerate a platform's series only from a sources tree that has
# ONLY that platform's patches applied (format-patch captures everything
# between the pinned base and HEAD).
#
# Usage: scripts\regenerate-patches.ps1 3.44.0 [windows]
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Platform = 'windows'
)

. "$PSScriptRoot\_common.ps1"
Require-Version $Version
$lock = Load-SdkLock $Version

function Regen([string]$Label, [string]$BaseRef, [string]$Cwd, [string]$Out) {
    if (-not (Test-Path (Join-Path $Cwd '.git'))) {
        Write-Host "[$Label] no sources at $Cwd - skipping"
        return
    }
    Push-Location $Cwd
    try {
        git cat-file -e $BaseRef 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Error "[$Label] base ref '$BaseRef' unknown in $Cwd. Has sdk.lock drifted?" }
        if (git status --porcelain) { Write-Error "[$Label] $Cwd has uncommitted changes. Commit them in the source repo first." }
        Write-Host "[$Label] regenerating patches from $BaseRef..HEAD"
        Remove-Item -Recurse -Force $Out -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force $Out | Out-Null
        git format-patch --no-stat --no-signature "$BaseRef..HEAD" -o $Out
        if ($LASTEXITCODE -ne 0) { Write-Error "[$Label] git format-patch failed" }
    } finally {
        Pop-Location
    }
    $count = (Get-ChildItem $Out -Filter '*.patch' -ErrorAction SilentlyContinue).Count
    if ($count -eq 0) {
        Write-Host "[$Label] no patches produced - source is identical to base"
        Remove-Item $Out -ErrorAction SilentlyContinue
    } else {
        Write-Host "[$Label] wrote $count patches"
    }
}

$engineBase = if ($lock.ENGINE_COMMIT) { $lock.ENGINE_COMMIT } else { $lock.ENGINE_REF }
Regen 'engine' $engineBase (Sources-Dir $Version) (Patches-Dir $Version $Platform 'engine')
Regen 'dart' $lock.DART_COMMIT (Dart-SrcDir $Version) (Patches-Dir $Version $Platform 'dart')

Write-Host ''
Write-Host "Patches regenerated. Review: git -C $RepoRoot diff versions/$Version/patches/"
