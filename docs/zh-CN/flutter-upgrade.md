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

如果你已经就地升级过了，这个插件会在每次 `vfox use` 那个版本时打印一条警告，并给出恢复它的命令：

```bash
vfox uninstall flutter@3.47.0
vfox install  flutter@3.47.0
vfox use      flutter@3.47.0
```

## 警告内容

SDK 的 HEAD 不再是 vfox 安装时的那个提交之后，`vfox use flutter@3.47.4` 打印的就是这样：

```
Warning: flutter SDK at ~/.vfox/cache/flutter/v-3.47.4 has drifted from the version vfox installed.
  vfox installed: flutter@3.47.4 (git HEAD 9584c6713b324636289d067944a46fd6b49df14b)
  current git HEAD: abaf9c523780a608bd46686fd5e53740a07077f8
  reason: the SDK's git HEAD no longer matches the commit vfox installed

This typically happens when `flutter upgrade` or a similar in-place command
is run inside a vfox-managed SDK. vfox manages SDK versions by directory and
does not track in-place mutations, so the version you get may differ from
the one you asked for.

To restore flutter@3.47.4:
  vfox uninstall flutter@3.47.4
  vfox install  flutter@3.47.4
  vfox use      flutter@3.47.4

To upgrade to a newer version, use vfox directly:
  vfox install flutter@<new-version>
  vfox use     flutter@<new-version>
```

原因有两种，`reason:` 后面的那行说明是哪一种：

| 原因 | 含义 |
| --- | --- |
| `the SDK's git HEAD no longer matches the commit vfox installed` | 提交变了。`flutter upgrade`、`flutter downgrade`、`flutter channel` 和 `git checkout` 都会这样 |
| `vfox can no longer read the SDK's git HEAD (its .git may be broken)` | `git` 在 SDK 里执行失败：`.git` 目录损坏了，或者 `git` 已经不在了 |

第一行里的路径，就是 `vfox info flutter@3.47.4` 打印的目录。SDK 是它里面的 `flutter-3.47.4` 目录。

## 检查如何进行

安装时，插件会在 SDK 的 `.git` 旁边写一个 `.vfox-manifest` 文件，记录预期的 git HEAD，之后每次 `vfox use` 都会重新检查。

清单是 SDK 根目录里的一个小 JSON 文件，`flutter-3.47.4/.vfox-manifest`：

```json
{"expected_head":"9584c6713b324636289d067944a46fd6b49df14b","installed_at":1792523751,"plugin":"vfox-flutter","plugin_version":"0.2.4","version":"3.47.4"}
```

`expected_head` 是 vfox 刚解压完 SDK 时 `git rev-parse HEAD` 打印的结果，`installed_at` 是安装时间，单位是自 1970 年以来的秒数。`vfox use` 时检查会再执行一次 `git rev-parse HEAD`，并比较两者。压缩包安装、源码安装和 OpenHarmony 构建版本都会有清单。在 SDK 里执行 `git status`，这个文件会显示为未跟踪。

警告只是警告：`vfox use` 仍然会选中你要的版本，退出码是 0。没有 `.git` 目录的 SDK 不检查。

没有可比较的东西时就什么都不检查：没有清单的 SDK（由早于 0.2.3 的插件安装的）、清单里没有 `expected_head` 的（安装时没有 `git`），以及 vfox 不认识的版本，都不会有任何提示。

## 关闭检查

删掉受影响那份安装里的 `.vfox-manifest` 文件。这个文件是真正的安装才会写出来的，所以只有卸载再重新安装那个版本，它才会回来；单独执行 `vfox install` 会跳过已经安装的版本，文件依然不存在。

`vfox info --format '{{.Path}}' flutter@3.47.0` 打印的是 SDK 上一层的目录，所以清单在更下一层的 `flutter-3.47.0` 里。这个目录以已安装的名字命名，如果你安装时带了架构后缀，它也会带（`flutter-3.47.0-x64`）。

### Ubuntu 26.04.1

在 Bash 中执行：

```bash
rm "$(vfox info --format '{{.Path}}' flutter@3.47.0)/flutter-3.47.0/.vfox-manifest"
```

### Windows 11

这里假设已经装好了 PowerShell 7，在 PowerShell 7 中执行：

```powershell
Remove-Item "$(vfox info --format '{{.Path}}' flutter@3.47.0)/flutter-3.47.0/.vfox-manifest"
```
