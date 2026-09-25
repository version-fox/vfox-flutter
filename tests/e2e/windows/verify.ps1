param(
    [Parameter(Mandatory = $true)] [string] $Flavor,
    [Parameter(Mandatory = $true)] [string] $Version
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

# --- in-place `flutter upgrade` drift detection ---------------------------
$manifestPath = Join-Path $sdk '.vfox-manifest'
if (-not (Test-Path $manifestPath)) { throw 'FAIL the SDK has no .vfox-manifest, so its installed version cannot be anchored' }
Write-Output 'PASS the SDK carries a .vfox-manifest'

$installedHead = @(git -C $sdk rev-parse HEAD)[0]
$anchorMatch = [regex]::Match((Get-Content $manifestPath -Raw), '"expected_head"\s*:\s*"([^"]+)"')
if (-not $anchorMatch.Success) { throw 'FAIL the .vfox-manifest has no expected_head' }
$anchor = $anchorMatch.Groups[1].Value
if ($anchor -ne $installedHead) { throw "FAIL the .vfox-manifest anchor $anchor does not match the installed git HEAD $installedHead" }
Write-Output 'PASS the .vfox-manifest anchor matches the installed git HEAD'

$PSNativeCommandUseErrorActionPreference = $false
$cleanOutput = (& vfox use --global "flutter@$Version" 2>&1) -join "`n"
$cleanCode = $LASTEXITCODE
$PSNativeCommandUseErrorActionPreference = $true
if ($cleanCode -ne 0) { throw "FAIL vfox use exited with code $cleanCode" }
if ($cleanOutput -match [regex]::Escape('has drifted')) { throw "FAIL a freshly installed SDK reports drift`n--- actual ---`n$cleanOutput" }
Write-Output 'PASS a freshly installed SDK reports no drift'

$env:GIT_AUTHOR_NAME = 'e2e'
$env:GIT_AUTHOR_EMAIL = 'e2e@vfox.flutter'
$env:GIT_COMMITTER_NAME = 'e2e'
$env:GIT_COMMITTER_EMAIL = 'e2e@vfox.flutter'
$PSNativeCommandUseErrorActionPreference = $false
git -C $sdk commit --allow-empty -q -m 'simulated flutter upgrade'
$commitCode = $LASTEXITCODE
$PSNativeCommandUseErrorActionPreference = $true
if ($commitCode -ne 0) { throw "FAIL failed to record a simulated flutter upgrade commit (git exit $commitCode)" }

$driftedHead = @(git -C $sdk rev-parse HEAD)[0]
$PSNativeCommandUseErrorActionPreference = $false
$driftOutput = (& vfox use --global "flutter@$Version" 2>&1) -join "`n"
$driftCode = $LASTEXITCODE
$PSNativeCommandUseErrorActionPreference = $true
if ($driftCode -ne 0) { throw "FAIL vfox use exited with code $driftCode" }
Assert-Contains $driftOutput 'has drifted from the version vfox installed' 'drift warning'
Assert-Contains $driftOutput $anchor 'drift warning expected head'
Assert-Contains $driftOutput $driftedHead 'drift warning current head'
Assert-Contains $driftOutput "vfox uninstall flutter@$Version" 'drift warning restore command'
Assert-Contains $driftOutput "vfox install  flutter@$Version" 'drift warning restore command'
Assert-Contains $driftOutput "vfox use      flutter@$Version" 'drift warning restore command'
Assert-Contains $driftOutput 'vfox install flutter@<new-version>' 'drift warning upgrade command'

git -C $sdk reset -q --hard $anchor
$PSNativeCommandUseErrorActionPreference = $false
$restoredOutput = (& vfox use --global "flutter@$Version" 2>&1) -join "`n"
$restoredCode = $LASTEXITCODE
$PSNativeCommandUseErrorActionPreference = $true
if ($restoredCode -ne 0) { throw "FAIL vfox use exited with code $restoredCode" }
if ($restoredOutput -match [regex]::Escape('has drifted')) { throw "FAIL a restored SDK still reports drift`n--- actual ---`n$restoredOutput" }
Write-Output 'PASS a restored SDK reports no drift'

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
