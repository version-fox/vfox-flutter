# 从源码安装

[中文](install-from-source.md) | [English](../install-from-source.md)

`vfox add flutter` 安装的是最新的发布版。想在下一个版本发布之前用上 `main`，或者试用你正在改的代码，就从源码构建插件。插件就是一个 `metadata.lua` 加上 `hooks` 和 `lib` 两个目录，vfox 可以从它们的 zip 包添加插件。

## Ubuntu 26.04.1

在 Bash 中执行：

```bash
sudo apt install --assume-yes git zip
git clone --depth 1 https://github.com/version-fox/vfox-flutter.git
cd ./vfox-flutter/
zip -qr ./flutter.zip metadata.lua hooks lib
vfox add flutter --source ./flutter.zip
rm ./flutter.zip
```

可以用下面的命令验证：

```bash
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
flutter --version --no-version-check
dart --version
```

macOS 的步骤相同，用你机器上已有的 `git` 和 `zip` 即可。

## Windows 11

这里假设已经装好了 PowerShell 7，在 PowerShell 7 中执行：

```powershell
winget install --id Git.Git --source winget --exact
git clone --depth 1 https://github.com/version-fox/vfox-flutter.git
cd ./vfox-flutter/
tar -a -cf ./flutter.zip metadata.lua hooks lib
vfox add flutter --source ./flutter.zip
Remove-Item ./flutter.zip
```

可以用下面的命令验证：

```powershell
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
flutter --version --no-version-check
dart --version
```

## 已经添加过 flutter 插件时

`vfox add` 会拒绝，并报 `plugin named flutter already exists`。你可以替换原有的插件，也可以把源码构建的版本另起个名字，与原插件并存。

替换要先执行 `vfox remove flutter`，它会连同通过这个插件装的 Flutter SDK 一起删掉，vfox 会在确认之前先说 `Removing this plugin will remove the installed sdk along with the plugin.`。之后需要重新安装这些 SDK。光是一个压缩包就有 1.6 到 2.3 GB，所以这是代价最高的办法。

想两个都留着，就给新的起个别名：

```bash
vfox add flutter --source ./flutter.zip --alias flutter-dev
vfox install flutter-dev@3.47.4
vfox remove -y flutter-dev            # 只删除 flutter-dev 和它装的东西
```

别名有它自己的已安装列表，它的下载也在 vfox 主目录的 `cache/flutter-dev` 下。`vfox use` 建的链接对两者都是 `~/.vfox/sdks/flutter`，进入 `PATH` 的 `bin` 目录也是同一个。在每个作用域里，只从其中一个选版本：全局作用域下，先执行 `vfox unuse --global flutter`，再 `vfox use --global flutter-dev@...`，反过来也一样。

## 更新

拉取代码，重新打 zip 包，再添加一次。以原名添加的插件必须先删除，这会连已安装的 Flutter 一起删掉，所以经常更新时用别名更省事：

```bash
vfox remove -y flutter-dev
vfox add flutter --source ./flutter.zip --alias flutter-dev
```

`vfox update flutter` 会拿 `metadata.lua` 里的版本号和插件注册表里的比较，两者相同时只会打印 `flutter is already the latest version`，所以版本号和发布版相同的改动，它不会替你装上。要装上这样的改动，请再添加一次源码构建的版本。

开发插件请看 [development.md](development.md)。
