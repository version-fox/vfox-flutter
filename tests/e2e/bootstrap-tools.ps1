$ErrorActionPreference = 'Stop'

$msi = "$env:TEMP\pwsh.msi"
& curl.exe -fsSL -o $msi 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/PowerShell-7.6.6-win-x64.msi'
& msiexec.exe /i $msi /quiet /norestart
if ($LASTEXITCODE -notin 0, 3010) { throw "PowerShell MSI install failed (exit $LASTEXITCODE)" }

$git = "$env:TEMP\git-installer.exe"
& curl.exe -fsSL -o $git 'https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/Git-2.55.0.5-64-bit.exe'
Start-Process $git -Wait -ArgumentList '/VERYSILENT', '/NORESTART', '/SP-', '/SUPPRESSMSGBOXES'
