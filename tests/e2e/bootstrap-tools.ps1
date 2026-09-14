$ErrorActionPreference = 'Stop'

function Get-LatestAssetUrl {
    param([string]$Repo, [string]$Pattern)
    $json = (& curl.exe -fsSL "https://api.github.com/repos/$Repo/releases/latest") -join "`n"
    ($json | ConvertFrom-Json).assets |
        Where-Object { $_.name -match $Pattern } | Select-Object -First 1 -ExpandProperty browser_download_url
}

$msi = Join-Path ([IO.Path]::GetTempPath()) 'pwsh.msi'
& curl.exe -fsSL -o $msi (Get-LatestAssetUrl -Repo 'PowerShell/PowerShell' -Pattern '^PowerShell-.*-win-x64\.msi$')
& msiexec.exe /i $msi /quiet /norestart
if ($LASTEXITCODE -notin 0, 3010) { throw "PowerShell MSI install failed (exit $LASTEXITCODE)" }

$git = Join-Path ([IO.Path]::GetTempPath()) 'git-installer.exe'
& curl.exe -fsSL -o $git (Get-LatestAssetUrl -Repo 'git-for-windows/git' -Pattern '^Git-.*-64-bit\.exe$')
Start-Process $git -Wait -ArgumentList '/VERYSILENT', '/NORESTART', '/SP-', '/SUPPRESSMSGBOXES'
