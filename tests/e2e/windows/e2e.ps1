$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Image = 'vfox-flutter-e2e:windows'

& docker build --pull -f "$PSScriptRoot\Dockerfile" -t $Image $Repo
if ($LASTEXITCODE -ne 0) { throw "FAIL docker build exited with code $LASTEXITCODE" }

$foxes = if ($env:VFOX_VERSION) { @($env:VFOX_VERSION) } else { @('latest', 'main') }
$flavours = if ($env:FLAVOR) { @($env:FLAVOR) } else { @('official', 'ohos') }

$combos = foreach ($vfox in $foxes) {
    foreach ($flavor in $flavours) {
        [pscustomobject]@{ Vfox = $vfox; Flavor = $flavor }
    }
}

$combos | ForEach-Object -Parallel {
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $false
    $vfox = $_.Vfox
    $flavor = $_.Flavor
    $prefix = "vfox $vfox, $flavor"
    Write-Output "[$prefix] === start ==="
    & docker run --rm -e "VFOX_VERSION=$vfox" -e "FLAVOR=$flavor" $using:Image 2>&1 | ForEach-Object { "[$prefix] $_" }
    if ($LASTEXITCODE -ne 0) { throw ("FAIL docker run ({0}) exited with code {1}" -f $prefix, $LASTEXITCODE) }
} -ThrottleLimit 3
