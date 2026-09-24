$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
. "$PSScriptRoot\lib.ps1"

$VfoxVersion = if ($env:VFOX_VERSION) { $env:VFOX_VERSION } else { 'latest' }

$slot = if ($env:VFOX_E2E_SLOT) { $env:VFOX_E2E_SLOT } else { 'default' }
$slotRoot = Join-Path $env:USERPROFILE "vfox-e2e-runs\$slot"
New-Item -ItemType Directory -Force -Path (Join-Path $slotRoot 'tmp') | Out-Null
$env:USERPROFILE = $slotRoot
$env:VFOX_HOME = Join-Path $slotRoot '.vfox'
$env:TEMP = Join-Path $slotRoot 'tmp'
$env:TMP = $env:TEMP

$RepoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$WorkDir = "$env:TEMP\vfox-flutter-e2e"
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$VfoxExe = "$WorkDir\vfox.exe"
$PluginZip = "$WorkDir\flutter.zip"
$env:PATH = "$WorkDir;$env:PATH"

$CurlRetry = @('--retry', '3', '--retry-delay', '5', '--retry-all-errors')

function Install-VfoxRelease {
    $PSNativeCommandUseErrorActionPreference = $false
    $tag = ((& curl.exe @CurlRetry -fsSLI -o NUL -w '%{url_effective}' 'https://github.com/version-fox/vfox/releases/latest') -split '/tag/')[-1].Trim()
    $PSNativeCommandUseErrorActionPreference = $true
    $vfoxArch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64' } else { 'x86_64' }
    $zip = "$WorkDir\vfox.zip"
    Invoke-Native { & curl.exe @CurlRetry -fsSL -o $zip "https://github.com/version-fox/vfox/releases/download/$tag/vfox_$($tag.TrimStart('v'))_windows_$vfoxArch.zip" } 'the vfox release download'
    Invoke-Native { tar -xf $zip -C $WorkDir } 'extracting the vfox release'
    Remove-Item $zip
    Copy-Item -Path (Get-ChildItem -Path $WorkDir -Recurse -Filter 'vfox.exe') -Destination $VfoxExe
}

function Install-VfoxMain {
    $goArch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $goMsi = "$env:TEMP\go.msi"
    Invoke-Native { & curl.exe @CurlRetry -fsSL -o $goMsi "https://go.dev/dl/go1.27.1.windows-$goArch.msi" } 'the Go download'
    $goInstall = $null
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        $goInstall = Start-Process msiexec.exe -Wait -PassThru -ArgumentList '/i', "`"$goMsi`"", '/quiet', '/norestart'
        if ($goInstall.ExitCode -in 0, 3010, 1937) { break }
        Start-Sleep -Seconds 15
    }
    if ($goInstall.ExitCode -notin 0, 3010, 1937) { throw "FAIL the Go MSI install exited with code $($goInstall.ExitCode)" }
    Remove-Item $goMsi
    $src = "$WorkDir\vfox-src"
    Invoke-Native { git clone --depth 1 https://github.com/version-fox/vfox $src } 'cloning vfox from main'
    $buildScript = @"
go build -C "$src" -trimpath -o "$VfoxExe" .
"@
    $build = Start-Process pwsh -Wait -PassThru -UseNewEnvironment -ArgumentList '-Command', $buildScript
    if ($build.ExitCode -ne 0) { throw "FAIL vfox build from main exited with code $($build.ExitCode)" }
}

if ($VfoxVersion -eq 'main') { Install-VfoxMain } else { Install-VfoxRelease }

Invoke-Native { tar -a -cf $PluginZip -C $RepoRoot metadata.lua hooks lib } 'tar packaging'
Invoke-Native { vfox add flutter --source $PluginZip } 'vfox add flutter --source'
