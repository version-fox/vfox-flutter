# E2E

Offline Lua hook tests (`tests/hooks_test.lua`) run via the **Test Plugin** workflow. A
containerized end-to-end suite exercises the plugin against real vfox (`latest` +
`main`) on Linux and Windows.

## Running on Ubuntu 26.04

Assume that the rootful Docker Engine is already installed.

Execute in Bash,

```bash
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
docker build -f tests/e2e/Dockerfile -t vfox-flutter-e2e:linux .
docker run --rm -e VFOX_VERSION=main vfox-flutter-e2e:linux
```

## Running on Windows 11 Pro

Assume Git for Windows and PowerShell 7 are already installed.

1. Execute in PowerShell 7,

```powershell
Invoke-WebRequest -UseBasicParsing `
    "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" `
    -OutFile ./install-docker-ce.ps1
```

2. Execute in PowerShell 7 with administrator privileges,

```powershell
./install-docker-ce.ps1
```

3. Execute in PowerShell 7,

```powershell
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
docker build -f tests/e2e/Dockerfile.windows -t vfox-flutter-e2e:windows .
docker run --rm -e VFOX_VERSION=main vfox-flutter-e2e:windows
```
