param(
    [Parameter(Mandatory = $true)] [string] $Version
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
. "$PSScriptRoot\lib.ps1"

Invoke-WithRetry { vfox install flutter@$Version } "vfox install flutter@$Version"
Invoke-Native { vfox use --global flutter@$Version } "vfox use --global flutter@$Version"
