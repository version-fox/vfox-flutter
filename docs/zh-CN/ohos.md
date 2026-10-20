# OpenHarmony 构建版本

[中文](ohos.md) | [English](../ohos.md)

OpenHarmony 构建版本来自一个面向 OpenHarmony 的第三方 Flutter 分支。插件会把 gitcode.com 上 [CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter/releases) 的发布版本和官方版本一起列出来，并以源码检出的方式安装它们。

## 前提条件

需要 `git`：

1. Ubuntu 26.04.1 上执行 `sudo apt install --assume-yes git`
2. Windows 11 上执行 `winget install --id Git.Git --source winget --exact`

## 使用方法

gitcode.com 上的 [OpenHarmony 版 Flutter 发布版本](https://gitcode.com/CPF-Flutter/flutter_flutter/releases)以源码检出的方式安装：

```bash
vfox install flutter@3.41.10-ohos-1.0.0
vfox use --global flutter@3.41.10-ohos-1.0.0
```

3.41、3.35 和 3.27 这几条线上最新的版本分别是 `3.41.10-ohos-1.0.0`、`3.35.8-ohos-1.0.3` 和 `3.27.5-ohos-1.0.7`，全部版本见[名称与发布版本](#名称与发布版本)。要看当前有哪些，执行：

```bash
vfox search flutter
```

## 名称与发布版本

名称由一个版本号、`-ohos-` 或 `+ohos-`，以及这个分支自己的版本号组成：`3.41.10-ohos-1.0.0` 是这个分支 3.41.10 线上的 1.0.0 版。`-ohos-` 名称里的第一个数字是这个分支自己的标记，并不总是对应某个 Flutter 版本：Flutter 没有 3.41.10、3.35.8、3.27.5 或 3.22.4，`3.41.10-ohos-1.0.0` 背后的分支叫 `oh-3.41.9-release`。这个分支 2026-10-15 起的新标签改用官方版本的版本号，后面跟 `+ohos-`（`3.41.9+ohos-1.0.2`）。2026-10-21 时插件列出了下面这 25 个发布版本，每条线内部新的在前：

| 开头 | 发布版本（`-ohos-` 或 `+ohos-` 之后的部分） |
| --- | --- |
| 3.41.10-ohos- | `1.0.0`、`0.0.1-canary1` |
| 3.41.9+ohos- | `1.0.2` |
| 3.35.8-ohos- | `1.0.3`、`1.0.1`、`0.0.3` |
| 3.35.7+ohos- | `1.0.5` |
| 3.27.5-ohos- | `1.0.7`、`1.0.6`、`1.0.5`、`1.0.3`、`1.0.0` |
| 3.27.4+ohos- | `1.0.9` |
| 3.22.4-ohos- | `1.1.4`、`1.1.3` |
| 3.22.3+ohos- | `1.1.6` |
| 3.22.1-ohos- | `1.1.1`、`1.0.9`、`1.0.1`、`0.1.2`、`0.1.1` |
| 3.7.12-ohos- | `1.1.7`、`1.1.1`、`1.0.7`、`1.0.6` |

`vfox search flutter` 把它们排在最后，在所有官方版本之后，每个显示为 `3.41.10-ohos-1.0.0 (OpenHarmony)`，没有 Dart 版本。因为这个顺序，`vfox install flutter@latest` 永远不会选中其中一个。

插件靠标签名里有 `-ohos-` 或 `+ohos-` 来认出一个发布版本。

## 安装如何进行

1. 插件向 `https://gitcode.com/api/v5/repos/CPF-Flutter/flutter_flutter/releases` 请求发布版本列表，最多五次，再按标签名找到对应的发布版本。它的 `target_commitish` 就是要安装的提交。
2. 在 `$VFOX_HOME` 下的 `.vfox/tmp/<名称>` 里（没设置 `VFOX_HOME` 就在你的主目录下，即 `~/.vfox/tmp/3.41.10-ohos-1.0.0`）执行 `git init`，然后 `git fetch --depth 1 https://gitcode.com/CPF-Flutter/flutter_flutter.git <提交>`，最多三次，再执行 `git checkout FETCH_HEAD`。
3. 检查 `bin/internal/engine.version` 是否存在，然后把这个目录交给 vfox，由它移动到安装位置。

得到的是只含一个提交的浅克隆，3.41.10-ohos-1.0.0 是 224 MB，网速很快时安装用了 19 秒。安装会等待 gitcode.com：它的 API 回答 HTTP 429（被限流）时，插件在五次尝试之间依次等 30、60、120 和 180 秒，遇到其他错误则每次间隔十秒。

`vfox search flutter` 向同一个 API 取发布版本的列表，但不会等它：最多两次，间隔两秒，遇到 HTTP 429 就停。API 没有响应时，列表里没有 OpenHarmony 的名字，并在 stderr 上说明这一点。安装官方版本完全不会访问 gitcode.com。

## 限制

- **只能按准确的版本号安装。** OpenHarmony 版本排在官方版本之后，所以 `@latest` 不会选中其中任何一个。`stable` 和 `beta` 渠道（见 [channels.md](channels.md)）通过 Flutter 官方的发布索引解析，而那里没有 OpenHarmony 构建版本。
- **没有架构变体。** `flutter@3.41.10-ohos-1.0.0-x64` 不支持，会失败并报 `flutter 3.41.10-ohos-1.0.0 has no architecture variants`。
- **只认上面这些名字。** `flutter@3.47.7-ohos-1.0.0` 会失败并报 `flutter 3.47.7-ohos-1.0.0 is not an OpenHarmony release`。
- **`linux-arm64` 和 `windows-arm64`。** 上游只发布了 x64 的 Dart SDK，所以第一次运行 `flutter` 会在那里失败（`It appears that the downloaded file is corrupt`）。ARM64 的 e2e 只跑官方版本。
- **第一次运行 `flutter` 命令很慢。** 它要构建工具，并从华为的 OBS 下载 Dart SDK，所以需要网络。
- **不做校验和验证。** git 的历史就是完整性检查，而且这是个第三方分支，信任它之前请先审查它的源码。
- **镜像不起作用。** `FLUTTER_STORAGE_BASE_URL` 和 `VFOX_FLUTTER_GITHUB_MIRROR`（见 [mirror.md](mirror.md)）只影响官方 SDK 的下载；OpenHarmony 构建版本是从 gitcode 克隆的，所以这两个变量都会被忽略。
- **卡住的克隆会重试。** 从 gitcode 拉取时如果卡住（一分钟内速度低于 1 KB/s），会被放弃并重试，最多三次；`GIT_HTTP_LOW_SPEED_LIMIT` / `GIT_HTTP_LOW_SPEED_TIME` 可以改这个阈值。
- **gitcode.com 会对它的 API 限流。** 安装 OpenHarmony 构建版本时会等它，见上文。另见 [troubleshooting.md](troubleshooting.md#gitcodecom-被限流)。
- **换行符。** 检出时会设置 `core.autocrlf=false`，这样全局的 `core.autocrlf=true` 就不会让 Linux 上的检出带上 CRLF 换行，见 [arm64.md](arm64.md#限制)。

### 构建 OpenHarmony 应用

还需要 DevEco Studio 和 OpenHarmony SDK，vfox 不会安装它们。
