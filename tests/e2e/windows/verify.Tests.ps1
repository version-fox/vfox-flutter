# Assert on an installed SDK, run via Invoke-Pester after install.ps1
# (see run.ps1). Self-contained: BeforeAll re-derives config and SDK state,
# so the file also runs standalone for debugging a live container.
#
# NOTE: the drift-warning strings asserted here are part of the plugin's
# user-facing contract (see hooks/ / lib/). If the Lua side rewords them,
# update both this file and tests/e2e/linux/verify.bats together.
# (Pester runs tests in file order; the drift test below still keeps its
# commit + reset inside one test so it never leaks state to neighbours.)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

Describe 'installed SDK' {
    BeforeAll {
        # NB: $PSScriptRoot must be used directly here. A $here variable set
        # at file top-level is NOT visible inside BeforeAll/It: Pester runs
        # discovery and execution in different sessions.
        . "$PSScriptRoot\lib.ps1"
        $Flavor = if ($env:FLAVOR) { $env:FLAVOR } else { throw 'FAIL FLAVOR is not set' }
        $Version = Resolve-FlutterVersion $Flavor
        $Sdk = Split-Path (Split-Path ((Get-Command flutter -CommandType Application | Select-Object -First 1).Source))
    }

    It 'carries no vfox commit on the official flavour' {
        if ($Flavor -ne 'official') { Set-ItResult -Skipped -Because 'official-only check' }
        $subject = git -C $Sdk log -1 --format=%s
        $subject | Should -Not -Match 'vfox install'
    }

    It 'is a git checkout with its engine pins tracked on the ohos flavour' {
        if ($Flavor -ne 'ohos') { Set-ItResult -Skipped -Because 'ohos-only check' }
        Test-Path "$Sdk\.git" | Should -BeTrue
        git -C $Sdk ls-files bin/internal/engine.version | Should -Match ([regex]::Escape('bin/internal/engine.version'))
    }

    It 'carries a .vfox-manifest anchored at the installed HEAD' {
        $manifestPath = Join-Path $Sdk '.vfox-manifest'
        Test-Path $manifestPath | Should -BeTrue
        $installedHead = @(git -C $Sdk rev-parse HEAD)[0]
        $anchorMatch = [regex]::Match((Get-Content $manifestPath -Raw), '"expected_head"\s*:\s*"([^"]+)"')
        $anchorMatch.Success | Should -BeTrue
        $anchorMatch.Groups[1].Value | Should -Be $installedHead
    }

    It 'reports no drift when freshly installed' {
        $PSNativeCommandUseErrorActionPreference = $false
        $cleanOutput = (& vfox use --global "flutter@$Version" 2>&1 | Out-String)
        $cleanCode = $LASTEXITCODE
        $PSNativeCommandUseErrorActionPreference = $true
        $cleanCode | Should -Be 0
        $cleanOutput | Should -Not -Match 'has drifted'
    }

    It 'detects an in-place upgrade and goes quiet after restore' {
        $manifestPath = Join-Path $Sdk '.vfox-manifest'
        $anchor = [regex]::Match((Get-Content $manifestPath -Raw), '"expected_head"\s*:\s*"([^"]+)"').Groups[1].Value
        $anchor | Should -Not -BeNullOrEmpty

        $env:GIT_AUTHOR_NAME = 'e2e'
        $env:GIT_AUTHOR_EMAIL = 'e2e@vfox.flutter'
        $env:GIT_COMMITTER_NAME = 'e2e'
        $env:GIT_COMMITTER_EMAIL = 'e2e@vfox.flutter'
        try {
            $PSNativeCommandUseErrorActionPreference = $false
            git -C $Sdk commit --allow-empty -q -m 'simulated flutter upgrade'
            if ($LASTEXITCODE -ne 0) { throw "FAIL failed to record a simulated flutter upgrade commit (git exit $LASTEXITCODE)" }

            $driftedHead = @(git -C $Sdk rev-parse HEAD)[0]
            $driftOutput = (& vfox use --global "flutter@$Version" 2>&1 | Out-String)
            $driftCode = $LASTEXITCODE
            $PSNativeCommandUseErrorActionPreference = $true
            $driftCode | Should -Be 0
            $driftOutput | Should -Match ([regex]::Escape('has drifted from the version vfox installed'))
            $driftOutput | Should -Match ([regex]::Escape($anchor))
            $driftOutput | Should -Match ([regex]::Escape($driftedHead))
            $driftOutput | Should -Match ([regex]::Escape("vfox uninstall flutter@$Version"))
            $driftOutput | Should -Match ([regex]::Escape("vfox install  flutter@$Version"))
            $driftOutput | Should -Match ([regex]::Escape("vfox use      flutter@$Version"))
            $driftOutput | Should -Match ([regex]::Escape('vfox install flutter@<new-version>'))
        } finally {
            $PSNativeCommandUseErrorActionPreference = $true
            git -C $Sdk reset -q --hard $anchor
        }

        $PSNativeCommandUseErrorActionPreference = $false
        $restoredOutput = (& vfox use --global "flutter@$Version" 2>&1 | Out-String)
        $restoredCode = $LASTEXITCODE
        $PSNativeCommandUseErrorActionPreference = $true
        $restoredCode | Should -Be 0
        $restoredOutput | Should -Not -Match 'has drifted'
    }

    It 'bootstraps the toolchain with agreeing dart/flutter versions' {
        Invoke-WithRetry { & curl.exe -fsSL --max-time 20 -o NUL 'https://pub.dev/api/packages/args' } 'pub.dev'
        $dart = (dart --version 2>&1 | Out-String)
        $flutter = (flutter --version --no-version-check 2>&1 | Out-String)
        $flutter | Should -Match ([regex]::Escape((git -C $Sdk rev-parse HEAD).Substring(0, 10)))
        $dartVersion = (($flutter -split "`n" | Where-Object { $_ -like '*Tools*' }) -split ' ')[3]
        $dartVersion | Should -Not -BeNullOrEmpty
        $dart | Should -Match ([regex]::Escape($dartVersion))
    }
}
