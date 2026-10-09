# E2E

The offline Lua hook tests (`tests/hooks_test.lua`) run in the **Test Plugin** workflow.
The end-to-end suite runs in containers against real vfox on Linux and Windows;
each `vfox` x `flavor` x `mirror` combination gets its own throwaway container.

## Ubuntu 26.04.1

Only Docker Engine (in either rootful or rootless mode) is required on the host. 
On ARM64 it runs the official flavor only: 
OpenHarmony publishes no `linux-arm64` Dart SDK (see `docs/ohos.md`), 
so the ohos flavor cannot bootstrap there.

### rootful Docker

Execute in Bash,

```bash
sudo apt install --assume-yes git
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
docker compose -f tests/e2e/linux/compose.yaml run --rm e2e
```

### rootless Docker

With rootless Docker the daemon socket lives elsewhere; point `DOCKER_SOCK`
at it instead:

```bash
sudo apt install --assume-yes git
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
DOCKER_SOCK="$XDG_RUNTIME_DIR/docker.sock" docker compose -f tests/e2e/linux/compose.yaml run --rm e2e
```

## Windows 11 Pro

Windows containers cannot be emulated across architectures, so the ARM64 suite
needs an ARM64 host (a Copilot+ PC or the `windows-11-arm` CI runner).

The `windows-11-arm` runner has no Windows Hypervisor Platform feature,
so Hyper-V isolation is unavailable; process isolation needs only the Containers feature.

The `main` combos run with `VFOX_HOME` pointing inside a path containing a
space (`C:\Users\John Doe\.vfox`), mirroring
[issue #33](https://github.com/version-fox/vfox-flutter/issues/33). Only vfox
`main` carries the fix for such paths
([vfox#712](https://github.com/version-fox/vfox/pull/712)), so `latest`
combinations still run with an unspaced home.

### x64

1. Execute in Windows PowerShell 5.1,

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

2. Execute in PowerShell 7,

```powershell
winget install --id Git.Git --source winget --exact
# Configure Git appropriately.

curl.exe -fsSL `
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

curl.exe -fsSL `
    "https://github.com/docker/compose/releases/download/v5.5.1/docker-compose-windows-x86_64.exe" `
    -o "$env:USERPROFILE\.docker\cli-plugins\docker-compose.exe"

git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
docker compose -f tests/e2e/windows/compose.amd64.yaml run --rm --build e2e
```

### arm64

1. Execute in Windows PowerShell 5.1,

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

2. Execute in PowerShell 7,

```powershell
winget install --id Git.Git --source winget --exact
# Configure Git appropriately.
winget install --id GoLang.Go --source winget --exact
git clone git@github.com:version-fox/vfox-flutter.git
cd ./vfox-flutter/
pwsh -NoProfile -File .\tests\e2e\windows\install-docker-arm64.ps1
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.docker\cli-plugins" | Out-Null

curl.exe -fsSL `
    "https://github.com/docker/compose/releases/download/v5.5.1/docker-compose-windows-aarch64.exe" `
    -o "$env:USERPROFILE\.docker\cli-plugins\docker-compose.exe"

docker compose -f tests/e2e/windows/compose.arm64.yaml run --rm --build e2e
```

## Local checks

Execute in Bash on Ubuntu before pushing.

```bash
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header check
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header fix
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -check -f .license.tpl tests/e2e/windows/*.ps1
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -f .license.tpl tests/e2e/windows/*.ps1

cd tests/e2e
go test -short ./...
test -z "$(gofmt -l .)"
go vet ./...
cd ../..

stylua --check .
mise x aqua:LuaLS/lua-language-server@3.19.1 -- lua-language-server --check . --checklevel=Warning
```
