param(
    [Parameter(Mandatory = $true)] [string] $Version
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

Invoke-Expression "$(vfox activate pwsh)"
if ($LASTEXITCODE -ne 0) { throw "FAIL vfox activate pwsh exited with code $LASTEXITCODE" }
vfox install flutter@$Version
if ($LASTEXITCODE -ne 0) { throw "FAIL vfox install flutter@$Version exited with code $LASTEXITCODE" }
vfox use --global flutter@$Version
if ($LASTEXITCODE -ne 0) { throw "FAIL vfox use --global flutter@$Version exited with code $LASTEXITCODE" }
Invoke-Expression "$(vfox activate pwsh)"
if ($LASTEXITCODE -ne 0) { throw "FAIL vfox activate pwsh exited with code $LASTEXITCODE" }
