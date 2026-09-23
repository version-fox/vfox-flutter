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

if ($env:PROCESSOR_ARCHITECTURE -ne 'ARM64') { throw "FAIL this script builds a windows/arm64 engine and needs an arm64 host" }

if (Test-Engine) {
    Write-Output 'PASS docker is already installed'
}
else {
    $mobyVersion = '29.8.1'
    $root = 'C:\vfox-docker'
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    Write-Output 'Building docker from source for windows/arm64 ...'

    $goMsi = "$env:TEMP\go.msi"
    & curl.exe -fsSL -o $goMsi 'https://go.dev/dl/go1.27.1.windows-arm64.msi'
    if ($LASTEXITCODE -ne 0) { throw "FAIL the Go download exited with code $LASTEXITCODE" }
    & msiexec.exe /i $goMsi /quiet /norestart
    if ($LASTEXITCODE -notin 0, 3010) { throw "FAIL the Go MSI install exited with code $LASTEXITCODE" }
    Remove-Item $goMsi
    $env:GOPATH = Join-Path $root 'gopath'
    New-Item -ItemType Directory -Force -Path $env:GOPATH | Out-Null
    $env:PATH = "C:\Program Files\Go\bin;$env:GOPATH\bin;$env:PATH"

    $moby = Join-Path $root 'moby'
    git clone --depth 1 --branch "docker-v$mobyVersion" https://github.com/moby/moby.git $moby
    if ($LASTEXITCODE -ne 0) { throw "FAIL the moby clone exited with code $LASTEXITCODE" }
    go install github.com/tc-hib/go-winres@v0.3.1
    if ($LASTEXITCODE -ne 0) { throw "FAIL the go-winres install exited with code $LASTEXITCODE" }
    $env:DOCKERCLI_VERSION = $mobyVersion
    $env:VERSION = $mobyVersion
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
    $dockerdArgs = "--data-root `"$dataRoot`" --debug --exec-opt isolation=process"
    Start-Process -FilePath (Join-Path $bin 'dockerd.exe') -ArgumentList $dockerdArgs -RedirectStandardOutput $log -RedirectStandardError (Join-Path $root 'dockerd.err.log')
    if (-not (Wait-Engine)) {
        if (Test-Path $log) { Get-Content $log -Tail 40 | ForEach-Object { "dockerd: $_" } }
        throw 'FAIL the docker engine never became ready'
    }
}

$info = ((& docker info --format '{{.OSType}}|{{.Architecture}}') -join '').Trim().ToLowerInvariant()
if ($info -ne 'windows|arm64') { throw "FAIL the docker engine runs $info containers" }
Write-Output 'PASS the docker engine runs windows/arm64 containers'
