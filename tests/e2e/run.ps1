$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$VfoxVersion = if ($env:VFOX_VERSION) { $env:VFOX_VERSION } else { 'latest' }
$FlutterVersion = '3.44.0'
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw "x86_64 only, got $env:PROCESSOR_ARCHITECTURE" }

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) 'vfox-flutter-e2e'
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$VfoxExe = Join-Path $WorkDir 'vfox.exe'
$PluginZip = Join-Path $WorkDir 'flutter.zip'
$env:PATH = "$WorkDir;$env:PATH"

function Get-LatestAssetUrl {
    param([string]$Repo, [string]$Pattern)
    $json = (& curl.exe -fsSL "https://api.github.com/repos/$Repo/releases/latest") -join "`n"
    ($json | ConvertFrom-Json).assets |
        Where-Object { $_.name -match $Pattern } | Select-Object -First 1 -ExpandProperty browser_download_url
}

function Install-VfoxRelease {
    $zip = Join-Path $WorkDir 'vfox.zip'
    & curl.exe -fsSL -o $zip (Get-LatestAssetUrl -Repo 'version-fox/vfox' -Pattern '^vfox_.*_windows_x86_64\.zip$')
    Expand-Archive $zip -DestinationPath $WorkDir -Force
    Remove-Item $zip
    Copy-Item -Path (Get-ChildItem -Path $WorkDir -Recurse -Filter 'vfox.exe') -Destination $VfoxExe
}

function Ensure-Go {
    if (Get-Command go -ErrorAction SilentlyContinue) { return }
    $ver = & curl.exe -fsSL 'https://go.dev/VERSION?m=text' | Select-Object -First 1
    $msi = Join-Path ([IO.Path]::GetTempPath()) 'go.msi'
    & curl.exe -fsSL -o $msi "https://go.dev/dl/${ver}.windows-amd64.msi"
    Start-Process msiexec.exe -Wait -ArgumentList '/i', "`"$msi`"", '/quiet', '/norestart'
    Remove-Item $msi
    $goBin = @('C:\Go\bin', 'C:\Program Files\Go\bin') |
        Where-Object { Test-Path (Join-Path $_ 'go.exe') } | Select-Object -First 1
    if (-not $goBin) { throw 'go.exe not found after Go MSI install' }
    $env:PATH = "$goBin;$env:PATH"
}

function Install-VfoxMain {
    Ensure-Go
    $src = Join-Path $WorkDir 'vfox-src'
    git clone --depth 1 https://github.com/version-fox/vfox $src
    Push-Location $src
    try { go build -trimpath -o $VfoxExe . } finally { Pop-Location }
}

if ($VfoxVersion -eq 'main') {
    Install-VfoxMain
} else {
    Install-VfoxRelease
}

Compress-Archive -Path (Join-Path $RepoRoot 'metadata.lua'),
    (Join-Path $RepoRoot 'hooks'),
    (Join-Path $RepoRoot 'lib') `
    -DestinationPath $PluginZip -Force

Invoke-Expression ((vfox activate pwsh) -join "`n")
vfox add flutter --source $PluginZip
vfox install "flutter@$FlutterVersion"
vfox use --global "flutter@$FlutterVersion"

$check = Join-Path $WorkDir 'check.ps1'
@'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Invoke-Expression ((vfox activate pwsh) -join "`n")
dart --version
flutter --version --no-version-check
'@ | Set-Content -Path $check -Encoding UTF8
pwsh -NoProfile -File $check
