$ErrorActionPreference = 'Stop'

$IsArm64 = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64'
$pwshArch = if ($IsArm64) { 'arm64' } else { 'x64' }
$gitAsset = if ($IsArm64) { 'Git-2.55.0.5-arm64.exe' } else { 'Git-2.55.0.5-64-bit.exe' }

$msi = "$env:TEMP\pwsh.msi"
& curl.exe -fsSL -o $msi "https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/PowerShell-7.6.6-win-$pwshArch.msi"
& msiexec.exe /i $msi /quiet /norestart
if ($LASTEXITCODE -notin 0, 3010) { throw "PowerShell MSI install failed (exit $LASTEXITCODE)" }

$git = "$env:TEMP\git-installer.exe"
& curl.exe -fsSL -o $git "https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/$gitAsset"
Start-Process $git -Wait -ArgumentList '/VERYSILENT', '/NORESTART', '/SP-', '/SUPPRESSMSGBOXES'
