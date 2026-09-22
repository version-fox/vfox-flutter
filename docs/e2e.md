# E2E

The offline Lua hook tests (`tests/hooks_test.lua`) run in the **Test Plugin** workflow.
The end-to-end suite runs in containers against real vfox on Linux and Windows; 
each `vfox` x `flavor` x `mirror` combination gets its own throwaway container.

## Ubuntu 26.04.1

Assume that Docker Engine (in either rootful or rootless mode) is already installed.

Execute in Bash,

```bash
sudo apt install --assume-yes git
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
bash tests/e2e/linux/e2e.sh
```

On ARM64 it runs the official flavor only: OpenHarmony publishes no `linux-arm64` Dart SDK (see `docs/ohos.md`), so the
ohos flavor cannot bootstrap there.

### Run the ARM64 E2E on a x64 host

To run the ARM64 E2E on an x64 host instead (emulated, much slower),
register QEMU binfmt support with one command (re-run after each reboot) and
override the architecture:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
ARCH=arm64 bash tests/e2e/linux/e2e.sh
```

## Windows 11 Pro

Windows containers cannot be emulated across architectures, so the ARM64 suite
needs an ARM64 host (a Copilot+ PC or the `windows-11-arm` CI runner).

### x64

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
pwsh -NoProfile -File .\tests\e2e\windows\e2e.ps1
```

### arm64

1. Execute in Windows PowerShell 5.1,

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

2. Execute in PowerShell 7,

```powershell
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
pwsh -NoProfile -File .\tests\e2e\windows\install-docker.ps1
pwsh -NoProfile -File .\tests\e2e\windows\e2e.ps1
```
