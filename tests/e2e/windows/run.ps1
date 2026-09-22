$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$vfox = if ($env:VFOX_VERSION) { $env:VFOX_VERSION } else { 'latest' }
$flavor = if ($env:FLAVOR) { $env:FLAVOR } else { throw 'FAIL FLAVOR is not set' }
$mirror = if ($env:FLUTTER_STORAGE_BASE_URL) { $env:FLUTTER_STORAGE_BASE_URL } else { 'default' }
$version = if ($flavor -eq 'official') {
    if ($env:FLUTTER_VERSION) { $env:FLUTTER_VERSION } else { '3.47.4' }
} elseif ($flavor -eq 'ohos') {
    if ($env:OHOS_VERSION) { $env:OHOS_VERSION } else { '3.41.10-ohos-1.0.0' }
} else {
    throw "FAIL unknown flavor $flavor"
}

Write-Output ("=== vfox {0}, flutter {1}, {2}, mirror {3} ===" -f $vfox, $version, $flavor, $mirror)
if (($flavor -eq 'official') -and ($mirror -ne 'default')) {
    $mirrorIndex = $mirror.TrimEnd('/') + '/flutter_infra_release/releases/releases_windows.json'
    try {
        & curl.exe -fsSL --max-time 20 -o NUL $mirrorIndex
    } catch {
        throw "FAIL mirror $mirror is unreachable ($mirrorIndex)"
    }
    if ($LASTEXITCODE -ne 0) { throw "FAIL mirror $mirror is unreachable ($mirrorIndex)" }
    Write-Output "PASS mirror $mirror serves the releases index"
}
. "$PSScriptRoot\setup.ps1"
if ($flavor -eq 'official') {
    $bogusMirror = 'https://invalid.example.invalid'
    $origMirror = $env:FLUTTER_STORAGE_BASE_URL
    $env:FLUTTER_STORAGE_BASE_URL = $bogusMirror
    $PSNativeCommandUseErrorActionPreference = $false
    $bogusOutput = (& vfox install "flutter@$version" 2>&1 | Out-String)
    $bogusCode = $LASTEXITCODE
    $PSNativeCommandUseErrorActionPreference = $true
    if ($null -eq $origMirror) { Remove-Item Env:\FLUTTER_STORAGE_BASE_URL } else { $env:FLUTTER_STORAGE_BASE_URL = $origMirror }
    if ($bogusCode -eq 0) { throw 'FAIL bogus mirror install unexpectedly succeeded' }
    if ($bogusOutput -notmatch [regex]::Escape('invalid.example.invalid')) { throw ("FAIL bogus mirror error is missing invalid.example.invalid`n--- actual ---`n{0}" -f $bogusOutput) }
    Write-Output 'PASS bogus mirror error contains invalid.example.invalid'
}
& pwsh -File "$PSScriptRoot\install.ps1" -Version $version
if ($LASTEXITCODE -ne 0) { throw "FAIL install.ps1 (flutter $version) exited with code $LASTEXITCODE" }
& pwsh -File "$PSScriptRoot\verify.ps1" -Flavor $flavor
if ($LASTEXITCODE -ne 0) { throw "FAIL verify.ps1 ($flavor) exited with code $LASTEXITCODE" }
