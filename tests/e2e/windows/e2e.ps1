$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Image = 'vfox-flutter-e2e:windows'

& docker build --pull -f "$PSScriptRoot\Dockerfile" -t $Image $Repo
if ($LASTEXITCODE -ne 0) { throw "FAIL docker build exited with code $LASTEXITCODE" }

$foxes = if ($env:VFOX_VERSION) { @($env:VFOX_VERSION) } else { @('latest', 'main') }
$flavours = if ($env:FLAVOR) { @($env:FLAVOR) } else { @('official', 'ohos') }
$mirrorList = if ($env:MIRROR) { @($env:MIRROR -split '\s+' | Where-Object { $_ -ne '' }) } else { @('default', 'https://storage.flutter-io.cn') }
$mirrorExplicit = -not [string]::IsNullOrWhiteSpace($env:MIRROR)

$combos = foreach ($vfox in $foxes) {
    foreach ($flavor in $flavours) {
        foreach ($mirror in $mirrorList) {
            if ((-not $mirrorExplicit) -and ($mirror -ne 'default') -and ($vfox -ne 'latest')) { continue }
            [pscustomobject]@{ Vfox = $vfox; Flavor = $flavor; Mirror = $mirror }
        }
    }
}

$combos | ForEach-Object -Parallel {
    $ErrorActionPreference = 'Stop'
    $PSNativeCommandUseErrorActionPreference = $false
    $vfox = $_.Vfox
    $flavor = $_.Flavor
    $mirror = $_.Mirror
    $prefix = "vfox $vfox, $flavor, mirror $mirror"
    Write-Output "[$prefix] === start ==="
    $dockerArgs = @('run', '--rm', '-e', "VFOX_VERSION=$vfox", '-e', "FLAVOR=$flavor")
    if ($mirror -ne 'default') { $dockerArgs += @('-e', "FLUTTER_STORAGE_BASE_URL=$mirror") }
    $dockerArgs += $using:Image
    & docker @dockerArgs 2>&1 | ForEach-Object { "[$prefix] $_" }
    if ($LASTEXITCODE -ne 0) { throw ("FAIL docker run ({0}) exited with code {1}" -f $prefix, $LASTEXITCODE) }
} -ThrottleLimit 3
