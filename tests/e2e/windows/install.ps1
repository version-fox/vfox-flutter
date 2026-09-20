param(
    [Parameter(Mandatory = $true)] [string] $Version
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

Invoke-Expression "$(vfox activate pwsh)"
vfox install flutter@$Version
vfox use --global flutter@$Version
Invoke-Expression "$(vfox activate pwsh)"
