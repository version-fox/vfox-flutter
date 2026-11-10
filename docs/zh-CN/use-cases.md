# 使用场景

[中文](use-cases.md) | [English](../use-cases.md)

下面按你可能遇到的场景，讲这个插件用在哪些地方。每个场景都给出用插件的命令，在有助于理解的地方说明手动做同样的事要怎么做，并链接到有详细说明的那一页。命令是 2026-11-03 在 Ubuntu 26.04.1（x64）的 Bash 里，用 vfox 1.0.13 和插件 0.2.5 运行的，当时 Flutter 发布索引里的 `stable` 是 `3.47.9`，`beta` 是 `3.50.0-0.3.pre`。vfox 自己的行为（Shell 钩子、作用域、`vfox install --all`）按 1.0.13 的实际表现来写，其他版本可能不同。

## 一台新机器

手动安装 Flutter，就是下载、解压，再改一次 `~/.bashrc`，而且下载地址要根据操作系统、渠道和版本自己拼。插件用三条命令完成同样的事。

### Ubuntu 26.04.1

在 Bash 中执行：

```bash
curl --location --output /tmp/flutter_linux.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.4-stable.tar.xz
mkdir -p ~/develop/
tar -xf /tmp/flutter_linux.tar.xz -C ~/develop/
rm -rf /tmp/flutter_linux.tar.xz
echo 'export PATH="$HOME/develop/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

用插件就是：

```bash
vfox add flutter
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
```

两种做法最后 `PATH` 上都是同一个 Flutter，`flutter --version --no-version-check` 的第一行都是 `Flutter 3.47.4 • channel stable • https://github.com/flutter/flutter.git`，下载的压缩包也是同一个文件。逐步对照：

| 手动 | 用插件 |
| --- | --- |
| 根据操作系统、渠道和版本拼出压缩包的地址，再用 `curl` 下载 | `vfox install flutter@3.47.4` 在 Flutter 的发布索引里找到这个版本，索引里列有对应你的操作系统和 CPU 的压缩包 |
| 没有哪一步会拿校验和比对下载的文件 | vfox 用索引里的 SHA-256 校验，并打印 `Verifying checksum ...` |
| `mkdir -p ~/develop/` 和 `tar -xf ...` 把一个 Flutter 放在一个固定的位置 `~/develop/flutter` | 每个版本都有自己的目录 `~/.vfox/cache/flutter/v-3.47.4/flutter-3.47.4/` |
| `rm -rf /tmp/flutter_linux.tar.xz` | vfox 解压之后自己删除压缩包 |
| `echo ... >> ~/.bashrc` 和 `source ~/.bashrc` | `vfox use --global flutter@3.47.4` |

