# 平台支持

[中文](platforms.md) | [English](../platforms.md)

插件可以在 x64 和 ARM64 的 Linux、macOS 和 Windows 上安装 Flutter。操作系统和 CPU 架构取自运行插件的 vfox 二进制（`osType` 和 `archType` 就是 Go 的 `GOOS` 和 `GOARCH`）：`darwin` 变成 `macos`，`amd64` 变成 `x64`，`arm64` 保持不变。其他 CPU 会报一条点出该 CPU 的提示，见 [troubleshooting.md](troubleshooting.md#flutter-does-not-support-the-386-architecture)。

| 机器 | 安装来源 | 发布索引 |
| --- | --- | --- |
| Linux x64 | Google 发布的 `.tar.xz` 压缩包 | `releases_linux.json` |
| Linux ARM64 | `flutter/flutter` 的 git 标签，见 [arm64.md](arm64.md#linux-arm64) | `releases_linux.json` |
| macOS Apple 芯片 | `.zip` 压缩包，arm64 和 x64 | `releases_macos.json` |
| macOS Intel | `.zip` 压缩包，x64 和 arm64 | `releases_macos.json` |
| Windows x64 | `.zip` 压缩包 | `releases_windows.json` |
| Windows ARM64 | `flutter/flutter` 的 git 标签，见 [arm64.md](arm64.md#windows-arm64) | `releases_windows.json` |

OpenHarmony 构建版本在每种机器上都是从 gitcode.com 检出的，见 [ohos.md](ohos.md)。发布索引读自 `https://storage.googleapis.com/flutter_infra_release/releases/`，或者 `FLUTTER_STORAGE_BASE_URL` 指定的镜像，见 [mirror.md](mirror.md)。

`3.47.4`、`3.47.4-x64` 和 `3.47.4-arm64` 在各种机器上分别得到什么，见 [arm64.md](arm64.md#各种机器分别得到什么)。

## 前提条件

- **vfox**，并且已经挂载到 Shell，这样 `vfox use` 之后 `flutter` 才在 `PATH` 里，见 vfox 的[快速入门](https://vfox.dev/zh-hans/guides/quick-start.html)。插件声明 vfox 0.3.0 是它能加载的最老版本。测试跑的是最新的 vfox 发布版和 vfox 的 `main`；主目录里带空格的 Windows 账户需要 vfox 1.0.13 或更新的版本（[vfox#712](https://github.com/version-fox/vfox/pull/712)）。
- **`git`**：Linux ARM64 和 Windows ARM64 的每次安装、OpenHarmony 构建版本，以及 [flutter-upgrade.md](flutter-upgrade.md) 里的漂移检查都要用。漂移检查在安装时向 `git` 要 SDK 的提交；没有 `git` 时安装依然会成功，写出的 `.vfox-manifest` 里没有提交，`vfox use` 永远不会警告。Flutter 本身也需要 `git`。
- **Flutter 自己的工具。** Android、iOS、Linux、Windows 和 Web 开发各有各的要求（Android SDK、Xcode、Visual Studio、GTK 等等），vfox 不会安装它们，见 [Flutter 的安装指南](https://docs.flutter.cn/install)。[README](../../README_CN.md#安装) 里的示例为 Ubuntu 装了 `curl git unzip xz-utils zip libglu1-mesa`。
- **磁盘空间。** 压缩包 1.6 到 2.3 GB（见 [versions.md](versions.md#安装)），vfox 解压后会把它删掉。Flutter 工具会为你要构建的平台下载所需的内容，SDK 会随之变大。源码安装还要给检出留出空间。你安装的每个名字都是一个独立的 SDK，见 [versions.md](versions.md#已安装的名称)。

## 插件会连接的地址

| 主机 | 用来做什么 | 什么时候 |
| --- | --- | --- |
| `storage.googleapis.com`，或你的镜像 | 发布索引、压缩包，以及 `flutter` 工具自己下载的东西，比如源码安装的 Dart SDK 和引擎产物 | 总是 |
| `gitcode.com` | OpenHarmony 版本的列表（一个 API 请求），以及 OpenHarmony 构建版本的检出 | `vfox search` 或 `vfox install` 的 `latest` 列出版本时要列表，安装 OpenHarmony 构建版本时也要；检出只在 OpenHarmony 构建版本时 |
| `github.com` | `flutter/flutter` 的检出 | Linux ARM64 和 Windows ARM64 的安装 |

`pub.dev` 不是插件要连的，但 Flutter 工具启动时会连它，测试套件也会检查它能否访问。安装官方版本不需要 `gitcode.com`，防火墙挡住它，也只是让 `vfox search` 快速试两次并给出一条警告，见 [troubleshooting.md](troubleshooting.md#gitcodecom-被限流)。未发布：0.2.4 每次安装也要问 `gitcode.com`，并且会等它。

## 测试覆盖的范围

Lua 的 hook 测试（`tests/hooks_test.lua`）对每个 pull request 离线运行。它们对着一份发布索引的样本，模拟 x64 和 arm64 上的 Linux、macOS 和 Windows。

容器测试套件用真实的 vfox 安装真实的 Flutter，每种组合各用一个一次性容器，见 [e2e.md](e2e.md)：

| 机器 | 容器 | Flutter | vfox |
| --- | --- | --- | --- |
| Linux x64 和 Linux ARM64 | Ubuntu 26.04，用 bash 驱动。另有一个测试用 zsh 和 Homebrew 装的 vfox | 3.47.4 | 最新发布版和 `main` |
| Windows x64 和 Windows ARM64 | Windows Server 2025 Server Core，用 PowerShell 7 驱动，vfox 主目录放在带空格的路径里 | 3.47.4 | 最新发布版和 `main` |

在 x64 上，这些运行还会针对 OpenHarmony 构建版本 3.41.10-ohos-1.0.0 重复一遍，只对最新的 vfox，还会设置 CFUG 镜像再跑一遍。ARM64 只跑官方构建。每次运行都会安装这个版本、检查漂移警告，并启动 `flutter` 和 `dart`。

macOS 不在容器测试里，因为容器跑不了它。它的架构选择只由离线测试覆盖。
