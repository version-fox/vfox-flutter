# E2E

[中文](e2e.md) | [English](../e2e.md)

离线的 Lua hook 测试（`tests/hooks_test.lua`）在 **Test Plugin** 工作流里运行。端到端套件在容器里对着真实的 vfox 运行，覆盖 Linux 和 Windows；每个 `vfox` × `flavor` × `mirror` 的组合都有自己的一次性容器。CI 在标准运行器上原生运行这两套测试（Docker，加上 `actions/setup-go` 提供的 Go）。在本地，仓库的开发容器可以复现 Linux 的运行；Windows 主机改用 Docker Compose 运行器镜像，因为开发容器无法承载 Windows 容器镜像（见下文）。

[platforms.md](platforms.md#测试覆盖的范围) 概括了这些套件覆盖什么，[development.md](development.md) 说明了插件如何工作。

## 开发容器

`.devcontainer/` 会打开一个 Linux 开发环境，四种主机平台都能用：

| 主机 | 开发容器怎么运行 |
| --- | --- |
| Linux amd64 / arm64 | 原生 |
| Windows amd64 / arm64 | Docker Desktop 的 Linux 容器模式（WSL 2） |

里面有 Go 1.26.8（CI 安装的版本）、Docker CLI、stylua、lua-language-server 和许可证工具，版本都固定为 `.github/workflows/lint.yml` 和 `license.yml` 里的那些，并且挂载了主机 Docker 守护进程的 socket。套件随后让 testcontainers 对着那个守护进程运行（Docker-out-of-Docker），启动的目标容器与原生 CI 运行器启动的相同；这里有意不用 Docker-in-Docker，所以镜像缓存和网络仍然是主机的。镜像不需要工作区里的任何文件，所以构建上下文只是 `.devcontainer/`；`postCreateCommand` 会为 `tests/e2e` 预热 Go 模块缓存，这样第一次运行测试时不会停下来下载。

用任何支持 Dev Containers 规范的工具都能打开它：在 VS Code/Cursor 里执行 **Dev Containers: Reopen in Container**，或者用命令行：

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

`TESTCONTAINERS_RYUK_DISABLED=true` 已经预先设好：Ryuk 会在主机守护进程上发布一个端口，并等套件回连它，而 Docker-out-of-Docker 容器做不到这一点。套件改为通过 `t.Cleanup` 显式终止每个容器；被杀掉的运行留下的容器都带 `vfox-flutter-e2e-` 这个名字前缀，可以据此清理。CI 设置了 `E2E_ASYNC_CLEANUP=true`，让清理在后台进行，而不是拖住每个组合，因为它的运行器本来就会被丢弃；最后几个容器因此可能比套件活得更久。使用 rootless Docker 的用户，在打开容器之前先在主机上执行 `export DOCKER_SOCK="$XDG_RUNTIME_DIR/docker.sock"`。在 Windows 主机上，把检出放在 WSL 2 里面（比如 `\\wsl$` 下）能让文件和 bind mount 的访问保持很快；放在 Windows 文件系统上也能用。

Windows *容器*的覆盖（`tests/e2e/windows`）无法在开发容器里运行：Dev Containers 规范不支持 Windows 容器镜像（[vscode-remote-release#445](https://github.com/microsoft/vscode-remote-release/issues/445)），而 Windows 容器只能在 Windows 守护进程上运行。那个套件仍然在 Windows 主机上使用它的 Docker Compose 运行器，见下文的 [Windows 11 Pro](#windows-11-pro)。

## Linux (Ubuntu 26.04)

在开发容器里，从仓库根目录执行：

```bash
cd tests/e2e
go test -v -timeout 55m -run TestE2E ./linux
```

迭代时，用同样的办法缩小范围：

```bash
VFOX_VERSION=latest FLAVOR=official MIRROR=default E2E_MAX_JOBS=1 go test -v -timeout 55m -run TestE2E ./linux
```

在原生主机上，同样的命令也能用，前提有两个：Docker Engine（rootful 或 rootless）和 Go 1.26.8，这正是 CI 准备的环境。使用 rootless Docker 的用户要把 Docker 客户端指向自己的 socket（`export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"`）；开发容器的 socket 挂载已经替你处理了这种情况。ARM64 上只运行 `official` flavor：OpenHarmony 没有发布 `linux-arm64` 的 Dart SDK（见 [ohos.md](ohos.md#限制)），所以 `ohos` flavor 在那里无法引导。

## Windows 11 Pro

Windows 容器无法跨架构模拟，所以 ARM64 套件需要一台 ARM64 主机（Copilot+ PC，或者 CI 的 `windows-11-arm` 运行器）。

这个套件没有开发容器：Dev Containers 规范不接受 Windows 容器镜像（见[开发容器](#开发容器)），所以它保留了自己的 Docker Compose 运行器。运行器镜像（`Dockerfile-runner`：标准的 servercore 加上固定版本的 Go MSI）通过挂载进来的命名管道驱动主机守护进程；对主机的要求是 Windows 容器模式的 Docker，加上 Compose v5 插件（下面按每台机器装一次）。Go 从不接触主机，所以不会和 vfox 管理的工具链冲突。

CI 跳过这个运行器镜像（每次构建要花好几分钟），直接在运行器上用 `actions/setup-go` 提供的 Go 运行 `go test`，和 Linux 的作业一样。它还把引擎的数据根目录从运行器那块很慢的 C: 系统盘上挪走了，否则拉取镜像、提交层，以及容器里安装 Flutter，都会慢得像爬：在 `windows-latest` 上放到工作区旁边的本地 D: 盘，在 `windows-11-arm` 上放到它出厂时没有格式化的本地 NVMe 盘。这样一来，那里的 `E2E_MAX_JOBS` 是 4。两个套件都先启动最慢的组合（CN 镜像，然后是官方 SDK），所以最后启动的几个都很短。解包 servercore 基础镜像仍然是最长的准备步骤，所以 CI 在设置 Go 和编译套件之前，就先在后台开始拉取它。

目标镜像（`tests/e2e/windows/Dockerfile`）是从便携的 zip 解包 PowerShell 7 和 MinGit，而不是运行它们的安装程序：Git for Windows 的安装程序是 x86 程序，arm64 容器只能在模拟下运行它。MinGit 是同一个 `git.exe`，只是没有 bash、Perl 和凭据管理器，而 vfox 和 Flutter 都不会调用它们。

`main` 的几个组合共用一个 `vfox.exe`：镜像构建的同时，套件用自己的 Go 工具链从 vfox 的 main 分支构建它，并在容器启动之前把它复制进每个 `main` 容器。

`windows-11-arm` 运行器没有 Windows Hypervisor Platform 功能，所以 Hyper-V 隔离不可用；进程隔离只需要 Containers 功能。

每个组合运行时，`VFOX_HOME` 都指向一个含空格的路径（`C:\Users\John Doe\.vfox`），对应 [vfox#723](https://github.com/version-fox/vfox/issues/723)。vfox 从 1.0.13 起能处理这样的路径（[vfox#712](https://github.com/version-fox/vfox/pull/712)），所以 `latest` 和 `main` 都带着这个修复。

### x64

1. 在 Windows PowerShell 5.1 中执行：

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

2. 在 PowerShell 7 中执行：

```powershell
winget install --id Git.Git --source winget --exact
# 按需配置 Git。

curl.exe -fsSL `
    "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" `
    -o ./install-docker-ce.ps1
```

3. 在以管理员身份启动的 PowerShell 7 中执行：

```powershell
./install-docker-ce.ps1
```

4. 在 PowerShell 7 中执行：

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

1. 在 Windows PowerShell 5.1 中执行：

```powershell
winget install --id Microsoft.PowerShell --source winget --exact
```

2. 在 PowerShell 7 中执行：

```powershell
winget install --id Git.Git --source winget --exact
# 按需配置 Git。
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

在 arm64 上，构建引擎用的也是 Go，所以 `install-docker-arm64.ps1` 要在运行套件之前先运行；之后 compose 的运行器镜像会带着它自己固定版本的 Go 来跑测试，主机上的 Go 不会再用到。这个脚本把引擎的二进制放在 `C:\vfox-docker\bin`，之后的运行只要它们与脚本固定的版本一致就会复用（CI 缓存的就是这个目录）；`-DataRoot` 可以把引擎的镜像和容器从默认的 `C:\vfox-docker\data` 挪到别处。要缩小运行范围，在 compose 命令前面加上 `$env:VFOX_VERSION = 'latest'; $env:FLAVOR = 'official'`，和其他平台一样。

## 本地检查

在开发容器里执行（下面所有工具都已预装，并且固定为工作流使用的版本），或者在主机上准备同样的工具。

```bash
# Lua 和 Go 的检查（.github/workflows/lint.yml）。
cd tests/e2e
go test -short ./...
test -z "$(gofmt -l .)"
go vet ./...
cd ../..

stylua --check .
lua-language-server --check . --checklevel=Warning
```

```bash
# 许可证头（.github/workflows/license.yml）。
license-eye header check
license-eye header fix
addlicense -check -f .license.tpl tests/e2e/windows/*.ps1
addlicense -f .license.tpl tests/e2e/windows/*.ps1
```

在只有 Docker 的主机上，许可证检查改为以容器方式运行（和 CI 用的是同样的镜像）：

```bash
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header check
docker run --rm -v "$PWD:/work" -w /work apache/skywalking-eyes:0.9.0 header fix
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -check -f .license.tpl tests/e2e/windows/*.ps1
docker run --rm -v "$PWD:/src" ghcr.io/google/addlicense:v1.2.0 -f .license.tpl tests/e2e/windows/*.ps1
```
