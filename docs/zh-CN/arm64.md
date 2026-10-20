# 架构选择

[中文](arm64.md) | [English](../arm64.md)

可安装的版本里有带架构后缀的，比如 `3.47.4-arm64` 和 `3.47.4-x64`。两种构建可以都装上，再来回切换。以 Apple 芯片的 Mac 为例：

```bash
vfox install flutter@3.47.4-arm64
vfox install flutter@3.47.4-x64
vfox use --global flutter@3.47.4-x64
```

不带架构的命令，比如 `vfox install flutter@3.47.4` 或 `vfox install flutter@stable`，仍然选本机架构，安装后的版本名也和以前一样。渠道也可以带后缀，比如 `vfox install flutter@stable-x64`。版本列表先列默认架构，再列其他架构，每一组内部按版本号排序。这样 `@latest` 就会保持在默认架构上。

列表里只有 Flutter 为当前操作系统提供的架构。请求其他架构会报 `no installable runtime provided`。

## 各种机器分别得到什么

| 机器 | `3.47.4`、`stable` | `3.47.4-x64` | `3.47.4-arm64` |
| --- | --- | --- | --- |
| Linux x64 | Linux 压缩包 | 同一个压缩包，装成 `3.47.4-x64` | 不提供 |
| Linux ARM64 | 从 git 标签源码安装 | Linux x64 压缩包，在这里运行不了 | 源码安装，名字是 `3.47.4-arm64` |
| macOS Apple 芯片 | arm64 压缩包 | x64 压缩包，需要 Rosetta | arm64 压缩包，名字是 `3.47.4-arm64` |
| macOS Intel | x64 压缩包 | 同一个压缩包，名字是 `3.47.4-x64` | arm64 压缩包，在这里运行不了 |
| Windows x64 | Windows 压缩包 | 同一个压缩包，装成 `3.47.4-x64` | 不提供 |
| Windows ARM64 | 从 git 标签源码安装 | Windows x64 压缩包 | 源码安装，名字是 `3.47.4-arm64` |

