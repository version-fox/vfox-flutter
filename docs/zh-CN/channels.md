# 渠道

[中文](channels.md) | [English](../channels.md)

`stable` 和 `beta` 安装该渠道当前指向的版本，也可以带架构后缀，比如 `stable-x64`（见 [arm64.md](arm64.md)）：

```bash
vfox install flutter@stable
```

2026-10-21 时，`stable` 指向 3.47.7，`beta` 指向 3.50.0-0.1.pre。

## 渠道如何解析

Flutter 的发布索引（`releases_linux.json`、`releases_macos.json` 和 `releases_windows.json`，见 [versions.md](versions.md#安装)）在 `current_release` 下写明了每个渠道指向哪个提交。插件读出这个提交，安装由它构建出的版本。如果请求带了架构后缀，或者机器上同一个提交有不止一个构建（macOS 上每个较新的版本都有 x64 和 arm64 两个压缩包），插件会取对应架构的那个构建：

| 你执行 | 安装的是 |
| --- | --- |
| `vfox install flutter@stable` | 本机架构的稳定版，名字是 `3.47.7` |
| `vfox install flutter@stable-x64` | 它的 x64 构建，名字是 `3.47.7-x64` |
| `vfox install flutter@stable-arm64` | 它的 arm64 构建（如果有的话），名字是 `3.47.7-arm64`，见 [arm64.md](arm64.md) |
| `vfox install flutter@beta` | beta 版，名字是 `3.50.0-0.1.pre` |

渠道请求比版本请求多读一次发布索引，而且这一次不会重试。镜像（见 [mirror.md](mirror.md)）提供的是它自己的那份索引，所以渠道指向哪里，以那份索引为准。2026-10-21 时 Google、CFUG 和 CERNET 的索引是一致的。

## 你会得到什么

- **安装时解析。** SDK 按渠道指向的版本命名，比如 `flutter@3.47.7`（`stable-x64` 则是 `flutter@3.47.7-x64`），安装结束时 vfox 会打印这个版本：

  ```
  $ vfox install flutter@stable
  Preinstalling flutter@3.47.7...
  ...
  Install flutter@3.47.7 success!
  Please use `vfox use flutter@3.47.7` to use it.
  ```

- **要用版本号，不要用渠道名。** 渠道名不是已安装的名字，见下文。
- **渠道不会自动跟随。** 渠道移到新版本之后，`vfox install flutter@stable` 会把新版本装在旧版本旁边，再用 `vfox use` 切过去。已经在用的 SDK 不会被改动。

## 用版本号，不要用渠道名

vfox 只认已安装的名字。渠道在插件安装的过程中就换成了具体的版本，所以安装之后 `vfox list flutter` 里没有 `stable`，所有要按已安装的名字查找的命令，用它都会失败：

- `vfox use flutter@stable` 报 `flutter@stable is not installed`；改用 `vfox use --global flutter@3.47.7`。
- `vfox uninstall flutter@stable` 同样失败；`vfox uninstall` 也要写版本号。
- `vfox exec flutter@stable -- flutter --version` 会把这个版本装上（或发现已经装了），然后打印 `failed to get runtime package for flutter@stable: open .../cache/flutter/v-stable: no such file or directory`，以退出码 1 结束，命令并没有运行。要写成 `vfox exec flutter@3.47.7 -- flutter --version`。
- `.vfox.toml` 或 `.tool-versions` 里写 `stable` 什么也选不中：`vfox current` 显示 `flutter -> N/A`，`flutter` 会来自下一个作用域。项目文件里要写版本号。

实际上，渠道代表的版本就是 `vfox search flutter` 里最新的 `(stable)` 或 `(beta)` 那一行，见 [versions.md](versions.md#搜索)。想让项目不受渠道变化影响，始终用同一个 Flutter，就用 `vfox use --project flutter@3.47.7` 固定版本，并把它写出的 `.vfox.toml` 提交进仓库。

## `latest` 不是渠道

`vfox install flutter@latest` 是 vfox 自己的简写，指的是 `vfox search flutter` 的第一行。那一行是最新的稳定版，带着架构后缀（2026-10-21 时是 `3.47.7-x64`），所以 `latest` 和 `stable` 装的是同一个 Flutter，只是名字不同（`3.47.7-x64` 和 `3.47.7`）。优先用 `stable`，见 [versions.md](versions.md#搜索)。

## `dev`

Flutter 已经废弃 `dev` 渠道，它的最后一个版本是 2022 年 4 月的 `2.13.0-0.1.pre`，所以插件不再接受它。`releases_<os>.json` 里 `current_release` 下仍然给 `dev` 写了一个提交，但插件不再看这一项，`vfox install flutter@dev` 会以下面的输出结束：

```
no installable runtime provided
failed to install flutter
```

过去发布到 `dev` 渠道的版本仍然会按各自的版本号列出，比如 `2.13.0-0.1.pre`，在 `vfox search flutter` 里它后面带着 `(dev)`。