最后一行才是关键。vfox 本身需要挂到 Shell 上，只做一次，这一行和 Flutter 无关，所有交给 vfox 管理的 SDK 共用它（其他 Shell 的写法见 vfox 的[快速入门](https://vfox.dev/zh-hans/guides/quick-start.html)）：

```bash
echo 'eval "$(vfox activate bash)"' >> ~/.bashrc
source ~/.bashrc
```

此后，`~/.bashrc` 里不会再添加、修改或删除任何和 Flutter 有关的内容：装另一个版本、切换版本、卸载，都不用。在没有挂钩子的 Shell 里，`vfox use` 会直接停下：`vfox requires hook support. Please ensure vfox is properly initialized with 'vfox activate'`。钩子在每次出现提示符之前运行，所以切换之前就已经开着的终端，到下一个提示符就会采用新的选择。手动的话，每个开着的终端都得执行 `source ~/.bashrc` 或者重新打开，而且 `echo` 那一行执行第二次，`PATH` 那一行就会被再写进去一次。

在 macOS 和 Windows 上，手动的步骤是一样的，换成对应你 CPU 的 `.zip`（`flutter_macos_arm64_3.47.4-stable.zip`、`flutter_windows_3.47.4-stable.zip`），改的是 `~/.zshrc` 或者你的用户 `Path` 变量。用插件的三条命令不变，只有把 vfox 挂到 Shell 上的那一行因 Shell 而异，见 [platforms.md](platforms.md)。

## 已经手动装过 Flutter

在你用 vfox 选定版本之前，`flutter` 仍然是 `~/develop/flutter` 里的那一份。装上你在用的版本，选中它，再问一下实际运行的是哪个 `flutter`。

### Ubuntu 26.04.1

在 Bash 中执行：

```bash
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
command -v flutter
```

`command -v flutter` 打印的是 `~/.vfox/sdks/flutter/bin/flutter`，其中的主目录会展开成完整路径。vfox 把自己的目录放在 `PATH` 里旧目录的前面，不管 `PATH` 那一行在 `~/.bashrc` 里是在钩子之前还是之后，所以不用改别的，新的 Flutter 就会运行。要收拾旧的，先找到旧的那一行：

```bash
grep -n 'develop/flutter/bin' ~/.bashrc
```

在编辑器里删掉它打印出来的那一行，再打开一个新终端（你现在这个还带着旧的 `PATH`），然后删除旧的 SDK：

```bash
rm -rf ~/develop/flutter
```

Flutter 自己的设置（`~/.config/flutter`）和 pub 缓存（`~/.pub-cache`）在你的主目录里，不在 SDK 里，所以它们会原样用于新装的版本。

## 项目用不同的 Flutter 版本

一个老应用必须停在 `3.44.0`，新的用 `3.47.4`。手动的话，就是两个目录，加上每次切换都要改的 `PATH`。用插件，每个版本只装一次，由每个项目自己说明用哪一个：

```bash
vfox install flutter@3.44.0
vfox install flutter@3.47.4
cd ~/work/legacy_app
vfox use --project flutter@3.44.0
cd ~/work/new_app
vfox use --project flutter@3.47.4
```

`vfox use --project` 把选择写进项目目录里的 `.vfox.toml`（`[tools]` 下的 `flutter = "3.44.0"`），并把 SDK 链接到 `.vfox/sdks/flutter`。你在这个目录里时，`flutter` 就是项目的 Flutter，在其他任何目录里则是用 `--global` 选的那个：

```
$ cd ~/work/legacy_app
$ flutter --version --no-version-check | sed -n 1p
Flutter 3.44.0 • channel stable • https://github.com/flutter/flutter.git
$ cd ~/work/new_app
$ flutter --version --no-version-check | sed -n 1p
Flutter 3.47.4 • channel stable • https://github.com/flutter/flutter.git
```

每个版本在磁盘上都是一个完整的 SDK，见 [platforms.md](platforms.md#前提条件)。关于作用域，有三点要知道：

- **选择在 `.vfox.toml` 所在的目录里生效，子目录里不生效。** 在 `~/work/legacy_app/lib` 里，`flutter` 来自会话或全局的选择。`vfox current flutter` 会告诉你当前所在的位置用的是哪个版本。
- **钩子在提示符出现时才改 `PATH`。** 把 `cd ~/work/new_app && flutter run` 写在一行里，运行的还是你来的那个目录的 Flutter。先 `cd`，再运行 `flutter`。
- **`.vfox/` 不要提交进 git。** 项目里已有 `.gitignore` 时，vfox 会把它加进去，并打印 `Added '.vfox/' to .gitignore`。它不会新建 `.gitignore`。

## 团队统一 Flutter 版本

把 `.vfox.toml` 和 `.gitignore` 的改动提交进仓库，大家构建项目用的就是它当初所写的那个 Flutter，而不是各自机器上碰巧装着的那个。克隆项目的人在它的目录里执行：

```bash
vfox add flutter
vfox install --all
vfox use --project flutter@3.44.0
```

`vfox install --all` 会安装 `.vfox.toml` 里列出的版本，装之前会先问一下（加 `--yes` 就不问了）。它不会选中这些版本，选中是 `vfox use --project` 的事，版本号取自 `.vfox.toml`，它写出来的 `.vfox.toml` 和原来一样，所以 git 里没有新的改动可提交。`vfox add flutter` 要放在前面，因为在没有插件的机器上，`vfox install --all` 只会把插件加上，SDK 要等下一次。

## 升级与回退

新的 Flutter 装在旧的旁边，你选中它之前什么都不会变。`vfox install flutter@stable` 安装的是 stable 渠道当前指向的版本（2026-11-03 是 `3.47.9`）：

```bash
vfox install flutter@stable
vfox use --global flutter@3.47.9
```

如果新版本弄坏了什么，旧的还装着：

```bash
vfox use --global flutter@3.47.4
```

`vfox uninstall flutter@3.47.9` 会删掉你不想要的那个版本，而且只删它的目录。`flutter upgrade` 则是就地改动 SDK，vfox 看不到，这时 `vfox list flutter` 说的就不再是实际运行的那个版本了，见 [flutter-upgrade.md](flutter-upgrade.md)。所以 Flutter 打出的那个建议执行 `flutter upgrade` 的 "A new version of Flutter is available!" 提示框可以不理会：`vfox install flutter@stable` 就是升级，见 [troubleshooting.md](troubleshooting.md#看起来不对但其实正常的现象)。

## 在一个终端里试用 beta

```bash
vfox install flutter@beta
vfox use --session flutter@3.50.0-0.3.pre
```

会话级的选择只对这个终端有效。其他终端保持原来的版本，新开的终端也没有 beta。beta 一直装着，直到你执行 `vfox uninstall flutter@3.50.0-0.3.pre`。`flutter@beta` 会换成它指向的版本（2026-11-03 是 `3.50.0-0.3.pre`），`vfox use` 要写的是这个名字，见 [channels.md](channels.md#用版本号不要用渠道名)。

## 镜像

`storage.googleapis.com` 很慢或者连不上时，手动的话就要把地址里的主机换掉，比如换成 CFUG 的镜像：

```bash
curl --location --output /tmp/flutter_linux.tar.xz https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.4-stable.tar.xz
```

用插件，只要设置一次 `FLUTTER_STORAGE_BASE_URL`，之后每次安装都从那里取索引和压缩包：

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
vfox install flutter@3.47.4
```

`flutter` 工具首次使用时下载东西，读的也是这个变量，所以它要一直保持在你的 Shell 里，而不只是在安装的时候。怎样让它永久生效、其他的镜像，以及插件不管的、用于拉取包的 `PUB_HOSTED_URL`，见 [mirror.md](mirror.md)。

## 脚本、容器和 IDE

`vfox use` 需要钩子，而脚本、容器构建和 CI 步骤里没有钩子。`vfox exec` 用你指定的 Flutter 运行一条命令，有没有钩子都行：

```bash
vfox exec flutter@3.47.4 -- flutter --version --no-version-check
```

想让 IDE 跟着你的全局选择走，可以把 `~/.vfox/sdks/flutter` 设为它的 Flutter SDK 路径，切换版本时就不用再改。见 [Flutter 在哪里](troubleshooting.md#flutter-在哪里)。

## ARM64 机器和 OpenHarmony

Google 没有为 Linux ARM64 和 Windows ARM64 发布 Flutter 压缩包，所以手动的话，Flutter 来自 `flutter/flutter` 的一次 `git clone`。插件对不带后缀的名字就是这样做的：

```bash
vfox install flutter@3.47.4
```

它只提供那里能用原生 Dart SDK 运行 Flutter 工具的版本，见 [arm64.md](arm64.md)。gitcode.com 上的 OpenHarmony 分支版 Flutter 也是同样的装法（`vfox install flutter@3.41.10-ohos-1.0.0`），见 [ohos.md](ohos.md)。
