# 开发

[中文](development.md) | [English](../development.md)

## 目录布局

```
metadata.lua              插件名、版本、最老的 vfox，以及 `vfox add` 打印的提示
hooks/available.lua       vfox search：所有名字的列表
hooks/pre_install.lua     vfox install：把名字解析成一个包；还有 PostInstall
hooks/pre_use.lua         vfox use：SDK 漂移时给出警告
hooks/env_keys.lua        PATH
lib/util.lua              镜像、平台、版本名及其顺序
lib/git.lua               git 命令、GitHub 镜像、工作目录
lib/source.lua            Linux ARM64 和 Windows ARM64 的源码安装
lib/ohos.lua              OpenHarmony 发布版本和检出
lib/manifest.lua          .vfox-manifest 和 pubspec.lock 的修正
tests/hooks_test.lua      离线的 hook 测试
tests/e2e/                容器测试，见 e2e.md
Injection.lua             vfox 注入内容的类型提示，从不加载
.luarc.json, stylua.toml  Lua 语言服务器和格式化工具的设置（Lua 5.1，120 列，4 个空格）
.devcontainer/            Linux 开发容器，见 e2e.md
.github/workflows/        lint、许可证头、hook 测试、e2e 和发布工作流
```

vfox 加载 `metadata.lua`，在命令需要时调用 hook，并把 `PLUGIN` 和 `RUNTIME`（`osType`、`archType`、`version`）放进作用域。`osType` 和 `archType` 是 vfox 二进制的 Go `GOOS` 和 `GOARCH`。这些 hook 运行在 gopher-lua 里，这是一个用 Go 写的 Lua 5.1 解释器，带有 vfox 的 `http` 和 `json` 模块。`lib` 里的文件用 `require` 加载，`lib/util.lua` 定义的是全局变量。

## 一条命令会运行什么

| 你执行 | 用到的 hook |
| --- | --- |
| `vfox search flutter` | `Available` |
| `vfox install flutter@3.47.4` | `PreInstall` 返回包，并自己调用 `Available` 来找它。vfox 下载、验证并解压，然后调用 `PostInstall` |
| `vfox use flutter@3.47.4` | `PreUse` 检查 SDK 并返回名字。`EnvKeys` 提供 `PATH` |
| `vfox uninstall flutter@3.47.4` | 没有，名字必须准确 |

## 容易踩坑的约定

