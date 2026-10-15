# E2E

The offline Lua hook tests (`tests/hooks_test.lua`) run in the **Test Plugin** workflow.
The end-to-end suite runs in containers against real vfox on Linux and Windows;
each `vfox` x `flavor` x `mirror` combination gets its own throwaway
container. On Linux, CI runs the suite natively on the stock runners (Docker
plus Go from `actions/setup-go`), the way the repository dev container
reproduces it locally. On Windows it runs through a Docker Compose runner
image, since dev containers cannot host Windows container images (see below).

## Dev container

`.devcontainer/` opens a Linux development environment that works on all four
host platforms:

| Host                  | How the dev container runs                     |
| --------------------- | ---------------------------------------------- |
| Linux amd64 / arm64   | natively                                       |
| Windows amd64 / arm64 | Docker Desktop in Linux-container mode (WSL 2) |

It carries Go 1.26.8 (the version CI installs), the Docker CLI, stylua,
lua-language-server, and the license tools — all pinned to the versions in
`.github/workflows/lint.yml` and `license.yml` — and mounts the host Docker
daemon socket. The suites then run testcontainers against that daemon
(Docker-out-of-Docker), spawning the same target containers a native CI
runner spawns; this is deliberately not Docker-in-Docker, so image cache and
networking stay the host's. The image needs no workspace files, so the build
context stays at `.devcontainer/`; `postCreateCommand` warms the Go module
cache for `tests/e2e` so the first test run does not stop to download.

Open it with any Dev Containers spec tool — **Dev Containers: Reopen in
Container** in VS Code/Cursor, or the CLI:

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

`TESTCONTAINERS_RYUK_DISABLED=true` is preset: Ryuk publishes a port on the
host daemon and waits for the suite to dial it back, which a
Docker-out-of-Docker container cannot do. The suites terminate every
container explicitly via `t.Cleanup` instead; leftovers from killed runs
share the `vfox-flutter-e2e-` name prefix for pruning. Rootless Docker users
export `DOCKER_SOCK="$XDG_RUNTIME_DIR/docker.sock"` on the host before
opening the container. On Windows hosts, keeping the checkout inside WSL 2
(e.g. under `\\wsl$`) keeps file and bind-mount access fast; a checkout on
the Windows filesystem works too.

Windows *container* coverage (`tests/e2e/windows`) cannot run in a dev
container: the Dev Containers spec does not support Windows container images
([vscode-remote-release#445](https://github.com/microsoft/vscode-remote-release/issues/445)),
and Windows containers only run on a Windows daemon. That suite keeps its
Docker Compose runner on a Windows host; see [Windows 11 Pro](#windows-11-pro)
below.

## Linux (Ubuntu 26.04)

Inside the dev container, from the repository root:

```bash
cd tests/e2e
go test -v -timeout 55m -run TestE2E ./linux
```

Scope it down while iterating the same way:

```bash
VFOX_VERSION=latest FLAVOR=official MIRROR=default E2E_MAX_JOBS=1 go test -v -timeout 55m -run TestE2E ./linux
```

On a native host the same command works with two prerequisites — Docker
Engine (rootful or rootless) and Go 1.26.8 — which is exactly what CI
provisions. Rootless Docker users point the Docker client at their socket
(`export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"`); the dev
container's socket mount covers that case for you. On ARM64 the official
flavor runs only: OpenHarmony publishes no `linux-arm64` Dart SDK (see
`docs/ohos.md`), so the ohos flavor cannot bootstrap there.

## Windows 11 Pro

Windows containers cannot be emulated across architectures, so the ARM64 suite
needs an ARM64 host (a Copilot+ PC or the `windows-11-arm` CI runner).

There is no dev container for this suite — the Dev Containers spec rejects
Windows container images (see [Dev container](#dev-container)) — so it keeps
its Docker Compose runner. The runner image (`Dockerfile-runner`: stock
servercore plus the pinned Go MSI) drives the host daemon through the mounted
named pipe; the host requirement is Docker in Windows-container mode plus the
Compose v5 plugin (installed once per machine below). Go never touches the
host, so it cannot conflict with a vfox-managed toolchain.

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

On arm64, Go is also what builds the engine, so `install-docker-arm64.ps1`
runs before the suite; the compose runner image then carries its own pinned
Go for the tests, and the host Go is not used again. Scope the run down with
`$env:VFOX_VERSION = 'latest'; $env:FLAVOR = 'official'` in front of the
compose command, as on the other platforms.

## Local checks

Execute from the dev container — everything below is preinstalled and pinned
to the versions the workflows use — or provision the same tools on a host.

```bash
# Lua and Go checks (.github/workflows/lint.yml).
cd tests/e2e
go test -short ./...
test -z "$(gofmt -l .)"
go vet ./...
cd ../..

stylua --check .
lua-language-server --check . --checklevel=Warning
```

```bash
# License headers (.github/workflows/license.yml).
license-eye header check
license-eye header fix
addlicense -check -f .license.tpl tests/e2e/windows/*.ps1
addlicense -f .license.tpl tests/e2e/windows/*.ps1
```

On a Docker-only host the license checks run as containers instead (the same
images CI uses):

```bash
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header check
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header fix
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -check -f .license.tpl tests/e2e/windows/*.ps1
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -f .license.tpl tests/e2e/windows/*.ps1
```
