# 关于 `flutter upgrade`

[中文](flutter-upgrade.md) | [English](../flutter-upgrade.md)

这个插件安装的 Flutter 发布压缩包里带有完整的 `.git` 检出，所以 `flutter upgrade`（以及它的同类 `flutter downgrade`、`flutter channel`，还有在 SDK 目录里执行的任何 `git checkout` / `git pull`）可以就地把 SDK 的 HEAD 移到更新的提交。vfox 是按目录管理 SDK 版本的，不会跟踪这种就地的改动，所以下一次 `vfox use flutter@3.47.0` 会悄悄给你一个已经漂移到别处的 SDK，而不是 3.47.0。

不要在 vfox 管理的 Flutter SDK 里运行 `flutter upgrade`。要换版本，通过 vfox：

```bash
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
```

源码安装（Linux ARM64、Windows ARM64、OpenHarmony 构建版本）也是 git 检出，同样适用。

## 恢复已漂移的 SDK

如果你已经就地升级过了，用下面这条命令恢复那个版本：

```bash
vfox install --reinstall flutter@3.47.0
```

`vfox doctor` 会报告同一个问题（`sdk.drift`）。

## 用其他包管理器装的 SDK

机器上已有的 Flutter，不管是 Homebrew、mise、asdf、winget 装的，还是手动装的，都可以登记给 vfox 用，不用重新下载。登记持有 `bin` 的那个目录（不是的会被拒绝，并说明原因）：

```bash
vfox link flutter@brew-3.47.4 <flutter-sdk-所在的目录>
vfox use --global flutter@brew-3.47.4
```

不管是谁下载的，Google 每个发布压缩包里都带有完整的 `.git` 检出，所以 Fingerprint 事实还是同一个 `head`，就地改动（比如 `brew upgrade`）也会同样报出来，有两点不同：vfox 并不拥有那个 SDK，所以这条问题只是 `vfox doctor` 里 info 级别的提示（`Found 0 errors, 0 warnings and 1 notice`），也没有 `Fix:` 那一行。`vfox install --reinstall` 会拒绝登记来的版本；要用它自己的管理器去升级或删除那个 SDK，或者执行 `vfox uninstall flutter@<名字>` 只删掉登记（SDK 本身原样保留）。没有 `.git` 的登记目录记不下事实，和没有 `.git` 的安装一样，永远安静。

如果另一个管理器的 `flutter` 一直在运行，选中的 `vfox use` 版本始终轮不到它，说明它的目录在 `PATH` 里更靠前：`command -v flutter` 能看到实际赢的是哪一个，`vfox doctor` 会点出挡在前面的目录（`path.shadowed`）。哪些目录留在前面，由 vfox 的 [`path.mode`](https://vfox.dev/zh-hans/guides/configuration.html#path-order-settings) 决定。

## 警告内容

这需要 vfox 1.1.0 或更新的版本，它会在安装时记下 SDK 的状态，每次 `vfox use` 再拿来比对。SDK 的 HEAD 不再是 vfox 安装时的那个提交之后，`vfox use flutter@3.47.4` 打印的就是这样：

```
flutter@3.47.4 has changed since vfox installed it (head: 9584c6713b32… -> abaf9c523780…).
  Something modified the SDK in place, for example a self-update command. vfox manages versions by directory and does not track that.
  To move to a newer version, install it with vfox instead: vfox install flutter@<new-version>
  Fix: vfox install --reinstall flutter@3.47.4
```

`head:` 后面先是记下来的提交，再是现在的提交，都缩短显示了。当前 HEAD 完全读不出来时（`.git` 损坏了），那里会写 `unreadable`，而不是一个提交。

警告只是警告：`vfox use` 仍然会选中你要的版本，退出码是 0。没有 `.git` 目录的 SDK 不检查。

vfox 老于 1.1.0 时，插件会打印它自己的警告（它加载不到 `Fingerprint` 钩子），并给出手工重装的命令。把 vfox 升级到 1.1.0 或更新，就能用上面的检查。

## 检查如何进行

安装时和 `vfox link` 登记时，插件通过 `Fingerprint` 钩子报告 SDK 检出所在的提交：只从文件里读 `.git/HEAD`（以及它指向的 ref 或 `packed-refs`），不跑任何命令。vfox 把这个事实记在版本的收据里，也就是 `vfox info flutter@3.47.4` 打印的那个目录下的 `.vfox-receipt.json`：

```json
{
  "schema": 1,
  "sdk": "flutter",
  "version": "3.47.4",
  "origin": "installed",
  "facts": {
    "head": "9584c6713b324636289d067944a46fd6b49df14b"
  }
}
```

`vfox use` 和 `vfox doctor` 在事实对不上时报告 `sdk.drift`。压缩包安装、源码安装和 OpenHarmony 构建版本都会报告。插件现在读不出来的事实，也算是一种变化。

没有可比较的东西时就什么都不检查：没有事实的 SDK（安装时就没有 `.git` 可读）、vfox 开始记收据之前安装的版本（见下面的 `vfox doctor --adopt`），以及 vfox 不认识的版本，都不会有任何提示。

比这个插件更老的版本装出来的 SDK，根目录里可能还留着 `.vfox-manifest` 文件（`flutter-3.47.0/.vfox-manifest`）。当前插件既不写它也不读它，它会被忽略，可以删掉。留着的时候，在 SDK 里执行 `git status` 会把它显示为未跟踪。

在 vfox 开始记收据之前安装的版本，没有收据可比。`vfox doctor` 会说明（`sdk.no-receipt`），并可以按要求把现在的状态记为基准：

```bash
vfox doctor --adopt flutter@3.47.0
```

## 关闭检查

这个检查是 `vfox use` 选中版本后运行的快速检查之一。要停掉它们：

```bash
vfox config diagnostics.onUse false
```

只想让某一个版本不再报这一项，在 `config.yaml` 里把它加到 `diagnostics.ignore`：

```yaml
diagnostics:
  ignore:
    - "sdk.drift:flutter@3.47.0"
```

其余的检查项，见 vfox 的[配置说明](https://vfox.dev/zh-hans/guides/configuration.html#diagnostics-settings)和 [`vfox doctor`](https://vfox.dev/zh-hans/usage/core-commands.html#doctor)。
