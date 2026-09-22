$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Test-Engine {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return $false }
    $PSNativeCommandUseErrorActionPreference = $false
    & docker version 2>&1 | Out-Null
    $code = $LASTEXITCODE
    $PSNativeCommandUseErrorActionPreference = $true
    return $code -eq 0
}

function Wait-Engine {
    for ($attempt = 1; $attempt -le 60; $attempt++) {
        if (Test-Engine) { return $true }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Probe-Containers {
    $operatingSystem = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $hypervisor = $computerSystem.HypervisorPresent
    Write-Output "host os build : $($operatingSystem.Version)"
    Write-Output "hypervisor present : $(if ($null -eq $hypervisor) { 'not reported' } else { $hypervisor })"
    $features = @{}
    foreach ($feature in (Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue)) {
        $features[$feature.FeatureName] = $feature.State
    }
    if ($features.Count -eq 0) { Write-Output 'feature enumeration failed' }
    foreach ($name in @('Containers', 'Containers-Optional', 'Microsoft-Hyper-V-Client', 'Microsoft-Hyper-V-All', 'VirtualMachinePlatform', 'WindowsHypervisorPlatform')) {
        $state = if ($features.ContainsKey($name)) { $features[$name] } else { 'not found' }
        Write-Output "feature $name : $state"
    }
    foreach ($name in @('Containers', 'Containers-Optional')) {
        if ($features.ContainsKey($name) -and $features[$name] -eq 'Disabled') {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart -ErrorAction SilentlyContinue
            Write-Output "enabled $name : success=$($result.Success) restartNeeded=$($result.RestartNeeded)"
        }
    }
}

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }

if (Test-Engine) {
    Write-Output 'PASS docker is already installed'
}
else {
    Probe-Containers
    $goVersion = '1.27.1'
    $root = 'C:\vfox-docker'
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    Write-Output "Building docker from source for windows/$arch ..."

    $env:GOPATH = Join-Path $root 'gopath'
    New-Item -ItemType Directory -Force -Path $env:GOPATH | Out-Null
    $goZip = Join-Path $root "go$goVersion.windows-$arch.zip"
    & curl.exe -fsSL -o $goZip "https://go.dev/dl/go$goVersion.windows-$arch.zip"
    if ($LASTEXITCODE -ne 0) { throw "FAIL the Go download exited with code $LASTEXITCODE" }
    Expand-Archive -Path $goZip -DestinationPath $root
    $env:PATH = "$root\go\bin;$env:GOPATH\bin;$env:PATH"

    $moby = Join-Path $root 'moby'
    git clone --depth 1 https://github.com/moby/moby.git $moby
    if ($LASTEXITCODE -ne 0) { throw "FAIL the moby clone exited with code $LASTEXITCODE" }
    go install github.com/tc-hib/go-winres@latest
    if ($LASTEXITCODE -ne 0) { throw "FAIL the go-winres install exited with code $LASTEXITCODE" }
    $env:DOCKERCLI_VERSION = '29.8.1'
    Push-Location $moby
    try {
        & .\hack\make.ps1 -Client -Daemon
    }
    finally {
        Pop-Location
    }

    $bin = Join-Path $moby 'bundles'
    if (-not (Test-Path (Join-Path $bin 'dockerd.exe'))) { throw 'FAIL the moby build produced no dockerd.exe' }
    if (-not (Test-Path (Join-Path $bin 'docker.exe'))) { throw 'FAIL the moby build produced no docker.exe' }
    $env:PATH = "$bin;$env:PATH"
    if ($env:GITHUB_PATH) { Add-Content -Path $env:GITHUB_PATH -Value $bin }

    $dataRoot = Join-Path $root 'data'
    $log = Join-Path $root 'dockerd.log'
    # Windows client SKUs (e.g. windows-11-arm) default to Hyper-V isolation,
    # which needs a hypervisor feature this runner does not have. Process
    # isolation only needs the "Containers" feature, which is enabled.
    $dockerdArgs = "--data-root `"$dataRoot`" --debug --exec-opt isolation=process"
    Start-Process -FilePath (Join-Path $bin 'dockerd.exe') -ArgumentList $dockerdArgs -RedirectStandardOutput $log -RedirectStandardError (Join-Path $root 'dockerd.err.log')
    if ($env:GITHUB_ENV) { Add-Content -Path $env:GITHUB_ENV -Value "DOCKER_LOG=$log" }
    if (-not (Wait-Engine)) {
        if (Test-Path $log) { Get-Content $log -Tail 40 | ForEach-Object { "dockerd: $_" } }
        throw 'FAIL the docker engine never became ready'
    }
}

$info = ((& docker info --format '{{.OSType}}|{{.Architecture}}') -join '').Trim().ToLowerInvariant()
$os, $rawArch = $info -split '\|'
$engineArch = if ($rawArch -eq 'x86_64') { 'amd64' } else { $rawArch }
if ($os -ne 'windows' -or $engineArch -ne $arch) { throw "FAIL the docker engine runs ${os}/${rawArch} containers, expected windows/$arch" }
Write-Output "PASS the docker engine runs windows/$arch containers"
