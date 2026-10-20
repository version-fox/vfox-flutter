# Versions and names

[中文](zh-CN/versions.md) | [English](versions.md)

The part after `flutter@` in `vfox install`, `vfox use` and `vfox uninstall` is a version: the name of a release as `vfox search flutter` prints it, with or without an architecture suffix, or a channel.

```bash
vfox install flutter@3.47.4              # a stable release, for the architecture of this machine
vfox install flutter@3.47.4-x64          # the same release, as an x64 build
vfox install flutter@3.50.0-0.1.pre      # a beta release
vfox install flutter@stable              # the release the stable channel points to today
vfox install flutter@3.41.10-ohos-1.0.0  # an OpenHarmony build
```

A version is matched as a whole. `flutter@3.47` and `flutter@3` do not select the newest 3.47.x or 3.x, they fail with `no installable runtime provided`. Names are case sensitive (`flutter@Stable` fails), and vfox itself drops a leading `v`, so `flutter@v3.47.4` is `flutter@3.47.4`.

## Release names

A release is named after the Flutter version it contains, as Flutter's release index spells it. `vfox search` shows the channel it was published to next to it, see [Searching](#searching).

| Name | What it is |
| --- | --- |
| `3.47.7` | A stable release |
| `3.50.0-0.1.pre` | A beta release. Flutter's pre-releases end in `.pre` |
| `3.47.4-x64`, `3.47.4-arm64` | The same release as an x64 or an arm64 build, see [arm64.md](arm64.md) |
| `1.22.6` | An old release without architecture metadata, which installs the same everywhere, see [arm64.md](arm64.md#releases-without-architecture-metadata) |
| `3.41.10-ohos-1.0.0` | An OpenHarmony build: release 1.0.0 of the fork's 3.41.10 line, see [ohos.md](ohos.md) |
| `stable`, `beta` | Channels, resolved to a release when you install, see [channels.md](channels.md) |

The plugin lists the releases from Flutter 1.17 (April 2020) on. Flutter published its older releases with a `v` prefix (`v1.12.13+hotfix.9` is the first one the plugin stops at), and they are not offered.

## Installing

`vfox install` asks the plugin which package matches, then vfox downloads and unpacks it.

- The plugin reads Flutter's release index for the operating system: `releases_linux.json`, `releases_macos.json` or `releases_windows.json` under `https://storage.googleapis.com/flutter_infra_release/releases/`, or under the mirror that `FLUTTER_STORAGE_BASE_URL` names (see [mirror.md](mirror.md)). It asks up to three times, five seconds apart.
- The version has to equal a name in that index, see [Release names](#release-names). A release nobody published fails with `no installable runtime provided`.
- Without an architecture suffix the plugin picks the build for the architecture of this machine. A release that has no architecture metadata has a single archive, which is the one it takes.
- vfox verifies the archive against the SHA-256 checksum from the index and prints `Verifying checksum ...`. It removes the archive after unpacking.
- On Linux ARM64 and Windows ARM64 the plugin installs a git tag instead of an archive, see [arm64.md](arm64.md). OpenHarmony builds are git checkouts as well, see [ohos.md](ohos.md). Neither is verified against a checksum.
- Installing a name that is already there prints `flutter@3.47.4 is already installed` and downloads nothing.
- Installing an official release does not contact gitcode.com. Listing versions does: `vfox search`, and the `latest` of `vfox install`, ask it for the OpenHarmony releases, twice at most, and say so when it does not answer, see [troubleshooting.md](troubleshooting.md#gitcodecom-is-rate-limited).

An archive is large: 3.47.7 on 2026-10-21 was 1.6 GB for Linux x64, 1.9 GB for Windows x64 and 2.3 GB for macOS. The first `flutter` run downloads more, see [troubleshooting.md](troubleshooting.md#things-that-look-wrong-and-are-not).

## Installed names

The plugin names an install after the version you asked for, with the architecture suffix only if you wrote one. These are the Linux x64 results on 2026-10-21; a channel or `latest` is replaced by the release it stands for:

| You run | Installed name |
| --- | --- |
| `vfox install flutter@3.47.4` | `3.47.4` |
| `vfox install flutter@3.47.4-x64` | `3.47.4-x64` |
| `vfox install flutter@stable` | `3.47.7` |
| `vfox install flutter@stable-x64` | `3.47.7-x64` |
| `vfox install flutter@beta` | `3.50.0-0.1.pre` |
| `vfox install flutter@latest` | `3.47.7-x64`, the first line of `vfox search flutter`, see [Searching](#searching) |
| `vfox install flutter@3.41.10-ohos-1.0.0` | `3.41.10-ohos-1.0.0` |

These are the names `vfox list flutter` shows and `vfox use` and `vfox uninstall` need:

```
$ vfox list flutter
-> 3.50.0-0.1.pre-x64
-> 3.47.4-x64
-> 3.47.4 <— current
```

`3.47.4` and `3.47.4-x64` are the same Flutter on an x64 machine, and vfox keeps them as two installs, each a full SDK. Write the suffix always or never. Uninstalling one leaves the other alone:

```bash
vfox uninstall flutter@3.47.4-x64
```

`vfox uninstall flutter@stable` answers `flutter@stable is not installed`; `vfox uninstall` takes the installed name, as `vfox use` does. When you uninstall the version in use, vfox switches to the first entry left in `vfox list flutter`, which can be a beta.

Each install lives in `cache/flutter/v-<name>/flutter-<name>/` under the vfox home (`~/.vfox` unless `VFOX_HOME` is set), see [troubleshooting.md](troubleshooting.md#where-flutter-is).

## Using

`vfox use` takes an installed name as it is. It does not complete or search:

| You run | Result |
| --- | --- |
| `vfox use flutter@3.47.4` | selects `3.47.4` |
| `vfox use flutter@3.47.4-x64` | selects `3.47.4-x64` |
| `vfox use flutter@3.47` | `flutter@3.47 is not installed` |
| `vfox use flutter@stable` | `flutter@stable is not installed`, see [channels.md](channels.md) |
| `vfox use flutter@latest` | the first entry of `vfox list flutter`, which vfox sorts by itself, so it is a beta if you have one installed |

Pick the scope with `vfox use`'s flags: `--global`, `--project` or `--session`. Without a flag the scope is the session on Linux and macOS and the global one on Windows. Where the choice is written:

| Scope | Written to | `flutter` comes from |
| --- | --- | --- |
| `--global` | `~/.vfox/.vfox.toml` | `~/.vfox/sdks/flutter/bin` |
| `--project` | `.vfox.toml` in the current directory | `.vfox/sdks/flutter/bin` in that directory |
| `--session` | the current shell only | a directory under `~/.vfox/tmp` |

`.vfox.toml` holds the installed name (`flutter = "3.47.4"`). Commit it, so that the project builds with one Flutter for everybody, and keep `.vfox/` out of git: vfox does not add it to your `.gitignore`. vfox also reads an asdf `.tool-versions` (`flutter 3.47.4`) when its `legacyVersionFile.enable` setting is on, which it is by default in vfox 1.0.13. The plugin has no legacy file of its own, so `.fvmrc` and FVM's `.fvm` directory are not read.

The plugin adds `<sdk>/bin` to `PATH`. That puts `flutter` and `dart` on it. It sets no `FLUTTER_ROOT`, and `~/.pub-cache/bin`, where `dart pub global activate` puts executables, stays yours to add.

To run one command with a Flutter without selecting it, or in a script, a container or an IDE task where the shell hook is not active, use `vfox exec` with an installed name:

```bash
vfox exec flutter@3.47.4 -- flutter --version
```

`vfox exec flutter@stable` does not work, see [channels.md](channels.md#use-the-version-not-the-channel).

## Searching

```
$ vfox search flutter
Available versions:
 - 3.47.7-x64 (stable) [dart 3.13.5]
 - 3.47.6-x64 (stable) [dart 3.13.5]
 ...
 - 1.17.0 (stable) [dart ]
 - 3.50.0-0.1.pre-x64 (beta) [dart 3.14.0 (build 3.14.0-315.1.beta)]
 - 3.49.0-0.2.pre-x64 (beta) [dart 3.14.0 (build 3.14.0-211.1.beta)]
 ...
 - 1.17.0-3.2.pre (beta) [dart ]
 - 3.41.10-ohos-1.0.0 (OpenHarmony)
 ...
```

Each line is a name that can follow `flutter@`, with the channel the release was published to in parentheses, and the Dart SDK that comes with it in brackets. A mark `(installed)` follows the names that are installed. Flutter's index has no Dart version for the releases up to `2.9.0-0.1.pre`, which leaves the brackets empty. OpenHarmony builds carry `(OpenHarmony)` and no Dart version.

The mark only follows names the list prints. On x64 Linux and Windows nearly every official release is listed as `3.47.4-x64`, so an install made with `vfox install flutter@3.47.4` (installed name `3.47.4`) shows no mark, while `vfox install flutter@3.47.4-x64` does. Check `vfox list flutter` for what is installed.

In an interactive terminal `vfox search flutter` lets you pick a version and installs it; elsewhere it prints the list. vfox keeps the answer for 12 hours (`vfox config cache.availableHookDuration`), so a release published a minute ago may be missing; `vfox config cache.availableHookDuration 0` turns the cache off.

The list is sorted as follows:

1. Official releases come before OpenHarmony builds.
2. The architecture of this machine comes before the others. A release without architecture metadata counts as the architecture of this machine.
3. Releases of the stable channel come before the pre-releases of the beta and dev channels.
4. The newest comes first, going by the numbers in the version. `3.47.0` sorts above `3.47.0-0.4.pre`.
5. Two builds of one version put the architecture of this machine first, and a version in two channels lists beta before dev.

So the first line is the newest stable release, and that is what `vfox install flutter@latest` installs, with the architecture suffix:

```
$ vfox install flutter@latest
Using latest version: 3.47.7-x64
```

`latest` keeps to the architecture of this machine, as [arm64.md](arm64.md) explains, and never selects an OpenHarmony build.

A few versions appear more than once. They are in Flutter's index more than once, because a release was promoted from one channel to another and has an archive in each (`2.13.0-0.1.pre` is listed for beta and for dev), and the lines install the same name. A release that was published again has the same archive under two checksums, and the plugin lists only the newest entry of it, the one whose checksum matches the file (`3.13.3`, `3.9.0-0.1.pre` and `3.17.0-0.0.pre` are the three that Flutter published again), see [troubleshooting.md](troubleshooting.md#checksum-error).

The length of the list depends on the machine. On 2026-10-21 it had 455 names on Linux x64 (430 official releases and 25 OpenHarmony builds), 717 on macOS (692 and 25, with both architectures), 453 on Windows x64, and 743 and 490 on Linux ARM64 and Windows ARM64, which add 288 and 37 source installs. A list that is much shorter than that means the plugin could not read part of its sources, see [troubleshooting.md](troubleshooting.md#network).
