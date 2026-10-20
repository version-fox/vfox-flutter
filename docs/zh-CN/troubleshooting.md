# 问题排查

[中文](troubleshooting.md) | [English](../troubleshooting.md)

## 提示信息

vfox 自己打印的提示，是 vfox 1.0.12 和 1.0.13 的原文；其他版本的措辞可能不同。

### `no installable runtime provided`

```
$ vfox install flutter@dev
no installable runtime provided
failed to install flutter
```

插件对你输入的名字什么也没找到。常见的原因：

- 这个名字不是一个发布版本。`flutter@3.47` 和 `flutter@3` 不会补全成最新的 3.47.x 或 3.x，名字也区分大小写（`flutter@Stable`）。到 `vfox search flutter` 里查一下，见 [versions.md](versions.md)。
- `dev`：Flutter 已经废弃这个渠道，见 [channels.md](channels.md#dev)。
- 架构后缀在这台机器上不存在：Linux x64 和 Windows x64 上的 `-arm64`，没有架构元数据的版本带任何后缀（`1.22.6-x64`），或者 Apple 芯片上只有 x64 构建的老版本不带后缀（`flutter@2.10.5` 要写成 `flutter@2.10.5-x64`）。见 [arm64.md](arm64.md)。
- 未发布：比第一个能用原生 Dart SDK 运行的版本更老的版本，在 Linux ARM64（`flutter@1.20.0`）或 Windows ARM64（`flutter@3.43.0-0.3.pre`）上。0.2.4 会用 x64 的 Dart SDK 装上它们，见 [arm64.md](arm64.md#能原生运行的发布版本)。写成 `-x64` 的名字装的是压缩包。
- 带 `+ohos-` 的 OpenHarmony 名字（`3.41.9+ohos-1.0.2`），在 0.2.4 上，它只认 `-ohos-` 的名字。未发布：两种都认，见 [ohos.md](ohos.md#名称与发布版本)。

### `flutter@stable is not installed`

`vfox use` 和 `vfox uninstall` 只认已安装的名字，而渠道在安装时就换成了具体的版本。`vfox list flutter` 能看到这些名字，见 [channels.md](channels.md#用版本号不要用渠道名)。`vfox exec flutter@stable` 因为同样的原因，会以 `failed to get runtime package for flutter@stable: open .../cache/flutter/v-stable: no such file or directory` 结束。

### `flutter@3.47.4 is already installed`

这个名字已经安装了。vfox 不会再下载，也不会重新写 `.vfox-manifest`，见 [flutter-upgrade.md](flutter-upgrade.md#关闭检查)。

### `get version failed: ... (status ...)`

```
plugin [PreInstall] method error: ~/.vfox/plugin/flutter/hooks/available.lua:35: get version failed: Get "<索引地址>": <错误> (status nil)
stack traceback:
	...
failed to install flutter
```

插件没能读到 Flutter 的发布索引，它试了三次，每次间隔五秒，所以安装在开始十秒之后失败。`get version failed:` 后面是请求的错误，再后面括号里是 HTTP 状态：

- `(status nil)` 表示没有收到 HTTP 响应：DNS、连接、TLS 或代理的问题。连接被拒绝时是 `dial tcp 127.0.0.1:1: connect: connection refused`，代理没有响应时是 `proxyconnect tcp: dial tcp 127.0.0.1:9: connect: connection refused`。
- `get version failed: nil (status 404)`，或者别的数字，表示服务器应答了并拒绝。用镜像时出现 404，多半是地址写错了：插件请求的是 `<镜像>/flutter_infra_release/releases/releases_linux.json`（`releases_macos.json`、`releases_windows.json`）。

见[网络](#网络)和 [mirror.md](mirror.md)。渠道（`flutter@stable`）会在此之前先读一次索引，而且不重试，这时提示里写的是 `hooks/pre_install.lua`。

### `checksum error`

```
Verifying checksum c53c8aeff17d13c4c0b47bff2c54a293e48286e03dd089f37d561737e41a8c2c...
Checksum error, file: ~/.vfox/cache/flutter/flutter_linux_3.13.3-stable.tar.xz
checksum error
failed to install flutter
```

vfox 下载了压缩包，它的 SHA-256 和 Flutter 发布索引里的不一样。用镜像的话，要检查镜像提供的文件是否与它提供的索引一致。不用镜像时，这曾经是索引数据本身的问题：它把 `3.13.3`、`3.9.0-0.1.pre` 和 `3.17.0-0.0.pre` 各列了两三次，同一个文件，每条的校验和都不同。Flutter 重新上传了文件，却把旧的条目留着了。最新那条的校验和才是对的（在 Linux 上下载了这三个压缩包验证过）。

插件现在只列这种文件最新的那一条，所以这三个版本都能装。未发布：0.2.4 把所有条目都列出来，装排在最前面的那条，条目相同时顺序是任意的，还取决于列表的其余部分，比如其中有多少个 OpenHarmony 版本。2026-10-21 时，它在 Linux x64 上三个全都取了旧条目，在 macOS 和 Windows 上也有一部分，安装就会像上面这样结束。请装它旁边的版本（用 `3.13.2` 或 `3.13.4` 代替 `3.13.3`），或者更新插件。没有跳过校验的开关。

### `Warning: flutter SDK at ... has drifted from the version vfox installed.`

`flutter upgrade`、`flutter channel` 或某条 `git` 命令移动了 SDK。`vfox use` 仍然会选中它。见 [flutter-upgrade.md](flutter-upgrade.md)。

### `flutter does not support the 386 architecture`

插件只能在 x64 和 ARM64 上运行。vfox 会把它自己二进制的 CPU（`386`、`arm`、`riscv64`、`loong64` 等）告诉插件，提示里会写出它，比如 `flutter does not support the arm architecture`。`vfox search` 和官方版本的安装都会被它拦住。见 [platforms.md](platforms.md)。未发布：0.2.4 打印的内容一样，只是没有空格，是 `flutter does not support386architecture`。

### 源码安装：Linux ARM64 和 Windows ARM64

这些提示来自插件，会指出是哪一步失败了，见 [arm64.md](arm64.md#源码安装如何进行)。

| 提示 | 含义 |
| --- | --- |
| `cannot resolve the vfox home directory` | `VFOX_HOME`、`HOME` 和 `USERPROFILE` 都没有设置，插件不知道该在哪里建 `.vfox/tmp/<名称>` |
| `failed to initialize git in <dir> (is git installed?)` | `git init` 失败了：没有 `git`，或者目录不可写 |
| `failed to fetch tag 3.47.4 from https://github.com/flutter/flutter.git` | 三次拉取全都失败了。`git` 自己的错误打印在这条提示的上面。检查 GitHub 能否访问，或者设置 `VFOX_FLUTTER_GITHUB_MIRROR`，见 [mirror.md](mirror.md#源码安装用的-github-镜像) |
| `failed to check out 3.47.4 in <dir>` | `git checkout FETCH_HEAD` 失败了 |
| `the checkout at 3.47.4 has no engine version pin` | 检出里没有 `bin/internal/engine.version`，所以它不是 Flutter SDK |
| `Using GitHub mirror https://gh-proxy.org/https://github.com/flutter/flutter.git` | 不是错误：正在使用 `VFOX_FLUTTER_GITHUB_MIRROR` |

安装失败会在 `$VFOX_HOME` 下（或者你的主目录下）留下 `.vfox/tmp/<名称>`。把它删掉就行，下次安装同名版本时它本来也会被删掉。

拉取时如果一分钟内速度低于 1 KB/s，会被放弃并记为一次失败的尝试，卡住的连接最后就是这样变成 `failed to fetch tag` 的。

### OpenHarmony 构建版本

| 提示 | 含义 |
| --- | --- |
| `OpenHarmony releases are unavailable from https://gitcode.com/api/v5/...: HTTP 429` | 安装 OpenHarmony 构建版本时：五次读取发布版本列表都失败了。冒号后面是最后一次的错误，这里是 gitcode.com 的限流，见[下文](#gitcodecom-被限流)。列出版本时永远不会打印这条，它会打印下面那条警告，然后在没有 OpenHarmony 版本的情况下继续 |
| `Warning: the OpenHarmony releases could not be read from gitcode.com (<error>), so only the official releases are listed.` | 两次尝试都没拿到列表时，由 `vfox search` 和 `vfox install` 的 `latest` 打印到 stderr。官方版本照常列出，OpenHarmony 构建版本仍然可以按名字安装。未发布：0.2.4 什么都不打印，而且先要等最多 6.5 分钟 |
| `flutter 3.47.7-ohos-1.0.0 is not an OpenHarmony release` | 名字里有 `-ohos-`，但 gitcode.com 上没有叫这个名字的发布版本 |
| `flutter 3.41.10-ohos-1.0.0 has no architecture variants` | 名字后面带了 `-x64` 或 `-arm64` |
| `failed to fetch <commit> from https://gitcode.com/CPF-Flutter/flutter_flutter.git` | 三次拉取全都失败了 |

见 [ohos.md](ohos.md)。

### `bin/internal/shared.sh: line 5: $'\r': command not found`

在 Linux 上做源码安装（Linux ARM64，或者 OpenHarmony 构建版本）后，第一次运行 `flutter` 就这样失败，说明检出的是 CRLF 换行，原因是你的 git 配置里有 `core.autocrlf=true`。插件现在会在检出里设置 `core.autocrlf=false`。未发布：0.2.4 用的是你的设置，请执行 `git config --global core.autocrlf input`，卸载这个版本再重新安装，见 [arm64.md](arm64.md#限制)。

### `Building flutter tool...` 和 `It appears that the downloaded file is corrupt`

源码安装后的第一次 `flutter` 运行会构建 Flutter 工具并下载 Dart SDK，所以很慢，而且需要网络。从压缩包安装的则不会在第一次运行时构建工具：为此插件会在解压之后改写 `packages/flutter_tools/pubspec.lock`，见 [development.md](development.md#容易踩坑的约定)。

`It appears that the downloaded file is corrupt; please try again.` 是 Flutter 工具在下载来的 Dart SDK 不是有效的 zip 文件时说的，下载的文件不存在（HTTP 404）就是这种情况。OpenHarmony 构建版本在 ARM64 上会这样。

## 网络

插件会访问 `storage.googleapis.com`（或你的镜像）、`gitcode.com`，源码安装还会访问 `github.com`，见 [platforms.md](platforms.md#插件会连接的地址)。失败的请求会重试：

| 请求 | 次数 | 每次之间的等待 |
| --- | --- | --- |
| 发布索引，列出或安装一个版本时 | 3 | 5 秒 |
| 发布索引，渠道在此之前的那一次 | 1 | 不等待 |
| gitcode.com 上的 OpenHarmony 发布版本，用于安装 OpenHarmony 构建版本 | 5 | 10 秒，但遇到 HTTP 429 之后是 30、60、120 和 180 秒 |
| gitcode.com 上的 OpenHarmony 发布版本，用于列出版本 | 2 | 2 秒。遇到 HTTP 429 就停止尝试 |
| 源码安装或 OpenHarmony 构建版本的 `git fetch` | 3 | 不等待。一分钟内速度低于 1 KB/s 就算失败 |

vfox 自己的代理设置对插件的请求和压缩包的下载都有效：

```bash
vfox config proxy.enable true
vfox config proxy.url http://127.0.0.1:7890
```

`proxy.enable` 为 `false` 时，通常的 `HTTP_PROXY`、`HTTPS_PROXY` 和 `NO_PROXY` 环境变量依然有效。源码安装和 OpenHarmony 构建版本用的 `git` 不读 vfox 的设置，它读的是自己的：`HTTPS_PROXY` 或 `git config --global http.proxy`。

### gitcode.com 被限流

插件在两种情况下会向 gitcode.com 要 OpenHarmony 的发布版本。安装 OpenHarmony 构建版本需要它们，而且会等。`vfox search flutter`（vfox 会把结果缓存 12 小时，所以只有第一次会问）和 `vfox install` 的 `latest` 会列出它们，而且不会等。安装官方版本完全不会访问 gitcode.com。

gitcode.com 限制匿名客户端的请求次数。超出限制时它回答 HTTP 429：

```
{"error_code":429,"error_code_name":"UN_KNOW","error_message":"429 The number of times the user invokes this API is too large. Threshold: 10W times per user per hour. Limited account:p_repoRobot.", ...}
```

这是 gitcode.com 对未登录请求的限制，不是你自己的限额：提示里点出了这次请求算在哪个账户头上，是 `p_repoRobot`。插件对它的处理是：

- 列出版本时尝试两次，间隔两秒，遇到 HTTP 429 就立刻停止。拿不到列表时，它在 stderr 上打印一行，然后用官方版本继续：

  ```
  Warning: the OpenHarmony releases could not be read from gitcode.com (HTTP 429), so only the official releases are listed.
  ```

  gitcode.com 无法访问时同样只花这两次尝试，所以连接立刻失败的话大约 2 秒（经过一个拒绝连接的代理测得 2.1 秒）。之后 `vfox search flutter` 会在没有 OpenHarmony 名字的情况下缓存 12 小时，`vfox config cache.availableHookDuration 0` 可以关掉缓存。
- 安装 OpenHarmony 构建版本最多尝试五次，遇到 429 后依次等 30、60、120 和 180 秒，所以它可能等 6.5 分钟而且什么都不打印。

未发布：0.2.4 对每个列出版本的命令，以及每次安装（包括官方版本），都要这样等。2026-10-21 gitcode.com 回答 429 的时候测得：

| 命令 | 耗时 | 结果 |
| --- | --- | --- |
| `vfox search flutter` | 392 秒 | 434 个官方版本，没有 OpenHarmony 版本，退出码 0 |
| `vfox install flutter@3.47.4` | 212 秒 | 装上了。第四次尝试通过了 |

几分钟后同一个 API 一秒就能回答。没有 429 时，一次失败的请求每次重试花 10 秒，一共 40 秒。

## 看起来不对但其实正常的现象

- **`vfox install flutter@latest` 装出来的是 `3.47.7-x64`，不是 `3.47.7`。** `latest` 是 `vfox search flutter` 的第一行，也就是最新的稳定版，而且它带着架构后缀，所以你再装一次 `stable` 的话，同一个 Flutter 会装两份，见 [versions.md](versions.md#搜索)。未发布：0.2.4 装的是最新的 beta。
- **一个版本在 `vfox search flutter` 里出现了不止一次。** Flutter 的索引里它在不止一个渠道里，见 [versions.md](versions.md#搜索)。
- **未发布：`vfox search flutter` 或 `vfox install` 等了好几分钟，什么也没打印。** 0.2.4 在 gitcode.com 限制它的 API 时会等，见 [gitcode.com 被限流](#gitcodecom-被限流)。命令自己会结束。
- **你装过的版本在 `(installed)` 标记里没有。** 标记跟的是列表里打印的名字，比如 `3.47.4-x64`，而不是你装的不带后缀的名字。以 `vfox list flutter` 为准。
- **预期的版本在 `vfox search` 里没有。** vfox 会把结果缓存 12 小时。`vfox config cache.availableHookDuration 0` 可以关掉缓存。也可能是 Flutter 的索引里还没有它，或者你的镜像那份里还没有。
- **`3.47.4` 和 `3.47.4-x64` 是两份安装。** 在 x64 机器上它们是同一个 Flutter，见 [versions.md](versions.md#已安装的名称)。
- **卸载一个版本后，全局版本被换掉了。** 卸载正在使用的版本时，vfox 会选 `vfox list flutter` 里剩下的第一项，那可能是个 beta。
- **`flutter` 运行的不是 `vfox use` 选的那个 Flutter。** `PATH` 里更靠前的另一个 Flutter 会胜出，比如手动装在 `~/develop/flutter` 的，或者包管理器装的。`command -v flutter` 能看到实际运行的是哪一个，它的路径应当以 `~/.vfox/sdks/flutter/bin` 开头，在项目里则是 `.vfox/sdks/flutter/bin`。
- **Flutter 说“A new version of Flutter is available!”并建议执行 `flutter upgrade`。** 别理它：`flutter upgrade` 会在 vfox 的背后改动 SDK，见 [flutter-upgrade.md](flutter-upgrade.md)。`vfox install flutter@stable` 才是升级。`flutter --no-version-check` 可以不显示这条提示。
- **`FLUTTER_ROOT` 没有设置。** 插件只设置 `PATH`。`flutter` 脚本会自己找到它所在的目录。
- **没有装 Dart 插件，`dart` 却在。** Flutter SDK 包含 Dart SDK，`dart` 就在它的 `bin` 里。不需要再另外添加 [vfox-dart](https://github.com/version-fox/vfox-dart) 插件。
- **`.vfox-manifest` 在 SDK 的 git 里是未跟踪的。** 这是插件写的，见 [flutter-upgrade.md](flutter-upgrade.md)。
- **在中国，`flutter pub get` 很慢或者失败。** 包是从 `PUB_HOSTED_URL` 拉取的，插件不会去动它，见 [mirror.md](mirror.md#哪种安装用哪个镜像)。
- **第一次执行 `flutter` 命令会下载很多东西。** Flutter 工具在你第一次为某个平台构建时才拉取所需的内容，而且它为此读取 `FLUTTER_STORAGE_BASE_URL`，所以要一直保持镜像变量处于设置状态，见 [mirror.md](mirror.md#这个变量的作用)。

## Flutter 在哪里

每份安装都是 vfox 主目录里自己的一个目录，默认是 `~/.vfox`，设置了 `VFOX_HOME` 则是它（`storage.sdkPath` 可以把 SDK 挪到别处，见 vfox 的[配置](https://vfox.dev/zh-hans/guides/configuration.html)）。`vfox info flutter@3.47.4` 打印的是 SDK 上一层的目录，SDK 是它里面的 `flutter-3.47.4` 目录：

```
$ vfox info flutter@3.47.4
/home/user/.vfox/cache/flutter/v-3.47.4
$ ls /home/user/.vfox/cache/flutter/v-3.47.4
flutter-3.47.4
```

`vfox use` 还会为你选中的 SDK 建一个链接，不管它指向哪个版本，链接的路径都是同一个：

| 作用域 | 链接 |
| --- | --- |
| `--global` | `~/.vfox/sdks/flutter`（Windows 上是 `%USERPROFILE%\.vfox\sdks\flutter`） |
| `--project` | 项目目录里的 `.vfox/sdks/flutter` |
| `--session` | `~/.vfox/tmp` 下某个目录里的 `flutter` |

`PATH` 里放的是这个链接的 `bin` 目录，所以 `flutter` 和 `dart` 都来自它。想跟随你的全局选择的 IDE 或构建工具，可以把这个链接当作 Flutter SDK 路径（Android Studio 的 *Flutter SDK path*，VS Code 的 `dart.flutterSdkPath` 设置），这样切换版本时它们不用再改。要固定某个版本，就用 `vfox info` 打印的目录和它里面的 `flutter-<版本>` 目录。没有 Shell 钩子的地方，可以用 `vfox exec flutter@3.47.4 -- <命令>` 用那个 Flutter 运行命令，见 [versions.md](versions.md#使用)。

## 报告问题

请到 [version-fox/vfox-flutter](https://github.com/version-fox/vfox-flutter/issues) 提 issue，附上 `vfox --version` 和 `vfox info flutter` 的输出、操作系统和 CPU、你执行的命令，以及它打印的全部内容。`vfox --debug <命令>` 会打印更多信息。Flutter 本身的问题应当提给 [flutter/flutter](https://github.com/flutter/flutter/issues)，OpenHarmony 分支的问题提给 [CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter)。
