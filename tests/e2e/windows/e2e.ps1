$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$Repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path

$hostArch = $env:PROCESSOR_ARCHITECTURE
if ($env:ARCH) { $hostArch = $env:ARCH }
$arch = $hostArch.ToLowerInvariant()
if ($arch -eq 'aarch64') { $arch = 'arm64' }
if ($arch -eq 'x86_64' -or $arch -eq 'x64') { $arch = 'amd64' }
if (($arch -ne 'amd64') -and ($arch -ne 'arm64')) { throw "FAIL unknown architecture $hostArch" }
$platform = "windows/$arch"
$Image = "vfox-flutter-e2e:windows-$arch"
$baseImage = "mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-$arch"

& docker build --pull --platform $platform --build-arg "BASE_IMAGE=$baseImage" -f "$PSScriptRoot\Dockerfile" -t $Image $Repo
if ($LASTEXITCODE -ne 0) { throw "FAIL docker build exited with code $LASTEXITCODE" }

$foxes = if ($env:VFOX_VERSION) { @($env:VFOX_VERSION) } else { @('latest', 'main') }
$defaultFlavours = @('official', 'ohos')
$defaultMirrors = @('default', 'https://storage.flutter-io.cn')
if ($arch -eq 'arm64') {
    $defaultFlavours = @('official')
    $defaultMirrors = @('default')
}
$flavours = if ($env:FLAVOR) { @($env:FLAVOR) } else { $defaultFlavours }
$mirrorList = if ($env:MIRROR) { @($env:MIRROR -split '\s+' | Where-Object { $_ -ne '' }) } else { $defaultMirrors }
$mirrorExplicit = -not [string]::IsNullOrWhiteSpace($env:MIRROR)

$combos = foreach ($vfox in $foxes) {
    foreach ($flavor in $flavours) {
        foreach ($mirror in $mirrorList) {
            if ((-not $mirrorExplicit) -and ($mirror -ne 'default') -and ($vfox -ne 'latest')) { continue }
            [pscustomobject]@{ Vfox = $vfox; Flavor = $flavor; Mirror = $mirror }
        }
    }
}

foreach ($combo in $combos) {
    $vfox = $combo.Vfox
    $flavor = $combo.Flavor
    $mirror = $combo.Mirror
    $prefix = "vfox $vfox, $flavor, mirror $mirror, $platform"
    Write-Output "[$prefix] === start ==="
    $runArgs = @('run', '-d', '--platform', $platform, '-e', "VFOX_VERSION=$vfox", '-e', "FLAVOR=$flavor")
    if ($mirror -ne 'default') { $runArgs += @('-e', "FLUTTER_STORAGE_BASE_URL=$mirror") }
    $runArgs += $Image
    $cid = & docker @runArgs
    if ($LASTEXITCODE -ne 0) { throw ("FAIL docker run ({0}) failed to start" -f $prefix) }
    $exitCode = & docker wait $cid
    $logs = (& docker logs $cid) -join "`r`n"
    Write-Output $logs
    & docker rm $cid
    if ([int]$exitCode -ne 0) { throw ("FAIL docker run ({0}) exited with code {1}" -f $prefix, $exitCode) }
    if ($logs -notmatch '=== vfox') { throw "FAIL docker run ($prefix) produced no test output" }
}
