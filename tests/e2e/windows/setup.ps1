$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$VfoxVersion = if ($env:VFOX_VERSION) { $env:VFOX_VERSION } else { 'latest' }

$RepoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
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
    $src = "$WorkDir\vfox-src"
    git clone --depth 1 https://github.com/version-fox/vfox $src
    $buildScript = @"
go build -C "$src" -trimpath -o "$VfoxExe" .
"@
    $build = Start-Process pwsh -Wait -PassThru -UseNewEnvironment -ArgumentList '-NoLogo', '-Command', $buildScript
    if ($build.ExitCode -ne 0) { exit $build.ExitCode }
}

if ($VfoxVersion -eq 'main') { Install-VfoxMain } else { Install-VfoxRelease }

tar -a -cf $PluginZip -C $RepoRoot metadata.lua hooks lib
vfox add flutter --source $PluginZip
