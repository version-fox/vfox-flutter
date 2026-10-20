# 变更记录

[中文](changes.md) | [English](../changes.md)

每个版本改了什么，写成用户能感受到的样子。其余的细节见 GitHub 的发布页面和下面链接的 pull request。最新的发布版是 0.2.5。`main` 领先于它时，多出来的改动列在最前面的“未发布”下，想现在就用上它们，见 [install-from-source.md](install-from-source.md)。

## 0.2.5 (2026-10-21)

- 安装官方版本不再访问 gitcode.com（[#50](https://github.com/version-fox/vfox-flutter/pull/50)）。0.2.4 每次安装都要问它，而 gitcode.com 对它的 API 限流（HTTP 429）时，一次安装或一次 `vfox search` 最多会等 6.5 分钟，什么也不打印：2026-10-21 测得 212 秒和 392 秒。`vfox search` 和 `vfox install` 的 `latest` 仍然会列出 OpenHarmony 的发布版本，但它们只尝试两次，遇到 HTTP 429 就放弃，拿不到列表时在 stderr 上打印一条警告。安装 OpenHarmony 构建版本还是和以前一样会等。见 [troubleshooting.md](troubleshooting.md#gitcodecom-被限流)。
- `3.13.3`、`3.9.0-0.1.pre` 和 `3.17.0-0.0.pre` 可以安装了（[#50](https://github.com/version-fox/vfox-flutter/pull/50)）。Flutter 重新上传了它们的文件，却把旧的校验和留在索引里，挨着新的，0.2.4 可能取到旧的，以 `checksum error` 结束。现在列表会保留一个压缩包最新的条目，它才有文件的校验和。见 [troubleshooting.md](troubleshooting.md#checksum-error)。
- 标签是 `+ohos-` 的 OpenHarmony 构建版本会被列出，也可以安装（[#50](https://github.com/version-fox/vfox-flutter/pull/50)）：`3.41.9+ohos-1.0.2`、`3.35.7+ohos-1.0.5`、`3.27.4+ohos-1.0.9` 和 `3.22.3+ohos-1.1.6`。见 [ohos.md](ohos.md#名称与发布版本)。
- 源码安装的检出会设置 `core.autocrlf=false`（[#50](https://github.com/version-fox/vfox-flutter/pull/50)）。全局 `core.autocrlf=true` 时，0.2.4 在 Linux 上（Linux ARM64 和 OpenHarmony 构建版本）会让 Flutter 的 shell 脚本带上 CRLF 换行，`flutter` 就会停在 `bin/internal/shared.sh: line 5: $'\r': command not found`。见 [arm64.md](arm64.md#限制)。
- Linux ARM64 和 Windows ARM64 只从第一个能用原生 Dart SDK 运行的版本起提供 `-arm64` 源码安装，分别是 Flutter 2.2.0 和 3.44.0-0.1.pre（[#50](https://github.com/version-fox/vfox-flutter/pull/50)）。0.2.4 也提供更老的版本，用的是 x64 的 Dart SDK：ARM64 的 Linux 机器运行不了它，Windows 靠模拟层运行它，名字却写着 arm64。这些版本的 `-x64` 压缩包仍然在列表里。见 [arm64.md](arm64.md#能原生运行的发布版本)。
- `vfox search` 把稳定版列在预发布版本之前（[#50](https://github.com/version-fox/vfox-flutter/pull/50)），所以 `vfox install flutter@latest` 装的是最新的稳定版（2026-10-21 是 `3.47.7-x64`），而不是最新的 beta（`3.50.0-0.1.pre-x64`）。见 [versions.md](versions.md#搜索)。
- 遇到插件不支持的 CPU 时，提示有了空格：`flutter does not support the arm architecture`（[#50](https://github.com/version-fox/vfox-flutter/pull/50)）。

## 0.2.4 (2026-10-17)

- `dev` 渠道没有了。Flutter 已经废弃它（最后一个版本是 2022 年 4 月的 `2.13.0-0.1.pre`），`vfox install flutter@dev` 不再能解析。`stable` 和 `beta` 的说明写在 [channels.md](channels.md) 里（[#47](https://github.com/version-fox/vfox-flutter/pull/47)）。
- 主目录带空格的 Windows 账户，比如 `C:\Users\John Doe`，在 vfox 1.0.13 或更新的版本上可以用了（[#48](https://github.com/version-fox/vfox-flutter/pull/48)）。
- 卡住的 `git fetch`（一分钟内速度低于 1 KB/s）会被放弃并重试，最多三次。它适用于 Linux ARM64 和 Windows ARM64 的源码安装，以及 OpenHarmony 构建版本（[#49](https://github.com/version-fox/vfox-flutter/pull/49)）。

## 0.2.3 (2026-10-10)

- Linux ARM64（[#23](https://github.com/version-fox/vfox-flutter/pull/23)）和 Windows ARM64（[#24](https://github.com/version-fox/vfox-flutter/pull/24)）安装官方 `flutter/flutter` 的 git 标签，因为 Google 没有为它们发布压缩包。见 [arm64.md](arm64.md)。
- 从 gitcode.com 安装 OpenHarmony 构建版本，比如 `3.41.10-ohos-1.0.0`（[#16](https://github.com/version-fox/vfox-flutter/pull/16)）。修复了在 Windows 上安装它们的问题（[#17](https://github.com/version-fox/vfox-flutter/pull/17)、[#18](https://github.com/version-fox/vfox-flutter/pull/18)），gitcode.com 回答 HTTP 429 时，会先等一会儿再试下一次（[#31](https://github.com/version-fox/vfox-flutter/pull/31)）。见 [ohos.md](ohos.md)。
- 当 `flutter upgrade` 或类似的命令把 vfox 管理的 SDK 移到了别的提交，`vfox use` 会发出警告，并给出恢复它的命令（[#27](https://github.com/version-fox/vfox-flutter/pull/27)）。见 [flutter-upgrade.md](flutter-upgrade.md)。
- 从压缩包安装之后第一次运行 `flutter`，不再重新构建 Flutter 工具（[#39](https://github.com/version-fox/vfox-flutter/pull/39)、[#37](https://github.com/version-fox/vfox-flutter/issues/37)）。
- `VFOX_FLUTTER_GITHUB_MIRROR` 为源码安装的 GitHub 克隆指定镜像（[#34](https://github.com/version-fox/vfox-flutter/pull/34)，它取代了 [#29](https://github.com/version-fox/vfox-flutter/pull/29) 的自动回退）。失败的拉取最多重试三次。见 [mirror.md](mirror.md)。
- 发布索引最多请求三次，每次间隔五秒，错误信息里会写出 HTTP 状态（[#24](https://github.com/version-fox/vfox-flutter/pull/24)）。
- `vfox add flutter` 会打印一个指向 README 的链接（[#30](https://github.com/version-fox/vfox-flutter/pull/30)）。

## 0.2.2 (2026-09-12)

- 列出每个架构的变体，比如 `3.47.4-x64` 和 `3.47.4-arm64`，这样你可以安装其中任何一个，并来回切换。不带后缀的名字仍然是本机架构，安装后的名字也不变（[#6](https://github.com/version-fox/vfox-flutter/pull/6)）。见 [arm64.md](arm64.md)。

## 0.2.1 (2026-09-12)

- `FLUTTER_STORAGE_BASE_URL` 为发布索引和压缩包指定镜像（[#8](https://github.com/version-fox/vfox-flutter/pull/8)），镜像列表也更新到了最新（[#10](https://github.com/version-fox/vfox-flutter/pull/10)）。见 [mirror.md](mirror.md)。

## 0.2.0 (2024-07-01)

- macOS 得到对应自己架构的构建，Apple 芯片或 Intel，列表也改为新版本在前（[#3](https://github.com/version-fox/vfox-flutter/pull/3)）。

## 0.1.x (2024-04-01)

- 0.1.0 是第一个发布版。它列出 Flutter 索引里适用于当前操作系统的版本，安装压缩包并验证它的 SHA-256 校验和，认得 `stable`、`beta` 和 `dev` 渠道。
- 0.1.1 只改了版本号。
