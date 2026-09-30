$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
# CI hygiene: container stdout is redirected, where PowerShell would otherwise
# serialize progress records (e.g. "Preparing modules for first use" on the
# first Pester import) as CLIXML noise into the log. Our code uses no
# Write-Progress, so silencing it loses nothing.
$ProgressPreference = 'SilentlyContinue'
. "$PSScriptRoot\lib.ps1"

function Invoke-E2EFixture {
    param(
        [Parameter(Mandatory)] [string] $Name
    )
    $result = Invoke-Pester -Path "$PSScriptRoot\$Name.Tests.ps1" -Output Detailed -PassThru
    if ($result.FailedCount -gt 0) {
        throw "FAIL $Name.Tests.ps1: $($result.FailedCount) test(s) failed ($($result.PassedCount) passed, $($result.SkippedCount) skipped)"
    }
}

$flavor = if ($env:FLAVOR) { $env:FLAVOR } else { throw 'FAIL FLAVOR is not set' }
$mirror = if ($env:FLUTTER_STORAGE_BASE_URL) { $env:FLUTTER_STORAGE_BASE_URL } else { 'default' }
$version = Resolve-FlutterVersion $flavor
$vfox = if ($env:VFOX_VERSION) { $env:VFOX_VERSION } else { 'latest' }

Write-Output ("=== vfox {0}, flutter {1}, {2}, mirror {3}, {4} ===" -f $vfox, $version, $flavor, $mirror, $env:PROCESSOR_ARCHITECTURE)

. "$PSScriptRoot\setup.ps1"
Invoke-E2EFixture 'preflight'

Invoke-Native { & pwsh -NoProfile -File "$PSScriptRoot\install.ps1" -Version $version } "install.ps1 (flutter $version)"

$PSNativeCommandUseErrorActionPreference = $false
$activation = @(vfox activate pwsh) -join "`r`n"
$activationCode = $LASTEXITCODE
$PSNativeCommandUseErrorActionPreference = $true
if ($activationCode -ne 0) { throw "FAIL vfox activate pwsh exited with code $activationCode" }
# Dot-source via a temp file instead of Invoke-Expression: same effect
# (runs vfox's assignments in this scope), but auditable on disk and
# PSScriptAnalyzer-clean.
$activationFile = Join-Path ([System.IO.Path]::GetTempPath()) "vfox-activate-$([System.Guid]::NewGuid()).ps1"
try {
    $activation | Set-Content -Path $activationFile
    . $activationFile
} finally {
    Remove-Item $activationFile -ErrorAction SilentlyContinue
}

Invoke-E2EFixture 'verify'
