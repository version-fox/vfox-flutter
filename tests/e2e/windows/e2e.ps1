$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Image = 'vfox-flutter-e2e:windows'

& docker build --pull -f "$PSScriptRoot\Dockerfile" -t $Image $Repo
if ($LASTEXITCODE -ne 0) { throw "FAIL docker build exited with code $LASTEXITCODE" }

$foxes = if ($env:VFOX_VERSION) { @($env:VFOX_VERSION) } else { @('latest', 'main') }
$flavours = if ($env:FLAVOR) { @($env:FLAVOR) } else { @('official', 'ohos') }

foreach ($vfox in $foxes) {
    foreach ($flavor in $flavours) {
        Write-Output ("=== vfox {0}, {1} ===" -f $vfox, $flavor)
        & docker run --rm -e "VFOX_VERSION=$vfox" -e "FLAVOR=$flavor" $Image
        if ($LASTEXITCODE -ne 0) { throw ("FAIL docker run (vfox {0}, {1}) exited with code {2}" -f $vfox, $flavor, $LASTEXITCODE) }
    }
}
