<#
 Copyright 2026 Han Li and contributors

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
#>

$ErrorActionPreference = 'Stop'

# Local copy of the native-command guard (the e2e/lib.ps1 helper is gone;
# the suite is driven from Go now). Fails unless the command exits 0.
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

$IsArm64 = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64'
$pwshArch = if ($IsArm64) { 'arm64' } else { 'x64' }
$gitArch = if ($IsArm64) { 'arm64' } else { '64-bit' }

# Portable zips unpacked with the native tar.exe instead of the installers:
# Git for Windows' installer is an x86 program, which arm64 containers only
# run under emulation, at a cost of minutes. MinGit is the same git.exe
# without the extras (bash, Perl, the credential manager) that neither vfox
# nor Flutter calls. It cannot live in C:\Program Files\Git: its
# etc\gitconfig includes the system config of a Git for Windows installed
# there, which would then include itself.
$pwshHome = 'C:\Program Files\PowerShell\7'
$gitHome = 'C:\Program Files\MinGit'
$pwshZip = "$env:TEMP\pwsh.zip"
$pwshUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/PowerShell-7.6.6-win-$pwshArch.zip"
$gitZip = "$env:TEMP\mingit.zip"
$gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/MinGit-2.55.0.5-$gitArch.zip"

Invoke-Native { & curl.exe -fsSL --retry 3 --retry-delay 5 --retry-all-errors -o $pwshZip $pwshUrl } 'the PowerShell download'
Invoke-Native { & curl.exe -fsSL --retry 3 --retry-delay 5 --retry-all-errors -o $gitZip $gitUrl } 'the MinGit download'
New-Item -ItemType Directory -Force -Path $pwshHome, $gitHome | Out-Null
Invoke-Native { & tar.exe -xf $pwshZip -C $pwshHome } 'the PowerShell unpack'
Invoke-Native { & tar.exe -xf $gitZip -C $gitHome } 'the MinGit unpack'
Remove-Item $pwshZip, $gitZip
if (-not (Test-Path "$pwshHome\pwsh.exe")) { throw 'FAIL pwsh.exe is missing after the PowerShell unpack' }
if (-not (Test-Path "$gitHome\cmd\git.exe")) { throw 'FAIL git.exe is missing after the MinGit unpack' }

# What the installers did besides unpacking: put both on the machine PATH,
# and give git the installer defaults MinGit's etc\gitconfig lacks (it
# already sets core.autocrlf and core.symlinks).
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
[Environment]::SetEnvironmentVariable('Path', "$machinePath;$pwshHome;$gitHome\cmd", 'Machine')
Invoke-Native { & "$gitHome\cmd\git.exe" config --system core.fscache true } 'enable the git file system cache'
Invoke-Native { & "$gitHome\cmd\git.exe" config --system core.longpaths true } 'enable system-wide git long paths'
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -PropertyType DWORD -Force | Out-Null
