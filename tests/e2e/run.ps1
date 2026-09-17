$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$VfoxVersion = if ($env:VFOX_VERSION) { $env:VFOX_VERSION } else { 'latest' }

$RepoRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$WorkDir = "$env:TEMP\vfox-flutter-e2e"
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$VfoxExe = "$WorkDir\vfox.exe"
$PluginZip = "$WorkDir\flutter.zip"
$env:PATH = "$WorkDir;$env:PATH"

function Install-VfoxRelease {
    $tag = ((& curl.exe -fsSLI -o NUL -w '%{url_effective}' 'https://github.com/version-fox/vfox/releases/latest') -split '/tag/')[-1].Trim()
    $zip = "$WorkDir\vfox.zip"
    & curl.exe -fsSL -o $zip "https://github.com/version-fox/vfox/releases/download/$tag/vfox_$($tag.TrimStart('v'))_windows_x86_64.zip"
    tar -xf $zip -C $WorkDir
    Remove-Item $zip
    Copy-Item -Path (Get-ChildItem -Path $WorkDir -Recurse -Filter 'vfox.exe') -Destination $VfoxExe
}

function Install-VfoxMain {
    $goMsi = "$env:TEMP\go.msi"
    & curl.exe -fsSL -o $goMsi 'https://go.dev/dl/go1.27.1.windows-amd64.msi'
    Start-Process msiexec.exe -Wait -ArgumentList '/i', "`"$goMsi`"", '/quiet', '/norestart'
    Remove-Item $goMsi
    $env:PATH = "$WorkDir;" + [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $src = "$WorkDir\vfox-src"
    git clone --depth 1 https://github.com/version-fox/vfox $src
    Push-Location $src
    try { go build -trimpath -o $VfoxExe . } finally { Pop-Location }
}

if ($VfoxVersion -eq 'main') { Install-VfoxMain } else { Install-VfoxRelease }

tar -a -cf $PluginZip -C $RepoRoot metadata.lua hooks lib

$Pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
Add-Content -Path $PROFILE -Value 'Invoke-Expression "$(vfox activate pwsh)"'

$setup = @'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
vfox add flutter --source '{0}'
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
. $PROFILE
dart --version
flutter --version --no-version-check
'@
& $Pwsh -NoLogo -Command ($setup -f $PluginZip)
