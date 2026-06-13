# Assemble the Windows engine artifacts consumer apps need: the cache-layout
# flutter zips for each built host variant. Windows counterpart of package.sh.
#
# The zips inside out\<v>\host_*\zip_archives\windows-x64*\windows-x64-flutter.zip
# contain exactly the file set flutter_tools' UnpackWindows copies
# (flutter_windows.dll/.lib/.pdb + headers), so consumers extract them over
# <flutter-sdk>\bin\cache\artifacts\engine\windows-x64{,-release}\.
#
# Usage: scripts\package.ps1 3.44.0
param([Parameter(Mandatory = $true)][string]$Version)

. "$PSScriptRoot\_common.ps1"
Require-Version $Version

$outVersion = Join-Path $OutRoot $Version
$pkgDir = Join-Path $OutRoot 'packages'
$stage = Join-Path $pkgDir "stage-windows-$Version"
$zip = Join-Path $pkgDir "flutter-plezy-windows-$Version.zip"

Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stage | Out-Null

$items = @(
    @{ Variant = 'host_debug';   CacheDir = 'windows-x64' },
    @{ Variant = 'host_release'; CacheDir = 'windows-x64-release' }
)

$missing = @()
foreach ($item in $items) {
    $archive = Join-Path $outVersion "$($item.Variant)\zip_archives"
    $flutterZip = Get-ChildItem $archive -Recurse -Filter 'windows-x64-flutter.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $flutterZip) {
        $missing += "$($item.Variant): zip_archives\...\windows-x64-flutter.zip"
        continue
    }
    $dst = Join-Path $stage $item.CacheDir
    New-Item -ItemType Directory -Force $dst | Out-Null
    Expand-Archive $flutterZip.FullName -DestinationPath $dst -Force
}

if ($missing.Count -gt 0) {
    Write-Error ("missing build outputs - run build-engine.ps1 for these variants first:`n  " + ($missing -join "`n  "))
}

Remove-Item $zip -ErrorAction SilentlyContinue
Compress-Archive -Path "$stage\*" -DestinationPath $zip
Remove-Item -Recurse -Force $stage

Get-Item $zip | Select-Object FullName, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
Write-Host "Done. Upload with: gh release create windows-v$Version $zip"
