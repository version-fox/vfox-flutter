$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Image = 'vfox-flutter-e2e:windows'

& docker build --pull -f "$PSScriptRoot\Dockerfile" -t $Image $Repo

$foxes = if ($env:VFOX_VERSION) { @($env:VFOX_VERSION) } else { @('latest', 'main') }
$flavours = if ($env:FLAVOR) { @($env:FLAVOR) } else { @('official', 'ohos') }

foreach ($vfox in $foxes) {
    foreach ($flavor in $flavours) {
        Write-Output ("=== vfox {0}, {1} ===" -f $vfox, $flavor)
        & docker run --rm -e "VFOX_VERSION=$vfox" -e "FLAVOR=$flavor" $Image
    }
}
