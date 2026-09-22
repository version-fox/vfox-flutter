param(
    [Parameter(Mandatory = $true)] [string] $Version
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

for ($attempt = 1; $attempt -le 5; $attempt++) {
    $PSNativeCommandUseErrorActionPreference = $false
    vfox install flutter@$Version
    $code = $LASTEXITCODE
    $PSNativeCommandUseErrorActionPreference = $true
    if ($code -eq 0) { break }
    if ($attempt -eq 5) { throw "FAIL vfox install flutter@$Version exited with code $code" }
    Start-Sleep -Seconds 10
}

vfox use --global flutter@$Version
if ($LASTEXITCODE -ne 0) { throw "FAIL vfox use --global flutter@$Version exited with code $LASTEXITCODE" }
