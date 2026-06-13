# Build one Windows host variant of the 3.44.0 engine.
# Expects sources synced via scripts\fetch-sources.ps1 and (optionally) patched
# via scripts\apply-patches.ps1 3.44.0 windows.
#
# Usage: versions\3.44.0\build.ps1 <variant>
# or:    scripts\build-engine.ps1 3.44.0 <variant>
#
# Variants (gn args mirror the engine's own CI builder windows_host_engine.json):
#   host_debug    - what `flutter run` (debug) loads from cache\...\windows-x64\
#   host_release  - what `flutter build windows --release` loads
#
# Note: unlike the tvOS variants there is no verify_sdk_hash override here -
# the Windows patch series does not touch the Dart SDK, so the prebuilt
# dart-sdk hash stays valid.
param([Parameter(Mandatory = $true)][string]$Variant)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. "$repoRoot\scripts\_common.ps1"
Ensure-DepotTools

$version = '3.44.0'

$gnFlags = switch ($Variant) {
    'host_debug'   { @('--runtime-mode=debug', '--no-lto') }
    'host_release' { @('--runtime-mode=release', '--no-lto') }
    default        { Write-Error "unknown variant $Variant (host_debug | host_release)" }
}

$monoRoot = Sources-Dir $version
$engineSrc = Join-Path $monoRoot 'engine\src'
if (-not (Test-Path (Join-Path $engineSrc 'flutter'))) {
    Write-Error "engine source missing at $engineSrc\flutter - run fetch-sources.ps1 first"
}

# The engine pins Windows SDK 10.0.22621.0; the windows patch series makes
# setup_toolchain.py fall back to the newest installed SDK when the pinned
# one is missing (the compiler is the checkout's own clang either way).
# Install SDK 10.0.22621 for exact CI parity.

$outDir = Join-Path $OutRoot "$version\$Variant"
New-Item -ItemType Directory -Force (Split-Path -Parent $outDir) | Out-Null

Push-Location $engineSrc
try {
    Write-Host "[gn] $engineSrc -> $($gnFlags -join ' ')"
    python3 .\flutter\tools\gn @gnFlags
    if ($LASTEXITCODE -ne 0) { Write-Error "gn failed with exit code $LASTEXITCODE" }

    $gnOut = "out\$Variant"
    if (-not (Test-Path "$gnOut\args.gn")) {
        # tools/gn names the out dir from the config; fall back to newest.
        $gnOut = (Get-ChildItem out -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        if (-not (Test-Path "$gnOut\args.gn")) { Write-Error "couldn't locate gn output dir under $engineSrc\out" }
    }
    Write-Host "[gn] output dir: $gnOut"

    # Targets per ci/builders/windows_host_engine.json. archives:windows_flutter
    # emits the cache-layout zip (zip_archives\windows-x64*\windows-x64-flutter.zip).
    Write-Host "[ninja] -C $gnOut windows gen_snapshot flutter/build/archives:windows_flutter"
    ninja -C $gnOut windows gen_snapshot flutter/build/archives:windows_flutter
    if ($LASTEXITCODE -ne 0) { Write-Error "ninja failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

# Promote the artifacts package.ps1 needs to the canonical out\<version>\<variant>\.
# (Mirror only what consumers use - the full gn out dir is tens of GB.)
$src = Join-Path $engineSrc $gnOut
Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $outDir | Out-Null
foreach ($item in @('zip_archives', 'flutter_windows.dll', 'flutter_windows.dll.lib', 'flutter_windows.dll.pdb', 'gen_snapshot.exe')) {
    $p = Join-Path $src $item
    if (Test-Path $p) {
        Copy-Item -Recurse -Force $p (Join-Path $outDir $item)
    }
}

Write-Host ''
Write-Host "Built $Variant -> $outDir"
