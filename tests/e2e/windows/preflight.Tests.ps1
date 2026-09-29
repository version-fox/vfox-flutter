# Pre-install guards: mirror reachability and proof that the plugin really
# honours $env:FLUTTER_STORAGE_BASE_URL. Runs via Invoke-Pester after
# setup.ps1 but before install.ps1 (see run.ps1).

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

Describe 'mirror preflight' {
    BeforeAll {
        # NB: $PSScriptRoot must be used directly here. A $here variable set
        # at file top-level is NOT visible inside BeforeAll/It: Pester runs
        # discovery and execution in different sessions.
        . "$PSScriptRoot\lib.ps1"
        $Flavor = if ($env:FLAVOR) { $env:FLAVOR } else { throw 'FAIL FLAVOR is not set' }
        $Mirror = if ($env:FLUTTER_STORAGE_BASE_URL) { $env:FLUTTER_STORAGE_BASE_URL } else { 'default' }
    }

    It 'serves the releases index' {
        if (($Flavor -ne 'official') -or ($Mirror -eq 'default')) {
            Set-ItResult -Skipped -Because 'only official flavours with a configured mirror probe the index'
        }
        $index = $Mirror.TrimEnd('/') + '/flutter_infra_release/releases/releases_windows.json'
        Invoke-WithRetry { & curl.exe -fsSL --max-time 20 -o NUL $index } "mirror $index"
    }

    It 'rejects a bogus mirror naming the host' {
        if ($Flavor -ne 'official') {
            Set-ItResult -Skipped -Because 'only the official flavour honours the download mirror'
        }
        $origMirror = $env:FLUTTER_STORAGE_BASE_URL
        try {
            $env:FLUTTER_STORAGE_BASE_URL = 'https://invalid.example.invalid'
            $PSNativeCommandUseErrorActionPreference = $false
            $bogusOutput = (& vfox install "flutter@$(Resolve-FlutterVersion $Flavor)" 2>&1 | Out-String)
            $bogusCode = $LASTEXITCODE
            $PSNativeCommandUseErrorActionPreference = $true
        } finally {
            if ($null -eq $origMirror) { Remove-Item Env:\FLUTTER_STORAGE_BASE_URL } else { $env:FLUTTER_STORAGE_BASE_URL = $origMirror }
        }
        $bogusCode | Should -Not -Be 0
        $bogusOutput | Should -Match ([regex]::Escape('invalid.example.invalid'))
    }
}
