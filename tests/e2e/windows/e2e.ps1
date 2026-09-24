$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
. "$PSScriptRoot\lib.ps1"

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

Invoke-Native { & docker build --pull --platform $platform --build-arg "BASE_IMAGE=$baseImage" -f "$PSScriptRoot\Dockerfile" -t $Image $Repo } 'docker build'

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

$combos = [System.Collections.Generic.List[object]]::new()
foreach ($vfox in $foxes) {
    foreach ($flavor in $flavours) {
        foreach ($mirror in $mirrorList) {
            if ((-not $mirrorExplicit) -and ($mirror -ne 'default') -and ($vfox -ne 'latest')) { continue }
            $combos.Add([pscustomobject]@{ Vfox = $vfox; Flavor = $flavor; Mirror = $mirror })
        }
    }
}

$maxJobs = 2
if ($env:E2E_MAX_JOBS) { $maxJobs = [int]$env:E2E_MAX_JOBS }
if ($maxJobs -lt 1) { $maxJobs = 1 }

function Get-ComboSlug {
    param([object] $Combo)
    return ($Combo.Vfox + '-' + $Combo.Flavor + '-' + ($Combo.Mirror -replace '[^A-Za-z0-9]', '_'))
}

function Get-ContainerExitCode {
    param([string] $Id)
    $code = & docker wait $Id
    $code = if ($null -eq $code) { '' } else { ($code | Select-Object -Last 1).Trim() }
    if ($code -notmatch '^-?\d+$') { throw "FAIL docker wait $Id reported no exit code" }
    return [long]$code
}

$failures = [System.Collections.Generic.List[string]]::new()
for ($start = 0; $start -lt $combos.Count; $start += $maxJobs) {
    $end = [math]::Min($start + $maxJobs - 1, $combos.Count - 1)
    $batch = [System.Collections.Generic.List[object]]::new()

    for ($i = $start; $i -le $end; $i++) {
        $combo = $combos[$i]
        $vfox = $combo.Vfox
        $flavor = $combo.Flavor
        $mirror = $combo.Mirror
        $prefix = "vfox $vfox, $flavor, mirror $mirror, $platform"
        Write-Output "[$prefix] === start ==="

        $slug = Get-ComboSlug $combo
        $runArgs = @(
            'run', '-d', '--platform', $platform,
            '-e', "VFOX_VERSION=$vfox", '-e', "FLAVOR=$flavor",
            '-e', "VFOX_E2E_SLOT=$slug")
        if ($mirror -ne 'default') { $runArgs += @('-e', "FLUTTER_STORAGE_BASE_URL=$mirror") }
        $runArgs += $Image

        $cid = & docker @runArgs
        if ($LASTEXITCODE -ne 0) { throw "FAIL docker run ($prefix) failed to start" }
        $batch.Add([pscustomobject]@{ Prefix = $prefix; Id = $cid })
    }

    foreach ($entry in $batch) {
        $prefix = $entry.Prefix
        $exitCode = Get-ContainerExitCode $entry.Id
        $logs = (& docker logs $entry.Id) -join "`r`n"
        Write-Output $logs
        & docker rm $entry.Id | Out-Null

        if ($exitCode -ne 0) {
            $failures.Add("FAIL docker run ($prefix) exited with code $exitCode")
        }
        elseif ($logs -notmatch '=== vfox') {
            $failures.Add("FAIL docker run ($prefix) produced no test output")
        }
    }
}

if ($failures.Count -gt 0) { throw ($failures -join "`r`n") }
