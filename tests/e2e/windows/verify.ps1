param(
    [Parameter(Mandatory = $true)] [string] $Flavor
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)] [string] $Actual,
        [Parameter(Mandatory = $true)] [string] $Expected,
        [Parameter(Mandatory = $true)] [string] $Label
    )
    if ($Expected -eq '') { throw "FAIL $Label : the expected value is empty" }
    if ($Actual -match [regex]::Escape($Expected)) {
        Write-Output ("PASS {0} contains {1}" -f $Label, $Expected)
        return
    }
    throw ("FAIL {0} is missing {1}`n--- actual ---`n{2}" -f $Label, $Expected, $Actual)
}

$sdk = Split-Path (Split-Path ((Get-Command flutter -CommandType Application | Select-Object -First 1).Source))
if ($Flavor -eq 'official') {
    $subject = git -C $sdk log -1 --format=%s
    if ($subject -like '*vfox install*') { throw 'FAIL the official SDK carries a vfox commit' }
    Write-Output 'PASS the official SDK carries no vfox commit'
} else {
    if (-not (Test-Path "$sdk\.git")) { throw 'FAIL the OpenHarmony SDK is not a git checkout' }
    if (-not (git -C $sdk ls-files bin/internal/engine.version)) { throw 'FAIL the OpenHarmony engine version pin is not tracked' }
    Write-Output 'PASS the OpenHarmony SDK is a git checkout with its engine pins tracked'
}
try {
    & curl.exe -fsSL --max-time 20 -o NUL 'https://pub.dev/api/packages/args'
} catch {
    throw 'FAIL pub.dev is unreachable, the Flutter tool cannot bootstrap'
}
$dart = (dart --version) -join "`n"
$flutter = (flutter --version --no-version-check) -join "`n"
Assert-Contains $flutter ((git -C $sdk rev-parse HEAD).Substring(0, 10)) 'flutter --version revision'
$dartVersion = (($flutter -split "`n" | Where-Object { $_ -like '*Tools*' }) -split ' ')[3]
Assert-Contains $dart $dartVersion 'dart --version'
