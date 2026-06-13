# Delegates to the version-specific build.ps1, which knows the right gn args
# for that Flutter release. Output: .\out\<version>\<variant>\.
#
# Usage: scripts\build-engine.ps1 3.44.0 host_release
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Variant
)

. "$PSScriptRoot\_common.ps1"
Require-Version $Version

$vbuild = Join-Path $RepoRoot "versions\$Version\build.ps1"
if (-not (Test-Path $vbuild)) {
    Write-Error "no build.ps1 for version $Version at $vbuild"
}

& $vbuild $Variant
exit $LASTEXITCODE
