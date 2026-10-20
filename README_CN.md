# vfox-flutter

[中文](README_CN.md) | [English](README.md)

[vfox](https://vfox.dev/) 的 [Flutter](https://flutter.dev/) 插件。

它从 Google 发布的压缩包安装 Flutter SDK（Linux x64、macOS 和 Windows x64），并用 Flutter 发布索引里的 SHA-256 校验和做校验。Linux ARM64 和 Windows ARM64 没有现成的压缩包，插件改为安装官方 `flutter/flutter` 仓库的 git 标签。它还会从 gitcode.com 安装 OpenHarmony 版本的 Flutter。

## 安装

先安装 [vfox](https://github.com/version-fox/vfox)，然后执行下面的命令安装插件：

```bash
vfox add flutter
```

要让 `flutter` 出现在 `PATH` 里，需要先把 vfox 挂载到 Shell，见 vfox 的[快速入门](https://vfox.dev/zh-hans/guides/quick-start.html)。

Flutter SDK 自带 Dart SDK；如果通过本插件安装 Flutter SDK，就不需要再用 https://github.com/version-fox/vfox-dart 里的 vfox 插件单独安装 Dart SDK。

### 示例：Ubuntu 26.04.1

```bash
vfox add flutter
vfox install flutter@3.47.4
sudo apt install --assume-yes curl git unzip xz-utils zip libglu1-mesa
vfox use --global flutter@3.47.4
```

可以用下面的命令验证：

```bash
flutter --version --no-version-check
dart --version
```

`vfox search flutter` 会列出可以安装的版本，在交互式终端里还可以直接选一个并安装。

只存在于 `main`、还没进入最新发布版的行为，在下面各页里标有“未发布”。完整列表见 [docs/zh-CN/changes.md](docs/zh-CN/changes.md)，想直接用上 `main`，见 [docs/zh-CN/install-from-source.md](docs/zh-CN/install-from-source.md)。

## 版本与命名

版本就是 `vfox search flutter` 打印出的发布版本：`3.47.4`，或者 `3.50.0-0.1.pre` 这样的 beta。后面加 `-x64` 或 `-arm64`，表示要这个架构而不是本机架构；`stable` 和 `beta` 代表该渠道当前指向的版本。版本必须整串匹配，所以 `flutter@3.47` 不会选中最新的 3.47.x。`vfox use`、`vfox uninstall` 和 `vfox exec` 要写已安装的名字，也就是 `vfox list flutter` 里显示的那个。`flutter@latest` 是列表的第一行，即最新的稳定版。名字、安装后的命名和列表的顺序见 [docs/zh-CN/versions.md](docs/zh-CN/versions.md)。

## 渠道

`vfox install flutter@stable` 和 `flutter@beta` 安装该渠道当前指向的版本，并按那个版本命名（`3.47.7`），所以 `vfox use flutter@stable` 会失败：要写版本号。Flutter 已经废弃 `dev` 渠道。详见 [docs/zh-CN/channels.md](docs/zh-CN/channels.md)。

## 平台

x64 和 ARM64 上的 Linux、macOS 和 Windows。各平台从哪里安装、需要具备哪些条件（vfox 和 `git`）、插件会连接哪些地址，以及测试覆盖哪些内容，见 [docs/zh-CN/platforms.md](docs/zh-CN/platforms.md)。

## 架构选择

`flutter@3.47.4-x64` 和 `flutter@3.47.4-arm64` 安装指定架构的构建，不带后缀的名字则安装本机架构的那个。Linux ARM64 和 Windows ARM64 从 git 标签安装，只提供能用原生 Dart SDK 运行的版本。详见 [docs/zh-CN/arm64.md](docs/zh-CN/arm64.md)。

## 镜像

`FLUTTER_STORAGE_BASE_URL` 指定发布索引和压缩包的镜像，比如 CFUG 或 CERNET 的镜像；`VFOX_FLUTTER_GITHUB_MIRROR` 指定源码安装时 GitHub 克隆用的镜像。详见 [docs/zh-CN/mirror.md](docs/zh-CN/mirror.md)。

## OpenHarmony 构建版本

`vfox install flutter@3.41.10-ohos-1.0.0` 从 gitcode.com 以 git 检出的方式安装 OpenHarmony 分支版的 Flutter。这些版本排在官方版本之后，`@latest` 永远不会选中它们。详见 [docs/zh-CN/ohos.md](docs/zh-CN/ohos.md)。

## 问题排查

插件和 vfox 打印的各种提示、代理、被限流的 gitcode.com、看起来不对但其实正常的现象，以及 Flutter 的位置，见 [docs/zh-CN/troubleshooting.md](docs/zh-CN/troubleshooting.md)。

## 常见问题

### 关于 `flutter upgrade`

详见 [docs/zh-CN/flutter-upgrade.md](docs/zh-CN/flutter-upgrade.md)。

### 从源码安装

详见 [docs/zh-CN/install-from-source.md](docs/zh-CN/install-from-source.md)。

### 开发

插件的工作方式和修改方法见 [docs/zh-CN/development.md](docs/zh-CN/development.md)，容器测试见 [docs/zh-CN/e2e.md](docs/zh-CN/e2e.md)。

### 变更记录

每个版本改了什么，见 [docs/zh-CN/changes.md](docs/zh-CN/changes.md)。

## 发布这个插件

维护者在默认分支上执行 **Actions → Plugin → Run workflow**，填入不带 `v` 前缀的稳定版插件版本号即可发布。共享工作流会更新 `metadata.lua`，创建版本提交和标签，并把 ZIP 包和 manifest 发布到本仓库；不需要在本地打标签，也不需要额外的发布令牌。PR 只运行检查，PR 标题不再触发发布。

直接推送版本标签也可以发布，前提是 `PLUGIN.version` 已经与标签一致。发布失败时，重新运行失败的那个作业即可接着发布。

工作流引用的是共享的 `@v1` 发布工具，升级这个工具不会发布本插件。包的约定和首次接入的要求，见[共享工作流的文档](https://github.com/version-fox/plugin-manifest-action)。

## 致谢

- [Flutter](https://github.com/flutter/flutter)，插件安装用的发布索引和压缩包都来自它
- [CFUG 和 CERNET](docs/zh-CN/mirror.md)，插件可以使用它们提供的 Flutter 存储镜像
- [CPF-Flutter](https://gitcode.com/CPF-Flutter/flutter_flutter)，插件安装的 OpenHarmony 版 Flutter 来自它
