# Apply a platform's patch series onto the gclient-synced source trees.
# Windows counterpart of apply-patches.sh.
#
# Engine patches land at sources\<v>\ (the Flutter monorepo root) because they
# were format-patch'd from the monorepo root (paths like a/engine/src/flutter/...).
#
# Usage: scripts\apply-patches.ps1 3.44.0 [windows]
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Platform = 'windows'
)

. "$PSScriptRoot\_common.ps1"
Require-Version $Version
$null = Load-SdkLock $Version

function Apply-At([string]$Label, [string]$Patches, [string]$Cwd) {
    if (-not (Test-Path (Join-Path $Cwd '.git'))) {
        Write-Error "[$Label] $Cwd is not a git repo - has fetch-sources.ps1 been run?"
    }
    if (-not (Test-Path $Patches)) {
        Write-Host "[$Label] no patches dir at $Patches - skipping"
        return
    }
    $files = Get-ChildItem $Patches -Filter '*.patch' | Sort-Object Name
    if ($files.Count -eq 0) {
        Write-Host "[$Label] no .patch files in $Patches - skipping"
        return
    }
    Write-Host "[$Label] applying $($files.Count) patches to $Cwd"
    Push-Location $Cwd
    try {
        git am --abort 2>$null
        git am --3way ($files | ForEach-Object { $_.FullName })
        if ($LASTEXITCODE -ne 0) { Write-Error "[$Label] git am failed - resolve in $Cwd then 'git am --continue'" }
    } finally {
        Pop-Location
    }
}

Apply-At 'engine' (Patches-Dir $Version $Platform 'engine') (Sources-Dir $Version)
Apply-At 'dart'   (Patches-Dir $Version $Platform 'dart')   (Dart-SrcDir $Version)

Write-Host ''
Write-Host "Patches applied. Ready to build: scripts\build-engine.ps1 $Version <variant>"