最后两列里的名字是安装后的名字，见 [versions.md](versions.md#已安装的名称)。在 x64 机器上同时装 `3.47.4` 和 `3.47.4-x64`，得到的是同一个 Flutter 的两份安装。要么总是写后缀，要么总是不写。

## 没有架构元数据的发布版本

Flutter 的发布索引给大多数版本标了架构（`dart_sdk_arch`），有些老版本没有。2026-10-21 时，它们是稳定版 `1.17.0` 到 `1.17.5`、`1.22.5` 和 `1.22.6`，以及到 `2.10.0-0.3.pre` 为止的预发布版本，一共 114 个。插件在所有机器上都不带后缀地列出它们，安装的是 Flutter 发布的那一个压缩包，是 x64 构建：

```bash
vfox install flutter@1.22.6
```

它们不会以 `-arm64` 或 `-x64` 的形式提供，所以 `vfox install flutter@1.22.6-arm64` 和 `vfox install flutter@1.22.6-x64` 都会失败。因为它们算作默认架构，所以排在原生构建中间，不会排到外来架构的后面。在 Linux ARM64 和 Windows ARM64 上，它们也没有源码安装（见[限制](#限制)），所以 `vfox install flutter@1.22.6` 在那里装的是 x64 压缩包。

## macOS

### Apple 芯片

运行 x64 构建需要 Rosetta。

Flutter 从 `2.12.0-4.1.pre`（预发布版本）和 `3.0.0`（稳定版）开始才有 arm64 构建。更老的版本只有 x64 构建，而且不带后缀的名字不会退回到它，所以要明确地要：

```bash
vfox install flutter@2.10.5-x64
```

`vfox install flutter@2.10.5` 会报 `no installable runtime provided`。

### Intel

macOS 的发布索引里不管是哪种 Mac 都带 arm64 构建，所以在 Intel 的 Mac 上也会列出它们，`vfox install flutter@3.47.4-arm64` 也能装上一个。它在 Intel 的 Mac 上运行不了。

## Linux ARM64

在 Linux ARM64 上，插件安装的是官方 `flutter/flutter` 仓库的 git 标签，而不是预编译的包。Flutter 工具首次运行时会自己引导出对应的原生 `dart-sdk-linux-arm64`，所以得到的是原生 SDK。

明确写 `-x64` 的请求仍然解析到上游的压缩包，它在 Linux ARM64 上运行不了。

## Windows ARM64

在 Windows ARM64 上，插件同样安装官方 `flutter/flutter` 仓库的 git 标签，而不是预编译的包，原因和 Linux ARM64 一样：上游没有发布 `windows-arm64` 的压缩包。Flutter 工具首次运行时会自己引导出对应的原生 `dart-sdk-windows-arm64`，所以得到的是原生 SDK。

明确写 `-x64` 的请求仍然解析到上游的 x64 压缩包。它不是原生构建，插件的测试也不会运行它。

## 源码安装如何进行

Linux ARM64 和 Windows ARM64 会为“有 x64 构建、并且能用原生 Dart SDK 运行”的版本列出一个 `-arm64` 源码安装（2026-10-21 时 Linux 上有 288 个，Windows 上有 37 个），数据取自同一份发布索引，见[能原生运行的发布版本](#能原生运行的发布版本)。安装其中一个的过程是：

1. 从一个空目录 `.vfox/tmp/<名称>` 开始，它在 `$VFOX_HOME` 下；没设置 `VFOX_HOME` 就在你的主目录下（`~/.vfox/tmp/3.47.4`，`3.47.4-arm64` 则是 `~/.vfox/tmp/3.47.4-arm64`），
2. 在那里执行 `git init`，并设置 `core.longpaths=true` 和 `core.autocrlf=false`，
3. 执行 `git fetch --depth 1 https://github.com/flutter/flutter.git refs/tags/3.47.4`，最多三次，
4. 检出 `FETCH_HEAD`，并检查 `bin/internal/engine.version` 是否存在，
5. 把这个目录交给 vfox，由它移动到安装位置（vfox 会打印 `Moving ... to ...`）。

得到的是只含一个提交的浅克隆，检出在一个标签上，而不在某个分支上。它大约 225 MB，3.47.7 在网速很快时拉取用了 10 秒。这样的检出也是 `flutter --version` 在这种安装上显示 `channel [user-branch]` 和 `unknown source`，而不是 `channel stable` 的原因。

安装失败会把这个目录留下。下次安装同名版本时会先删掉它，你自己删也没问题。

## 能原生运行的发布版本

`-arm64` 源码安装的意义，就是用上原生的 Dart SDK。Flutter 工具在第一次运行时，只有两个条件同时成立才会取 ARM64 的 Dart SDK：这个版本自己的引导脚本（`bin/internal/update_dart_sdk.sh`，Windows 上是 `update_dart_sdk.ps1`）要去请求它，Flutter 的存储里也要有它（该版本引擎修订号下的 `dart-sdk-<os>-arm64.zip`）。下表是这两个条件都成立的最老版本，2026-10-21 对 300 个有 x64 构建的版本逐个检查的结果：

| 机器 | 从哪个版本开始有原生 Dart SDK | 在它之前 |
| --- | --- | --- |
| Linux ARM64 | Flutter 2.2.0 | 脚本请求的是 x64 的 SDK，即 `1.20.0` 到 `2.0.6`（17 个版本）。存储里从 2.0.0 起就有 ARM64 的 SDK，只是这些脚本不去请求它，而 ARM64 的机器运行不了 x64 的 SDK |
| Windows ARM64 | Flutter 3.44.0-0.1.pre | 脚本从 `3.20.0-1.1.pre` 起会请求 ARM64 的 SDK，存储里没有时会说 `The current channel's Dart SDK does not support Windows Arm64, falling back to Windows x64...`，改用 x64 的 SDK，Windows 靠它的模拟层运行它。存储里有 ARM64 SDK 的更老版本只有七个 beta，其中三个工具会用上（`3.20.0-1.1.pre`、`3.21.0-0.0.pre` 和 `3.30.0-0.1.pre`） |

插件从这个版本开始提供 `-arm64` 源码安装。Linux ARM64 上的 `vfox install flutter@1.20.0`，以及 Windows ARM64 上的 `vfox install flutter@3.43.0-0.3.pre`，都会以 `no installable runtime provided` 结束。更老版本的 x64 压缩包仍然在列表里：`vfox install flutter@3.43.0-0.3.pre-x64` 装的是其中一个，Windows ARM64 靠模拟运行它；Linux ARM64 上的 `flutter@1.20.0-x64` 适合能运行 x64 程序的环境。这张表是 `lib/source.lua` 里的数据，检查方法见 [development.md](development.md#刷新-dart-sdk-表)。

## 限制

### Linux ARM64 和 Windows ARM64

- **需要 `git`。** 检出会对 `https://github.com/flutter/flutter.git` 执行 `git init` / `fetch` / `checkout`。拉取卡住（一分钟内速度低于 1 KB/s）时会被放弃并重试，最多三次；`GIT_HTTP_LOW_SPEED_LIMIT` / `GIT_HTTP_LOW_SPEED_TIME` 可以改这个阈值。
- **第一次运行 `flutter` 很慢。** 它要下载原生的 Dart SDK 并构建 Flutter 工具，所以需要网络。
- **不做校验和验证。** git 的历史就是完整性检查。
- **老版本没有 `-arm64` 变体。** 没有架构元数据的版本（比如 `1.22.6`，见上文）保持原有的、只有 x64 的行为。
- **镜像对克隆不起作用。** `FLUTTER_STORAGE_BASE_URL`（见 [mirror.md](mirror.md)）只影响发布索引、x64 压缩包和 Flutter 工具自己的下载；源码安装从 GitHub 克隆。要给 GitHub 的源码安装用镜像，请设置 `VFOX_FLUTTER_GITHUB_MIRROR`（见 [mirror.md](mirror.md)）。
- **老版本不提供。** 它们用不上原生的 Dart SDK，见[能原生运行的发布版本](#能原生运行的发布版本)。
- **你的 git 配置同样生效。** 插件以你的身份运行 `git`，只有换行符例外：它会在检出里设置 `core.autocrlf=false`，这样全局的 `true`（Git for Windows 的安装程序默认建议这样设）就不会让 Flutter 的 shell 脚本带上 CRLF 换行。Flutter 的 `.gitattributes` 只对 `bin/flutter`、`bin/flutter-dev` 和 `bin/dart` 强制使用 LF，所以设成 `true` 时，Linux ARM64 的安装和 Linux 上的 OpenHarmony 构建版本，检出的 `bin/internal/shared.sh` 和 Flutter 其他 `.sh` 文件里都会是 CRLF，第一次运行 `flutter` 就会停在 `bin/internal/shared.sh: line 5: $'\r': command not found`。0.2.5 之前的版本用的是你自己的设置，见 [troubleshooting.md](troubleshooting.md#bininternalsharedsh-line-5-r-command-not-found)。
- **残留。** 安装失败会把 `.vfox/tmp/<名称>` 留下，见[源码安装如何进行](#源码安装如何进行)。
