# 版本与命名

[中文](versions.md) | [English](../versions.md)

`vfox install`、`vfox use` 和 `vfox uninstall` 里 `flutter@` 后面的部分就是版本：可以是 `vfox search flutter` 打印出的某个发布版本的名字（带不带架构后缀都行），也可以是一个渠道。

```bash
vfox install flutter@3.47.4              # 稳定版，装本机架构的构建
vfox install flutter@3.47.4-x64          # 同一个版本，x64 构建
vfox install flutter@3.50.0-0.1.pre      # beta 版
vfox install flutter@stable              # stable 渠道当前指向的版本
vfox install flutter@3.41.10-ohos-1.0.0  # OpenHarmony 构建版本
```

版本必须整串匹配。`flutter@3.47` 和 `flutter@3` 不会选中最新的 3.47.x 或 3.x，而是报 `no installable runtime provided`。名字区分大小写（`flutter@Stable` 会失败），vfox 自己会去掉开头的 `v`，所以 `flutter@v3.47.4` 就是 `flutter@3.47.4`。

## 发布版本的名称

发布版本的名字就是它包含的 Flutter 版本号，写法和 Flutter 的发布索引一致。`vfox search` 会在名字旁边标出它发布到的渠道，见[搜索](#搜索)。

| 名称 | 含义 |
| --- | --- |
| `3.47.7` | 稳定版 |
| `3.50.0-0.1.pre` | beta 版。Flutter 的预发布版本都以 `.pre` 结尾 |
| `3.47.4-x64`、`3.47.4-arm64` | 同一个版本的 x64 或 arm64 构建，见 [arm64.md](arm64.md) |
| `1.22.6` | 没有架构元数据的老版本，在哪里装都一样，见 [arm64.md](arm64.md#没有架构元数据的发布版本) |
| `3.41.10-ohos-1.0.0` | OpenHarmony 构建版本：这个分支 3.41.10 线上的 1.0.0 版，见 [ohos.md](ohos.md) |
| `stable`、`beta` | 渠道，安装时会解析成一个具体的版本，见 [channels.md](channels.md) |

插件列出的是 Flutter 1.17（2020 年 4 月）以后的版本。更早的版本 Flutter 带 `v` 前缀发布（`v1.12.13+hotfix.9` 是插件停下来的第一个），不提供安装。

## 安装

`vfox install` 先问插件哪个包匹配，再由 vfox 下载并解压。

- 插件读取当前操作系统的 Flutter 发布索引：`https://storage.googleapis.com/flutter_infra_release/releases/` 下的 `releases_linux.json`、`releases_macos.json` 或 `releases_windows.json`；设置了 `FLUTTER_STORAGE_BASE_URL` 时则读取那个镜像下的同名文件（见 [mirror.md](mirror.md)）。最多请求三次，每次间隔五秒。
- 版本必须与索引里的某个名字完全相同，见[发布版本的名称](#发布版本的名称)。没有发布过的版本会报 `no installable runtime provided`。
- 不带架构后缀时，插件选本机架构的构建。没有架构元数据的版本只有一个压缩包，就用它。
- vfox 用索引里的 SHA-256 校验和验证压缩包，并打印 `Verifying checksum ...`。解压之后会删除压缩包。
- 在 Linux ARM64 和 Windows ARM64 上，插件安装的是 git 标签而不是压缩包，见 [arm64.md](arm64.md)。OpenHarmony 构建版本同样是 git 检出，见 [ohos.md](ohos.md)。两者都不做校验和验证。
- 安装一个已经存在的名字，会打印 `flutter@3.47.4 is already installed`，不会下载任何东西。
- 安装官方版本不会访问 gitcode.com。列出版本才会：`vfox search` 和 `vfox install` 的 `latest` 会去问它有哪些 OpenHarmony 版本，最多两次，问不到时会提示，见 [troubleshooting.md](troubleshooting.md#gitcodecom-被限流)。

压缩包很大：2026-10-21 的 3.47.7，Linux x64 是 1.6 GB，Windows x64 是 1.9 GB，macOS 是 2.3 GB。第一次运行 `flutter` 还会再下载东西，见 [troubleshooting.md](troubleshooting.md#看起来不对但其实正常的现象)。

## 已安装的名称

插件按你请求的版本给安装命名，只有你写了架构后缀才会带后缀。下面是 Linux x64 在 2026-10-21 的结果；渠道和 `latest` 会换成它们代表的那个版本：

| 你执行 | 已安装的名称 |
| --- | --- |
| `vfox install flutter@3.47.4` | `3.47.4` |
| `vfox install flutter@3.47.4-x64` | `3.47.4-x64` |
| `vfox install flutter@stable` | `3.47.7` |
| `vfox install flutter@stable-x64` | `3.47.7-x64` |
| `vfox install flutter@beta` | `3.50.0-0.1.pre` |
| `vfox install flutter@latest` | `3.47.7-x64`，即 `vfox search flutter` 的第一行，见[搜索](#搜索) |
| `vfox install flutter@3.41.10-ohos-1.0.0` | `3.41.10-ohos-1.0.0` |

`vfox list flutter` 显示的就是这些名字，`vfox use` 和 `vfox uninstall` 要写的也是它们：

```
$ vfox list flutter
-> 3.50.0-0.1.pre-x64
-> 3.47.4-x64
-> 3.47.4 <— current
```

在 x64 机器上，`3.47.4` 和 `3.47.4-x64` 是同一个 Flutter，vfox 把它们当作两份安装，各是一个完整的 SDK。要么总是写后缀，要么总是不写。卸载其中一个不会动另一个：

```bash
vfox uninstall flutter@3.47.4-x64
```

`vfox uninstall flutter@stable` 会回答 `flutter@stable is not installed`；`vfox uninstall` 和 `vfox use` 一样，要写已安装的名字。卸载正在使用的版本时，vfox 会切换到 `vfox list flutter` 里剩下的第一项，那可能是个 beta。

每份安装都在 vfox 主目录（默认是 `~/.vfox`，设置了 `VFOX_HOME` 则是它）下的 `cache/flutter/v-<名称>/flutter-<名称>/` 里，见 [troubleshooting.md](troubleshooting.md#flutter-在哪里)。

## 使用

`vfox use` 只认已安装的名字，原样匹配，不会补全，也不会搜索：

| 你执行 | 结果 |
| --- | --- |
| `vfox use flutter@3.47.4` | 选中 `3.47.4` |
| `vfox use flutter@3.47.4-x64` | 选中 `3.47.4-x64` |
| `vfox use flutter@3.47` | `flutter@3.47 is not installed` |
| `vfox use flutter@stable` | `flutter@stable is not installed`，见 [channels.md](channels.md) |
| `vfox use flutter@latest` | `vfox list flutter` 的第一项，那个列表由 vfox 自己排序，所以装了 beta 的话它就是 beta |

用 `vfox use` 的参数选择作用域：`--global`、`--project` 或 `--session`。不带参数时，Linux 和 macOS 上是会话作用域，Windows 上是全局作用域。选择会写在这些地方：

| 作用域 | 写入位置 | `flutter` 来自 |
| --- | --- | --- |
| `--global` | `~/.vfox/.vfox.toml` | `~/.vfox/sdks/flutter/bin` |
| `--project` | 当前目录里的 `.vfox.toml` | 那个目录里的 `.vfox/sdks/flutter/bin` |
| `--session` | 只在当前 Shell 里 | `~/.vfox/tmp` 下的某个目录 |

`.vfox.toml` 里写的是已安装的名字（`flutter = "3.47.4"`）。把它提交进仓库，大家构建项目时用的就是同一个 Flutter；`.vfox/` 则不要提交：vfox 不会替你把它加进 `.gitignore`。vfox 在 `legacyVersionFile.enable` 打开时还会读取 asdf 的 `.tool-versions`（`flutter 3.47.4`），vfox 1.0.13 默认是打开的。插件自己没有旧版本文件的支持，所以不会读取 `.fvmrc` 和 FVM 的 `.fvm` 目录。

插件会把 `<sdk>/bin` 加进 `PATH`，`flutter` 和 `dart` 就都在里面了。它不会设置 `FLUTTER_ROOT`，也不会把 `dart pub global activate` 放可执行文件的 `~/.pub-cache/bin` 加进去，这个要你自己加。

想在不切换版本的情况下用某个 Flutter 跑一条命令，或者是在没有启用 Shell 钩子的脚本、容器、IDE 任务里，可以用 `vfox exec`，同样要写已安装的名字：

```bash
vfox exec flutter@3.47.4 -- flutter --version
```

`vfox exec flutter@stable` 不行，见 [channels.md](channels.md#用版本号不要用渠道名)。

## 搜索

```
$ vfox search flutter
Available versions:
 - 3.47.7-x64 (stable) [dart 3.13.5]
 - 3.47.6-x64 (stable) [dart 3.13.5]
 ...
 - 1.17.0 (stable) [dart ]
 - 3.50.0-0.1.pre-x64 (beta) [dart 3.14.0 (build 3.14.0-315.1.beta)]
 - 3.49.0-0.2.pre-x64 (beta) [dart 3.14.0 (build 3.14.0-211.1.beta)]
 ...
 - 1.17.0-3.2.pre (beta) [dart ]
 - 3.41.10-ohos-1.0.0 (OpenHarmony)
 ...
```

每一行都是可以写在 `flutter@` 后面的名字，圆括号里是这个版本发布到的渠道，方括号里是随它一起的 Dart SDK。已安装的名字后面会有 `(installed)` 标记。Flutter 的索引里，`2.9.0-0.1.pre` 及更早的版本没有 Dart 版本，方括号就是空的。OpenHarmony 构建版本带的是 `(OpenHarmony)`，没有 Dart 版本。

标记只会出现在列表打印出的名字上。在 x64 的 Linux 和 Windows 上，几乎所有官方版本都以 `3.47.4-x64` 的形式列出，所以用 `vfox install flutter@3.47.4` 装出来的（已安装的名字是 `3.47.4`）不会有标记，用 `vfox install flutter@3.47.4-x64` 装的才有。以 `vfox list flutter` 为准。

在交互式终端里，`vfox search flutter` 会让你选一个版本并安装；其他情况只打印列表。vfox 会把结果缓存 12 小时（`vfox config cache.availableHookDuration`），所以刚发布一分钟的版本可能还看不到；`vfox config cache.availableHookDuration 0` 可以关掉缓存。

列表按下面的顺序排：

1. 官方版本排在 OpenHarmony 构建版本之前。
2. 本机架构排在其他架构之前。没有架构元数据的版本算作本机架构。
3. stable 渠道的版本排在 beta 和 dev 渠道的预发布版本之前。
4. 按版本号里的数字，新的在前。`3.47.0` 排在 `3.47.0-0.4.pre` 之前。
5. 同一个版本的两个构建，本机架构在前；同一个版本在两个渠道里时，beta 在 dev 之前。

所以第一行是最新的稳定版，`vfox install flutter@latest` 装的就是它，带着架构后缀：

```
$ vfox install flutter@latest
Using latest version: 3.47.7-x64
```

`latest` 会保持在本机架构上，原因见 [arm64.md](arm64.md)，而且永远不会选中 OpenHarmony 构建版本。

有些版本会出现不止一次。它们在 Flutter 的索引里就不止一条：有的是从一个渠道晋升到另一个渠道，每个渠道各有一个压缩包（`2.13.0-0.1.pre` 在 beta 和 dev 里都有），这几行装出来的名字相同。有的是版本重新发布过，同一个压缩包对应两个校验和，插件只列其中最新的那条，也就是校验和与文件相符的那条（Flutter 重新发布过的有 `3.13.3`、`3.9.0-0.1.pre` 和 `3.17.0-0.0.pre` 这三个），见 [troubleshooting.md](troubleshooting.md#checksum-error)。

列表有多长取决于机器。2026-10-21 的数量：Linux x64 是 455 个名字（430 个官方版本和 25 个 OpenHarmony 构建版本），macOS 是 717 个（692 个和 25 个，两种架构都在），Windows x64 是 453 个，Linux ARM64 和 Windows ARM64 分别是 743 个和 490 个，它们多出来的 288 个和 37 个是源码安装。列表比这短得多，说明插件有一部分数据来源没读到，见 [troubleshooting.md](troubleshooting.md#网络)。
