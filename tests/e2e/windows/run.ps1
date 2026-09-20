$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$vfox = if ($env:VFOX_VERSION) { $env:VFOX_VERSION } else { 'latest' }
$flavor = if ($env:FLAVOR) { $env:FLAVOR } else { throw 'FAIL FLAVOR is not set' }
$version = if ($flavor -eq 'official') {
    if ($env:FLUTTER_VERSION) { $env:FLUTTER_VERSION } else { '3.47.4' }
} elseif ($flavor -eq 'ohos') {
    if ($env:OHOS_VERSION) { $env:OHOS_VERSION } else { '3.41.10-ohos-1.0.0' }
} else {
    throw "FAIL unknown flavor $flavor"
}

Write-Output ("=== vfox {0}, flutter {1}, {2} ===" -f $vfox, $version, $flavor)
. "$PSScriptRoot\setup.ps1"
& pwsh -File "$PSScriptRoot\install.ps1" -Version $version
if ($LASTEXITCODE -ne 0) { throw "FAIL install.ps1 (flutter $version) exited with code $LASTEXITCODE" }
& pwsh -File "$PSScriptRoot\verify.ps1" -Flavor $flavor
if ($LASTEXITCODE -ne 0) { throw "FAIL verify.ps1 ($flavor) exited with code $LASTEXITCODE" }
