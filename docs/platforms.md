# Platform support

[中文](zh-CN/platforms.md) | [English](platforms.md)

The plugin installs Flutter on Linux, macOS and Windows, on x64 and ARM64. It takes the operating system and the CPU architecture from the vfox binary that runs it (`osType` and `archType` are Go's `GOOS` and `GOARCH`): `darwin` becomes `macos`, `amd64` becomes `x64` and `arm64` stays. Any other CPU stops with a message that names it, see [troubleshooting.md](troubleshooting.md#flutter-does-not-support-the-386-architecture).

| Machine | Installs from | Release index |
| --- | --- | --- |
| Linux x64 | `.tar.xz` archives Google publishes | `releases_linux.json` |
| Linux ARM64 | the `flutter/flutter` git tag, see [arm64.md](arm64.md#linux-arm64) | `releases_linux.json` |
| macOS Apple silicon | `.zip` archives, arm64 and x64 | `releases_macos.json` |
| macOS Intel | `.zip` archives, x64 and arm64 | `releases_macos.json` |
| Windows x64 | `.zip` archives | `releases_windows.json` |
| Windows ARM64 | the `flutter/flutter` git tag, see [arm64.md](arm64.md#windows-arm64) | `releases_windows.json` |

OpenHarmony builds are a checkout from gitcode.com on every machine, see [ohos.md](ohos.md). The index is read from `https://storage.googleapis.com/flutter_infra_release/releases/`, or from the mirror named by `FLUTTER_STORAGE_BASE_URL`, see [mirror.md](mirror.md).

What each machine gets for `3.47.4`, `3.47.4-x64` and `3.47.4-arm64` is in [arm64.md](arm64.md#what-each-machine-gets).

## Requirements

- **vfox**, hooked into your shell, so that `flutter` is on the `PATH` after `vfox use`, see vfox's [quick start](https://vfox.dev/guides/quick-start.html). The plugin declares vfox 0.3.0 as the oldest it loads on. The tests run against the latest vfox release and against vfox's `main`, and a Windows account whose home directory contains a space needs vfox 1.0.13 or later ([vfox#712](https://github.com/version-fox/vfox/pull/712)).
- **`git`**, for Linux ARM64 and Windows ARM64 (every install), for OpenHarmony builds, and for the drift check of [flutter-upgrade.md](flutter-upgrade.md). That check asks `git` for the SDK's commit when it installs; without `git` the install still succeeds, writes a `.vfox-manifest` that has no commit, and `vfox use` never warns. Flutter itself needs `git` as well.
- **Flutter's own tools.** Android, iOS, Linux, Windows and web development have requirements of their own (Android SDK, Xcode, Visual Studio, GTK and more). vfox does not install them, see [Flutter's installation guide](https://docs.flutter.dev/install). The example in the [README](../README.md#install) installs `curl git unzip xz-utils zip libglu1-mesa` for Ubuntu.
- **Disk space.** An archive is 1.6 to 2.3 GB (see [versions.md](versions.md#installing)), and vfox removes it after unpacking. The SDK grows as the `flutter` tool downloads what it needs for the platforms you build for. A source install needs room for the checkout as well. Every name you install is a separate SDK, see [versions.md](versions.md#installed-names).

## Where the plugin connects

| Host | What for | When |
| --- | --- | --- |
| `storage.googleapis.com`, or your mirror | the release index, the archives, and what the `flutter` tool downloads itself, such as the Dart SDK of a source install and the engine artifacts | always |
| `gitcode.com` | the list of OpenHarmony releases (an API request), and the checkout of an OpenHarmony build | the list when `vfox search` or the `latest` of `vfox install` lists versions, and to install an OpenHarmony build; the checkout for OpenHarmony builds only |
| `github.com` | the checkout of `flutter/flutter` | Linux ARM64 and Windows ARM64 installs |

`pub.dev` is not the plugin's, but the Flutter tool reaches it when it boots, and the test suite checks that it answers. Installing an official release does not need `gitcode.com`, and a firewall that blocks it costs `vfox search` two quick attempts and a warning, see [troubleshooting.md](troubleshooting.md#gitcodecom-is-rate-limited).

## What the tests cover

The Lua hook tests (`tests/hooks_test.lua`) run offline for every pull request. They simulate Linux, macOS and Windows on x64 and arm64 against a fixture of the release index.

The container suites install a real Flutter with real vfox, in a throwaway container for each combination, see [e2e.md](e2e.md):

| Machine | Container | Flutter | vfox |
| --- | --- | --- | --- |
| Linux x64 and Linux ARM64 | Ubuntu 26.04, driven from bash. A second test uses zsh and a Homebrew vfox | 3.47.4 | the latest release and `main` |
| Windows x64 and Windows ARM64 | Windows Server 2025 Server Core, driven from PowerShell 7, with a vfox home in a path that contains a space | 3.47.4 | the latest release and `main` |

On x64 the runs repeat for the OpenHarmony build 3.41.10-ohos-1.0.0, and, with the latest vfox only, with the CFUG mirror set. ARM64 runs the official build only. Each run installs the version, checks the drift warning, and boots `flutter` and `dart`.

macOS is not in the container suites, because a container cannot run it. Its architecture selection is covered by the offline tests only.
