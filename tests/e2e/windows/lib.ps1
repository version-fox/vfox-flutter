# NOTE: the default versions below duplicate tests/e2e/linux/setup.go
# (PowerShell and Go share no config format). Bump both sides together.
function Resolve-FlutterVersion {
    param(
        [Parameter(Mandatory)] [string] $Flavor
    )
    if ($Flavor -eq 'official') {
        if ($env:FLUTTER_VERSION) { $env:FLUTTER_VERSION } else { '3.47.4' }
    } elseif ($Flavor -eq 'ohos') {
        if ($env:OHOS_VERSION) { $env:OHOS_VERSION } else { '3.41.10-ohos-1.0.0' }
    } else {
        throw "FAIL unknown flavor $Flavor"
    }
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)] [scriptblock] $Cmd,
        [Parameter(Mandatory)] [string] $What,
        [int[]] $Ok = 0
    )
    $prev = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    & $Cmd
    $code = $LASTEXITCODE
    $PSNativeCommandUseErrorActionPreference = $prev
    if ($null -eq $code) { throw "FAIL $What did not run" }
    if ($code -notin $Ok) { throw "FAIL $What exited with code $code" }
}

# Invoke-WithRetry runs a native command streaming its output (so callers
# can still capture it) and retries up to $Attempts times with linear
# backoff. Progress notices go to stderr to stay out of captures.
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)] [scriptblock] $Cmd,
        [Parameter(Mandatory)] [string] $What,
        [int] $Attempts = 3,
        [int] $BackoffSeconds = 10
    )
    $code = 1
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $prev = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
        & $Cmd
        $code = $LASTEXITCODE
        $PSNativeCommandUseErrorActionPreference = $prev
        if ($code -eq 0) { return }
        if ($attempt -lt $Attempts) {
            [Console]::Error.WriteLine("retrying $What, attempt $attempt exited $code")
            Start-Sleep -Seconds ($BackoffSeconds * $attempt)
        }
    }
    throw "FAIL $What failed after $Attempts attempts (exit $code)"
}
