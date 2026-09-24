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
