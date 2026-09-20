# E2E

The offline Lua hook tests (`tests/hooks_test.lua`) run in the **Test Plugin** workflow.
The end-to-end suite runs in containers against real vfox (`latest` and `main`) on Linux
and Windows; each of the four `vfox` x `flavor` combinations gets its own throwaway
container.

## Ubuntu 26.04

Assume that Git and Docker Engine (in either rootful or rootless mode) are already installed.

Execute in Bash,

```bash
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
bash tests/e2e/linux/e2e.sh
```

## Running on Windows 11 Pro

1. Execute in Windows PowerShell 5.1,

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

2. Execute in PowerShell 7,

```powershell
winget install --id Git.Git --source winget --exact

Invoke-WebRequest -UseBasicParsing `
    "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" `
    -OutFile ./install-docker-ce.ps1
```

3. Execute in PowerShell 7 with administrator privileges,

```powershell
./install-docker-ce.ps1
```

4. Execute in PowerShell 7,

```powershell
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tests\e2e\windows\e2e.ps1
```
