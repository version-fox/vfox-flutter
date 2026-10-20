# 镜像

[中文](mirror.md) | [English](../mirror.md)

默认情况下，Flutter SDK 从 `https://storage.googleapis.com` 下载。如果访问它有困难，可以设置环境变量 `FLUTTER_STORAGE_BASE_URL` 来使用镜像。

常见的镜像：

| 镜像 | 地址 |
|------|------|
| CFUG（中国 Flutter 用户组） | `https://storage.flutter-io.cn` |
| CERNET（中国教育和科研计算机网） | `https://mirrors.cernet.edu.cn/flutter` |

最新的镜像列表见 MirrorZ Help 站点：https://help.mirrors.cernet.edu.cn/flutter/ 。

## 这个变量的作用

`FLUTTER_STORAGE_BASE_URL` 是 Flutter 自己的变量，有三个地方用到它：

- **插件从它读取发布索引**：`<镜像>/flutter_infra_release/releases/releases_linux.json`（macOS 和 Windows 上是 `releases_macos.json` 和 `releases_windows.json`）。`vfox search flutter` 列出什么、渠道指向哪个版本，都由这份索引决定，见 [channels.md](channels.md)。
- **压缩包从它下载。** 插件用索引里的 `archive` 字段拼出 vfox 要下载的地址 `<镜像>/flutter_infra_release/releases/<archive>`，不用索引自己带的 `base_url`。校验和则是同一份索引里的那个。
- **`flutter` 工具自己也读它。** 工具自己发起的下载，比如源码安装的 Dart SDK（见 [arm64.md](arm64.md)）和引擎产物，都会走它。所以它要一直保持在你的 Shell 里，而不只是在执行 `vfox install` 的时候。

末尾的斜杠会被去掉，所以 `https://storage.flutter-io.cn/` 也可以用，空值等同于没设置。镜像必须保持 Google 在 `flutter_infra_release/` 下的目录结构，并且能同时提供索引和压缩包。镜像里的索引就是你能安装的版本的列表：它还没同步的版本就看不到，`stable` 指向哪里也以它那份为准。2026-10-21 时 Google、CFUG 和 CERNET 提供的索引是一样的。

使用镜像之前，可以先检查一下它能否提供你所在系统的索引：

```bash
curl --fail --silent --show-error --location --output /dev/null \
  https://storage.flutter-io.cn/flutter_infra_release/releases/releases_linux.json
```

测试套件在通过 `https://storage.flutter-io.cn` 安装之前，也会先发同样的请求。

## 哪种安装用哪个镜像

| 安装方式 | 发布索引 | 下载 |
| --- | --- | --- |
| 压缩包：Linux x64、macOS、Windows x64，以及各处的 `-x64` | `FLUTTER_STORAGE_BASE_URL` | `FLUTTER_STORAGE_BASE_URL` |
| 源码：Linux ARM64 和 Windows ARM64 | `FLUTTER_STORAGE_BASE_URL` | GitHub，用 `VFOX_FLUTTER_GITHUB_MIRROR` |
| OpenHarmony | gitcode.com，没有镜像 | gitcode.com，没有镜像 |

安装 OpenHarmony 构建版本完全不读发布索引，但 `vfox search flutter` 会读，因为它要把官方版本和它们一起列出来。`PUB_HOSTED_URL` 是 `flutter pub get` 拉取包的地址，插件不读它。如果你用 CFUG 的镜像，Flutter 的[中国用户指南](https://docs.flutter.cn/community/china)里，除了 `FLUTTER_STORAGE_BASE_URL`，还把它设成了 `https://pub.flutter-io.cn`。

## Ubuntu 26.04.1

在 Bash 中：

1. 用下面的命令可以让设置在当前 Shell 里临时生效。

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

2. 要让环境变量一直生效，可以这样做：

```bash
sudo tee /etc/profile.d/myenvvars.sh <<EOF
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
EOF

source /etc/profile.d/myenvvars.sh
```

`/etc/profile.d` 里的文件由登录 Shell 读取，所以其他终端要重新登录之后才会生效。

## macOS

在 zsh 中，把这一行加进 `~/.zshrc`，再打开一个新终端：

```bash
echo 'export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn' >> ~/.zshrc
```

## Windows 11

在 PowerShell 7 中：

1. 用下面的命令可以让设置在当前 Shell 里临时生效。

```powershell
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

2. 要让环境变量一直生效，可以这样做：

```powershell
[Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'Machine')
```

`Machine` 作用域需要以管理员身份启动的 PowerShell，对之后启动的程序生效。改用 `'User'` 则只对你的账户生效。

## 源码安装用的 GitHub 镜像

在 Linux ARM64 和 Windows ARM64 上，插件是从 git 源码而不是预编译的压缩包安装 Flutter 的。如果访问 `https://github.com` 有困难，可以设置环境变量 `VFOX_FLUTTER_GITHUB_MIRROR` 来改用镜像。它的值是一个 URL 前缀，会加在 GitHub 的地址前面。

常见的镜像：

| 镜像 | 值 |
|------|----|
| gh-proxy | `https://gh-proxy.org/` |

在 Bash 中：

1. 用下面的命令可以让设置在当前 Shell 里临时生效。

```bash
export VFOX_FLUTTER_GITHUB_MIRROR=https://gh-proxy.org/
```

2. 要让环境变量一直生效，可以这样做：

```bash
sudo tee /etc/profile.d/myenvvars.sh <<EOF
export VFOX_FLUTTER_GITHUB_MIRROR="https://gh-proxy.org/"
EOF

source /etc/profile.d/myenvvars.sh
```

在 PowerShell 7 中：

1. 用下面的命令可以让设置在当前 Shell 里临时生效。

```powershell
$env:VFOX_FLUTTER_GITHUB_MIRROR = "https://gh-proxy.org/"
```

2. 要让环境变量一直生效，可以这样做：

```powershell
[Environment]::SetEnvironmentVariable('VFOX_FLUTTER_GITHUB_MIRROR', 'https://gh-proxy.org/', 'Machine')
```

这个镜像只会改写以 `https://github.com/` 开头的 URL，所以上面的 `FLUTTER_STORAGE_BASE_URL` 不受影响。

值末尾没有斜杠的话，插件会替你补上，安装时会打印它克隆用的地址：

```
Using GitHub mirror https://gh-proxy.org/https://github.com/flutter/flutter.git
```

只有对 `flutter/flutter` 的克隆会走它。这个镜像必须是 gh-proxy 这样的服务：前缀后面接完整的 GitHub 地址就能用。镜像不响应时，安装会在三次尝试之后以 `failed to fetch tag 3.47.4 from <地址>` 失败，见 [troubleshooting.md](troubleshooting.md#源码安装linux-arm64-和-windows-arm64)。

## 代理

代理不是镜像。vfox 自己的代理设置对插件的请求和压缩包的下载都有效，`git` 读的是它自己的设置（`HTTPS_PROXY`、`http.proxy`），见 [troubleshooting.md](troubleshooting.md#网络)。
