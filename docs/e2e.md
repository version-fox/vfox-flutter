# E2E

The offline Lua hook tests (`tests/hooks_test.lua`) run in the **Test Plugin** workflow.
The end-to-end suite runs in containers against real vfox on Linux and Windows;
each `vfox` x `flavor` x `mirror` combination gets its own throwaway container.

## Ubuntu 26.04.1

Only Docker Engine (in either rootful or rootless mode) is required on the
host. Execute in Bash,

```bash
sudo apt install --assume-yes git
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
docker compose -f tests/e2e/linux/compose.yaml run --rm e2e
```

With rootless Docker the daemon socket lives elsewhere; point `DOCKER_SOCK`
at it instead:

```bash
DOCKER_SOCK="$XDG_RUNTIME_DIR/docker.sock" \
    docker compose -f tests/e2e/linux/compose.yaml run --rm e2e
```

To check the `vfox` x `flavor` x `mirror` matrix expansion without
starting containers, override the service command:

```bash
docker compose -f tests/e2e/linux/compose.yaml run --rm e2e go test -short ./...
```

On ARM64 it runs the official flavor only: OpenHarmony publishes no `linux-arm64` Dart SDK (see `docs/ohos.md`), so the
ohos flavor cannot bootstrap there.

### Run the ARM64 E2E on a x64 host

To run the ARM64 E2E on an x64 host instead (emulated, much slower),
register QEMU binfmt support with one command (re-run after each reboot) and
override the architecture:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
cd ./vfox-flutter/
ARCH=arm64 docker compose -f tests/e2e/linux/compose.yaml run --rm e2e
```

## Windows 11 Pro

Windows containers cannot be emulated across architectures, so the ARM64 suite
needs an ARM64 host (a Copilot+ PC or the `windows-11-arm` CI runner).

The `windows-11-arm` runner has no Windows Hypervisor Platform feature,
so Hyper-V isolation is unavailable; process isolation needs only the Containers feature.

### x64

1. Execute in Windows PowerShell 5.1,

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

2. Execute in PowerShell 7,

```powershell
winget install --id Git.Git --source winget --exact

curl.exe -fsSL --retry 3 --retry-delay 5 --retry-all-errors `
    "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" `
    -o ./install-docker-ce.ps1
```

3. Execute in PowerShell 7 with administrator privileges,

```powershell
./install-docker-ce.ps1
```

4. Execute in PowerShell 7,

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.docker\cli-plugins" | Out-Null
curl.exe -fsSL --retry 3 --retry-delay 5 --retry-all-errors `
    "https://github.com/docker/compose/releases/download/v5.5.1/docker-compose-windows-x86_64.exe" `
    -o "$env:USERPROFILE\.docker\cli-plugins\docker-compose.exe"
```

5. Execute in PowerShell 7,

```powershell
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
docker compose -f tests/e2e/windows/compose.yaml run --rm --build e2e
```

To check the `vfox` x `flavor` x `mirror` matrix expansion without
starting containers, override the service command:

```powershell
docker compose -f tests/e2e/windows/compose.yaml run --rm e2e go test -short ./...
```

### arm64

1. Execute in Windows PowerShell 5.1,

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

2. Execute in PowerShell 7,

```powershell
winget install --id Git.Git --source winget --exact
# Host Go stays here: building the moby engine from source needs it. The
# suite itself runs from a container (see below), no host Go involved.
winget install --id GoLang.Go --source winget --exact
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
pwsh -NoProfile -File .\tests\e2e\windows\install-docker-arm64.ps1
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.docker\cli-plugins" | Out-Null
curl.exe -fsSL --retry 3 --retry-delay 5 --retry-all-errors `
    "https://github.com/docker/compose/releases/download/v5.5.1/docker-compose-windows-aarch64.exe" `
    -o "$env:USERPROFILE\.docker\cli-plugins\docker-compose.exe"
$env:ARCH = 'arm64'
docker compose -f tests/e2e/windows/compose.yaml run --rm --build e2e
```