- `Available` 为每个名字返回一个表，里面有 `version`、`url`、`sha256`、`key`、`note` 和 `addition`。`key` 是这个版本的 git 提交，渠道就是靠它找到自己的版本：索引里的 `current_release.stable` 是一个提交，`PreInstall` 取 `key` 等于这个提交的条目。`note` 是渠道，显示在圆括号里。`addition` 是 Dart 版本，显示在方括号里。`source = true` 是插件自己给 `-arm64` 源码安装做的标记。
- `PreInstall` 返回 `version`、`url` 和 `sha256`。`version` 会成为安装的名字。除非请求带了架构后缀，名字里就不带后缀（`3.47.4` 还是 `3.47.4`，`3.47.4-x64` 还是 `3.47.4-x64`），渠道则换成它代表的版本。源码安装返回的 `url` 是本地目录的路径，没有校验和，由 vfox 把这个目录移动到位。
- `PreInstall` 调用的是 `self:Available({ officialOnly = true })`，所以用不到 vfox 对列表的 12 小时缓存。每次安装都要读索引。`officialOnly` 会略去 OpenHarmony 发布版本：官方版本的安装用不着它们，而且它们来自的 API 被 gitcode.com 限流。vfox 用它自己的上下文调用 `Available`（`vfox search`，以及 `vfox install` 的 `latest`），那样的列表里有它们。未发布：0.2.4 每次安装都会去问 gitcode.com。
- `PreInstall` 对解析不了的名字返回 `nil`，vfox 会把它报告成 `no installable runtime provided`。失败时它会抛出错误：`error()` 的内容会出现在 `plugin [PreInstall] method error:` 那一行里。
- 索引里有些版本不止列了一次。`hooks/available.lua` 里的 `newestPublications` 对一个版本的每个压缩包只保留最新（`release_date`）的那条，因为重新上传过的文件，只有最新那条的校验和才是对的（见 [troubleshooting.md](troubleshooting.md#checksum-error)）。不同的版本绝不会合并，在两个渠道里的版本各有一个压缩包，两条都保留。`table.sort` 不是稳定排序，所以比较函数必须能区分任意两个条目，否则相等的条目出来的顺序取决于整个输入，而 `PreInstall` 取第一个匹配的。为此比较函数最后还比较版本和渠道。
- `PostInstall` 读取 `ctx.sdkInfo[PLUGIN.name]`。清单和 `pubspec.lock` 的修正都在 `pcall` 里运行，所以那里的失败永远不会让安装失败。
- vfox 用 Go 的 `archive/tar` 解压 `.tar.xz`，它给文件打上的是解压时的时间，而不是压缩包里存的时间。官方的 `tar -xf` 流程会保留那些时间，于是 `packages/flutter_tools/pubspec.lock` 比 `pubspec.yaml` 新。vfox 安装之后，两者共用解压的时间，谁最后写入谁就显得更新，所以 `bin/internal/shared.sh` 可能发现 `pubspec.yaml` 比 `pubspec.lock` 新，在第一次运行时重新构建工具（`Building flutter tool...`）。`manifest.touchPubspecLock` 在所有平台上重写 `pubspec.lock`，把顺序恢复过来（[#37](https://github.com/version-fox/vfox-flutter/issues/37)）。源码安装按设计就要在第一次运行时构建工具。
- Windows 上的命令行，在 vfox 1.0.13 及更新的版本里原样交给 `cmd.exe`（[vfox#712](https://github.com/version-fox/vfox/pull/712)），更老的版本会再加一层引号。`lib/git.lua` 和 `lib/manifest.lua` 里的 `quote` 只给含有空白字符的路径加双引号，其他路径保持原样，这样带空格的路径在 1.0.13 上可用，不带空格的路径在更老的版本上也依然可用。
- `os.execute` 报告成功的方式，视所用的 Lua 而定，可能是 `0`，也可能是 `true`，`lib/git.lua` 里的 `exec` 两者都接受。插件读取 `git` 的输出靠的是 `io.popen`；没有输出或失败的命令读出来是 `nil`，所以 `lib/manifest.lua` 里缺少 `git` 时不会有任何察觉。
- `lib/git.lua` 的工作目录依次取自 `VFOX_HOME`、`HOME`、`USERPROFILE`，再加上 `.vfox/tmp/<名称>`。设置了 `VFOX_HOME` 时就是 `$VFOX_HOME/.vfox/tmp/<名称>`，比 vfox 主目录低一层 `.vfox`。安装失败时这个目录不会被删除。
- `git` 用的是你的配置，只有 `git.init` 写进检出里的两项设置例外：`core.longpaths=true`，以及 `core.autocrlf=false`，因为全局的 `true` 会让 Flutter 的 shell 脚本带上 CRLF（见 [arm64.md](arm64.md#限制)）。在 Windows 上 `false` 写出的 CRLF 文件和 `true` 一样，因为那里的 `core.eol` 是 native。这是 git 本身的工作方式，我们在 Linux 上用 `core.eol=crlf` 和 Flutter 的 `.gitattributes`（第一条是 `* text=auto`）检查过：两种设置写出的文件同样是 CRLF，`bin/flutter` 则保持 LF。Windows ARM64 的容器测试装的就是这样的检出。拉取时会加上 `http.lowSpeedLimit=1000` 和 `http.lowSpeedTime=60`，`GIT_HTTP_LOW_SPEED_LIMIT` 和 `GIT_HTTP_LOW_SPEED_TIME` 可以覆盖它们。
- `lib/ohos.lua` 等 gitcode.com 有两种方式。安装构建版本需要发布版本列表，所以尝试五次：间隔 10 秒，遇到 HTTP 429 之后是 30、60、120 和 180 秒。列出它们只是给 `vfox search` 帮个忙，所以 `ohos.list()` 只尝试两次，间隔 2 秒，遇到 HTTP 429 就停，并返回 `nil` 和原因。然后 `Available` 往 stderr 写一行警告，再列出官方版本。
- 标签名里含有 `-ohos-` 或 `+ohos-`，就是一个 OpenHarmony 发布版本（`ohos.isOhosVersion`）。
- `source.list` 只对不早于 `OLDEST_NATIVE` 的版本提供 `-arm64` 源码安装，那是 Flutter 工具在这台机器上第一个用原生 Dart SDK 运行的版本，见[刷新 Dart SDK 表](#刷新-dart-sdk-表)。
- `EnvKeys` 只设置 `PATH`，不设置 `FLUTTER_ROOT`。
- Lua 没有 sleep，所以 `lib/util.lua` 里的 `sleep` 是 `os.execute("sleep N")`，Windows 上是 `timeout /t N`。`hooks/available.lua` 和 `lib/ohos.lua` 里的重试靠它来等待。

## 名称与排序

`lib/util.lua` 里的 `splitVersionAndArch` 把 `3.47.4-x64` 拆成 `3.47.4` 和 `x64`，只有 `x64` 和 `arm64` 算后缀：`3.50.0-0.1.pre` 就没有后缀。`compare_versions` 忽略后缀，逐个比较版本里的数字。数字少的版本，排在在相同数字后面还有数字的版本之前，所以 `3.47.0` 在 `3.47.0-0.4.pre` 之前。

`Available` 按下面的规则依次排序：

1. OpenHarmony 的名字排在所有其他名字之后（`ohos.isOhosVersion`）。
2. 本机架构，以及没有后缀的名字，排在另一个架构之前。
3. stable 渠道的条目（`note == "stable"`）排在其他条目之前，这样第一行 `@latest` 就是最新的稳定版，而不是数字更大的 beta。未发布：0.2.4 没有这条规则。
4. `compare_versions`，新的在前。
5. 本机架构排在另一个之前，然后是普通的字符串顺序。
6. 渠道（`beta` 在 `dev` 之前），用于同一个名字在两个渠道里的情况。

规则 2 和 3 让 `@latest` 保持在本机架构和稳定版上。单元测试检查了这两点。

## 解析一个名称

`PreInstall` 把请求拆成名字和架构（`requestedArch`），然后：

1. OpenHarmony 的名字交给 `ohos.checkout`，它不接受后缀。
2. `beta` 和 `stable` 从索引读出 `current_release`，把它的提交作为 `channelKey`。索引里没有写明的渠道，查找以 `nil` 结束。`dev` 不再是渠道，所以它被当作版本名查找，哪里也找不到。
3. 它遍历 `Available`，取第一个提交等于 `channelKey`、或者名字等于请求，并且架构是所请求的（或者本机的）那个条目。没有架构元数据的条目，对不带后缀的请求会被留作 `legacy`，在没有别的匹配时返回。
4. 源码条目交给 `source.checkout`，其他的返回 `url` 和 `sha256`。

## 测试

hook 测试在 `gopher-lua` 下离线运行，它是 vfox 内嵌的 Lua 解释器：

```bash
go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/hooks_test.lua
```

在仓库根目录运行。测试替换了 `http`、`json` 和 `os.getenv`，并在一张表里放了一份小索引：共用一个提交的两种架构、一个 beta、一个 dev 版本，以及一个没有架构元数据的版本。它检查：

- 每个变体都被列出，本机架构在前；
- 明确的后缀选中匹配的压缩包，不带后缀的名字保持本机架构；
- 另一个架构的版本更新时，`@latest` 也保持在本机架构上；
- 两个架构共用一个提交时，渠道依然选本机架构，`dev` 解析不到任何东西；
- 预发布版本的名字保持原样，后缀不改变顺序；
- 镜像同时提供索引和每个压缩包；
- 没有架构元数据的版本仍然可以安装，而且不会凭空多出变体；
- 缺少的架构绝不会退回到不兼容的压缩包；
- 拉取在传输卡住时放弃并重试；
- 安装官方版本永远不会访问 gitcode.com，而列出版本会访问一次；
- gitcode.com 限流时，列出版本不用等，只给一条警告，失败的请求会再试一次；
- 安装 OpenHarmony 构建版本时，会等过被限流的 gitcode.com（30、60、120 和 180 秒）；
- 带 `+ohos-` 的 OpenHarmony 标签会被列出、排序并且可以安装，还会拒绝架构后缀；
- 稳定版排在预发布版本之前，所以第一行是最新的稳定版；
- 重新发布过的压缩包保留它最新的条目，不同的版本或渠道绝不会合并；
- ARM64 的源码安装从第一个能用原生 Dart SDK 运行的版本开始；
- 检出不会采用你 git 配置里的 `core.autocrlf`（这一项运行真正的 `git`，没有它就跳过）；
- 不支持的 CPU 会在提示里点出名字。

清单和 `PreUse` 不在这个文件里，源码安装和 OpenHarmony 构建版本也只测到它们的 `git` 命令为止。这些由容器测试覆盖，见 [e2e.md](e2e.md)。lint、许可证头和容器测试见 [e2e.md](e2e.md#本地检查)。

要单独调用一个 hook，vfox 1.0.13 及更新的版本有 `vfox plugin run`。它不会注册插件，`--os` 和 `--arch` 可以替另一个平台作答：

```bash
vfox plugin run . Available --os windows --arch arm64 --json
vfox plugin run . PreInstall --input '{"version":"stable"}' --os darwin --arch arm64 --json
```

两条命令都会访问真实的索引和 gitcode.com。源码安装（`--os linux --arch arm64`）会在它的工作目录里运行真实的 `git`，不管你自己在什么操作系统上。`vfox --debug <命令>` 会显示 vfox 对一个 hook 做了什么，这是发现被它吞掉的错误的办法。

### 不下载几个 GB 就试验改动

一个压缩包有 1.6 到 2.3 GB，所以试验解析方面的改动，用一个假镜像更省事：它是真实索引的副本，里面所有的压缩包都换成同一个很小的 SDK。这个 SDK 里有一个 `flutter/bin/flutter` 脚本和一个真正的 git 仓库，所以清单和漂移检查都是真的在运行。请在 Linux 上、仓库根目录里运行。它会把 `HOME` 和 `VFOX_HOME` 设成一个临时目录（vfox 需要这两个都设），所以你真正的 vfox 不会受影响。

```bash
work=$(mktemp -d)
python3 - "$work" <<'EOF'
import hashlib, io, json, os, subprocess, sys, tarfile, urllib.request

work = sys.argv[1]
base = "https://storage.googleapis.com/flutter_infra_release/releases/"
index = json.load(urllib.request.urlopen(base + "releases_linux.json"))

sdk = os.path.join(work, "sdk", "flutter")
os.makedirs(os.path.join(sdk, "bin"))
with open(os.path.join(sdk, "bin", "flutter"), "w") as f:
    f.write('#!/bin/sh\necho "fake flutter in $(cd "$(dirname "$0")/.." && pwd)"\n')
os.chmod(os.path.join(sdk, "bin", "flutter"), 0o755)
git = ["git", "-C", sdk, "-c", "user.name=x", "-c", "user.email=x@x", "-c", "core.autocrlf=false"]
subprocess.run(["git", "init", "-q", sdk], check=True)
subprocess.run(git + ["add", "."], check=True)
subprocess.run(git + ["commit", "-q", "-m", "fake"], check=True)

path = os.path.join(work, "flutter.tar.xz")
with tarfile.open(path, "w:xz") as tar:
    tar.add(sdk, arcname="flutter")
sha = hashlib.sha256(open(path, "rb").read()).hexdigest()

root = os.path.join(work, "mirror", "flutter_infra_release", "releases")
os.makedirs(os.path.join(root, "fake"))
os.rename(path, os.path.join(root, "fake", "flutter.tar.xz"))
for release in index["releases"]:
    release["archive"], release["sha256"] = "fake/flutter.tar.xz", sha
with open(os.path.join(root, "releases_linux.json"), "w") as f:
    json.dump(index, f)
EOF
```

临时目录里现在有了这个镜像。按 [install-from-source.md](install-from-source.md) 的办法构建插件：

```bash
zip -qr "$work/flutter.zip" metadata.lua hooks lib
```

在一个你会一直开着的 Shell 里，把镜像放到后台提供服务，再对着它运行 vfox：

```bash
python3 -m http.server 8000 --bind 127.0.0.1 --directory "$work/mirror" >/dev/null 2>&1 &
server=$!
export HOME="$work/home" VFOX_HOME="$work/vfox" FLUTTER_STORAGE_BASE_URL=http://127.0.0.1:8000
mkdir -p "$HOME" "$VFOX_HOME"
vfox add flutter --source "$work/flutter.zip"
vfox search flutter
vfox install flutter@stable
eval "$(vfox activate bash)"
vfox use --global flutter@3.47.7
flutter
```

用 `kill "$server"` 停掉服务，不要用带着它命令行的 `pkill -f`，那样会把你自己的 Shell 也匹配进去。要试验下一个改动，就在仓库里改插件，重复上面的 `zip` 那一行，再在重新 `vfox add` 之前执行 `vfox remove -y flutter`。`vfox search` 列出版本时，插件会向 gitcode.com 要 OpenHarmony 的发布版本，gitcode.com 无法访问时只会花两次尝试和一条警告。真实的索引在 2026-10-21 时 `stable` 是 `3.47.7`；以 `vfox install flutter@stable` 打印出的版本为准。

### 刷新 Dart SDK 表

`lib/source.lua` 里的 `OLDEST_NATIVE` 为每个 ARM64 平台记录了 Flutter 工具用原生 Dart SDK 运行的最老版本。更老的版本做源码安装，克隆没问题，但它的工具取的是 x64 的 Dart SDK，所以插件不给它们 `-arm64` 这个名字。一个版本要原生，得有两个条件：它的引导脚本会请求 ARM64 的 Dart SDK，Flutter 的存储里也有它。老版本不会变，所以这张表在有新平台加入时才需要看一眼，不用每个版本都看。要检查一个版本：

```bash
release=2.0.6
curl -fsSL "https://raw.githubusercontent.com/flutter/flutter/$release/bin/internal/update_dart_sdk.sh" | grep 'DART_ZIP_NAME="dart-sdk-linux'
curl -fsSL "https://raw.githubusercontent.com/flutter/flutter/$release/bin/internal/update_dart_sdk.ps1" | grep -c -i arm64
engine=$(curl -fsSL "https://raw.githubusercontent.com/flutter/flutter/$release/bin/internal/engine.version")
for platform in linux windows; do
  printf '%s ' "$platform"
  curl -s -o /dev/null -I -w '%{http_code}\n' "https://storage.googleapis.com/flutter_infra_release/flutter/$engine/dart-sdk-$platform-arm64.zip"
done
```

第一条命令打印 Linux 脚本请求的 zip：到 `2.0.6` 为止是 `dart-sdk-linux-x64.zip`，从 `2.2.0` 起是 `dart-sdk-linux-${ARCH}.zip`，其中 `ARCH` 由 `uname -m` 决定。第二条数出 Windows 脚本里提到 ARM64 的行数：到 `3.19.6` 为止是 `0`，从 `3.20.0-1.1.pre` 起是 `6`。循环向存储询问这个引擎的 ARM64 Dart SDK，`200` 表示有，`404` 表示没有。2026-10-21 时，`2.0.6` 打印的是 `linux 200` 和 `windows 404`，`3.43.0-0.3.pre` 也一样，`3.44.0-0.1.pre` 两个都是 `200`。

表里 Linux 一行是脚本开始请求的位置（存储里从 `2.0.0` 起就有 SDK），Windows 一行是存储开始有的位置（脚本从 `3.20.0-1.1.pre` 起请求，没有时回退到 x64 的 SDK）。这张表是对 `releases_linux.json` 里 300 个 `"dart_sdk_arch": "x64"` 的版本（也就是会得到 `-arm64` 源码安装的那些）逐个做上面的检查得到的，对其中每一个都成立：283 个版本的 Linux 脚本按 CPU 选 zip，最老的 17 个不是；148 个版本的 Windows 脚本提到 ARM64，最老的 152 个没有。Windows 上有七个更老的 beta 在存储里有这个 SDK，它们和其余的一起被略去（列在 `lib/source.lua` 里）。`1.20.0`、`1.22.4`、`2.0.0` 和 `2.0.6` 的 Linux 脚本还被当作 ARM64 机器运行过，用的是一个说 `aarch64` 的 `uname` 和一个只打印它被要求下载的地址的 `curl`，它们请求的是 `dart-sdk-linux-x64.zip`；`2.2.0`、`2.5.0`、`3.0.0` 和 `3.24.0` 请求的是 `dart-sdk-linux-arm64.zip`。

## 给插件添加功能

- **新的命名或选择方式。** 改 `hooks/available.lua`（顺序）或 `hooks/pre_install.lua`（选择），在 `tests/hooks_test.lua` 里加一个用例，并更新 [versions.md](versions.md)、[channels.md](channels.md) 和 [arm64.md](arm64.md) 里描述它的地方。
- **新平台。** `lib/util.lua` 里的 `getOsTypeAndArch` 列出了支持的 CPU。从 git 安装的平台，要把自己加进 `lib/source.lua` 的 `SOURCE_INSTALL_PLATFORMS` 和 `OLDEST_NATIVE`。更新 [platforms.md](platforms.md) 和 [arm64.md](arm64.md) 里的表，有运行器的话，还要把它加进容器测试（[e2e.md](e2e.md)）。
- **新的构建来源**，像 OpenHarmony 那样：在 `lib/` 里加一个列出名字并负责检出的模块，在 `Available`、`PreInstall` 和 `PostInstall` 里加一个分支，在 `tests/e2e/common/common.go` 里加一个版本类别（`DefaultFlavours`、`DefaultOhosVersion`），再在 `docs/` 里加一页。
- **某条提示。** 容器测试断言了漂移警告的一部分（`tests/e2e/linux/verify.go` 和 `tests/e2e/windows/verify.go`）。要把 Lua 和这两个文件一起改，还有 [flutter-upgrade.md](flutter-upgrade.md) 里的文字。

## 已知缺口

- 源码安装和 OpenHarmony 构建版本不做校验和验证。
- 只列出 Flutter 1.17 及以后的版本。
- `OLDEST_NATIVE` 是 2026-10-21 取得的数据，不会跟随 Flutter 的存储或脚本变化。它只管 Dart SDK：插件不检查老版本在 ARM64 上的其他方面。
- 失败的源码安装会把它的工作目录留下。
- `vfox search` 只会把它打印出的名字标记为已安装，见 [versions.md](versions.md#搜索)。
- 没有架构元数据的版本（稳定版 `1.22.6` 及更早的，以及到 `2.10.0-0.3.pre` 为止的预发布版本）在每台机器上装的都是 x64 压缩包，包括 ARM64 的 Linux 和 Windows，在那里它不能原生运行。
- OpenHarmony 分支会改它的标签名（`-ohos-`，2026-10-15 起是 `+ohos-`）。带别的标记的名字不会被列出。

## 发布

维护者在默认分支上执行 **Actions → Plugin → Run workflow**，填入不带 `v` 的版本号。共享工作流做了什么，见 [README](../../README_CN.md#发布这个插件)。之后 [vfox-plugins](https://github.com/version-fox/vfox-plugins) 里的 `plugins/flutter.json` 会显示 `vfox add flutter` 提供的版本，[changes.md](changes.md) 里也应当有这个版本的条目。

## 编写文档

英文页面在 `docs/`，中文页面在 `docs/zh-CN/`，文件名相同（中文的 README 是 `README_CN.md`），每页的开头都有指向另一种语言的链接。改了一边，两边都要改：中文页面是译文，其中的命令、路径，以及插件和 vfox 的提示信息都保持原样。README 是入口：每个主题几句话和一个链接。细节在 `docs/` 里，每个主题一页。引用外部数据（Flutter 的索引、gitcode.com、vfox）的页面，要写明取得数据的日期或 vfox 的版本。CI 不检查文档，所以你加的命令都要自己运行一遍。

某个平台的命令放在带平台名的标题下（`## Ubuntu 26.04.1`、`## Windows 11`），开头写 `在 Bash 中执行：` 或 `在 PowerShell 7 中执行：`（英文是 `Execute in Bash,` 或 `Execute in PowerShell 7,`），和现有的页面一样。示例安装的是 `3.47.4`，也就是容器测试的默认版本（`tests/e2e/common/common.go` 里的 `DefaultOfficialVersion`）；它变了，就一起改。

只在 `main` 上、还没进入最新发布版的行为，要标上“未发布”（英文是 "Unreleased"），并在 [changes.md](changes.md) 的“未发布”下写一条。发布之后，把这些条目挪到新版本下面，并去掉标记，两种语言都要：`grep -rn -i -e unreleased -e 未发布 docs README*`。
