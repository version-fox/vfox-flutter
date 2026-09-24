param(
    [Parameter(Mandatory = $true)] [string] $Version
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
. "$PSScriptRoot\lib.ps1"

$installCode = 1
for ($attempt = 1; $attempt -le 3; $attempt++) {
    $PSNativeCommandUseErrorActionPreference = $false
    vfox install flutter@$Version
    $installCode = $LASTEXITCODE
    $PSNativeCommandUseErrorActionPreference = $true
    if ($installCode -eq 0) { break }
    if ($attempt -lt 3) {
        Write-Output "retrying vfox install flutter@$Version, attempt $attempt exited $installCode"
        Start-Sleep -Seconds (10 * $attempt)
    }
}
if ($installCode -ne 0) { throw "FAIL vfox install flutter@$Version exited with code $installCode" }
Invoke-Native { vfox use --global flutter@$Version } "vfox use --global flutter@$Version"
