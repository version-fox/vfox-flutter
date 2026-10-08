$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Entry point for the Windows container E2E suite on local hosts
# (see docs/e2e.md). Derives ARCH from the host so callers never set it by
# hand: the test matrix already falls back to the runner arch, and this only
# feeds the compose BASE_IMAGE build arg. An explicitly set $env:ARCH still
# wins (CI sets it per runner).
if ($env:ARCH -and $env:ARCH.Trim()) {
    $arch = $env:ARCH.Trim().ToLowerInvariant()
} elseif ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
    $arch = 'arm64'
} else {
    $arch = 'amd64'
}
$env:ARCH = $arch

$compose = Join-Path $PSScriptRoot 'compose.yaml'
& docker compose -f $compose run --rm --build e2e
if ($LASTEXITCODE -ne 0) { throw "FAIL the e2e run exited with code $LASTEXITCODE" }
Write-Output "PASS the windows/$arch e2e run finished"
