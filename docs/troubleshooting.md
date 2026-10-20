# Troubleshooting

[中文](zh-CN/troubleshooting.md) | [English](troubleshooting.md)

## Messages

The messages that vfox prints itself are the ones of vfox 1.0.12 and 1.0.13; other versions may word them differently.

### `no installable runtime provided`

```
$ vfox install flutter@dev
no installable runtime provided
failed to install flutter
```

The plugin found nothing for the name you typed. The usual reasons:

- The name is not a release. `flutter@3.47` and `flutter@3` are not completed to the newest 3.47.x or 3.x, and names are case sensitive (`flutter@Stable`). Look the name up in `vfox search flutter`, see [versions.md](versions.md).
- `dev`: Flutter retired the channel, see [channels.md](channels.md#dev).
- The architecture suffix does not exist for the machine: `-arm64` on Linux x64 and Windows x64, any suffix on a release without architecture metadata (`1.22.6-x64`), or no suffix for an old release on Apple silicon that only has an x64 build (`flutter@2.10.5` needs `flutter@2.10.5-x64`). See [arm64.md](arm64.md).
- Unreleased: a release that is older than the first that runs with a native Dart SDK, on Linux ARM64 (`flutter@1.20.0`) or Windows ARM64 (`flutter@3.43.0-0.3.pre`). Release 0.2.4 installs them with the x64 Dart SDK, see [arm64.md](arm64.md#releases-that-run-natively). The `-x64` name installs the archive.
- An OpenHarmony name with `+ohos-` (`3.41.9+ohos-1.0.2`) on release 0.2.4, which only knows `-ohos-` names. Unreleased: it knows both, see [ohos.md](ohos.md#names-and-releases).

### `flutter@stable is not installed`

`vfox use` and `vfox uninstall` only know installed names, and a channel is replaced by a release while it installs. `vfox list flutter` shows the names, see [channels.md](channels.md#use-the-version-not-the-channel). `vfox exec flutter@stable` ends with `failed to get runtime package for flutter@stable: open .../cache/flutter/v-stable: no such file or directory` for the same reason.

### `flutter@3.47.4 is already installed`

The name is installed. vfox does not download again, and does not write the `.vfox-manifest` again, see [flutter-upgrade.md](flutter-upgrade.md#disabling-the-check).

### `get version failed: ... (status ...)`

```
plugin [PreInstall] method error: ~/.vfox/plugin/flutter/hooks/available.lua:35: get version failed: Get "<address of the index>": <error> (status nil)
stack traceback:
	...
failed to install flutter
```

The plugin could not read Flutter's release index, and it tried three times, five seconds apart, so the install fails ten seconds after it started. After `get version failed:` comes the error of the request, then the HTTP status in parentheses:

- `(status nil)` means no HTTP answer came: DNS, connection, TLS or proxy problems. A refused connection reads `dial tcp 127.0.0.1:1: connect: connection refused`, and a proxy that does not answer `proxyconnect tcp: dial tcp 127.0.0.1:9: connect: connection refused`.
- `get version failed: nil (status 404)`, or another number, means the server answered and refused. With a mirror, a 404 usually means a wrong address: the plugin asks for `<mirror>/flutter_infra_release/releases/releases_linux.json` (`releases_macos.json`, `releases_windows.json`).

See [Network](#network) and [mirror.md](mirror.md). A channel (`flutter@stable`) reads the index once before that, without retrying, and the message then names `hooks/pre_install.lua`.

### `checksum error`

```
Verifying checksum c53c8aeff17d13c4c0b47bff2c54a293e48286e03dd089f37d561737e41a8c2c...
Checksum error, file: ~/.vfox/cache/flutter/flutter_linux_3.13.3-stable.tar.xz
checksum error
failed to install flutter
```

vfox downloaded the archive and its SHA-256 differs from the one in Flutter's release index. For a mirror, check that it serves the files of the index it serves. Without a mirror this was the data of the index itself: it lists `3.13.3`, `3.9.0-0.1.pre` and `3.17.0-0.0.pre` twice or three times for one file, with a different checksum for each entry. Flutter uploaded the file again and kept the old entries. The checksum of the newest entry is the right one (checked on Linux by downloading the three archives).

The plugin lists only the newest entry of such a file, so these three install. Unreleased: release 0.2.4 lists every entry and installs the one that sorts first, which is arbitrary for entries that are equal, and which also depends on the rest of the list, such as how many OpenHarmony releases it holds. On 2026-10-21 it took an old entry for all three on Linux x64, and for some of them on macOS and Windows, and the install ended as above. Install a release next to it (`3.13.2` or `3.13.4` instead of `3.13.3`), or update the plugin. There is no switch to skip the check.

### `Warning: flutter SDK at ... has drifted from the version vfox installed.`

`flutter upgrade`, `flutter channel` or a `git` command moved the SDK. `vfox use` still selects it. See [flutter-upgrade.md](flutter-upgrade.md).

### `flutter does not support the 386 architecture`

The plugin runs on x64 and ARM64 only. vfox tells it the CPU of its own binary (`386`, `arm`, `riscv64`, `loong64`, ...) and the message names it, as in `flutter does not support the arm architecture`. It stops `vfox search` and the install of an official release. See [platforms.md](platforms.md). Unreleased: release 0.2.4 prints the same without the spaces, `flutter does not support386architecture`.

### Source installs: Linux ARM64 and Windows ARM64

The messages come from the plugin and name the step that failed, see [arm64.md](arm64.md#how-a-source-install-works).

| Message | Meaning |
| --- | --- |
| `cannot resolve the vfox home directory` | Neither `VFOX_HOME`, `HOME` nor `USERPROFILE` is set, so the plugin does not know where to make `.vfox/tmp/<name>` |
| `failed to initialize git in <dir> (is git installed?)` | `git init` failed: `git` is missing, or the directory cannot be written |
| `failed to fetch tag 3.47.4 from https://github.com/flutter/flutter.git` | All three fetches failed. `git` printed its own error above the message. Check that GitHub answers, or set `VFOX_FLUTTER_GITHUB_MIRROR`, see [mirror.md](mirror.md#github-mirror-for-source-installs) |
| `failed to check out 3.47.4 in <dir>` | `git checkout FETCH_HEAD` failed |
| `the checkout at 3.47.4 has no engine version pin` | The checkout has no `bin/internal/engine.version`, so it is not a Flutter SDK |
| `Using GitHub mirror https://gh-proxy.org/https://github.com/flutter/flutter.git` | Not an error: `VFOX_FLUTTER_GITHUB_MIRROR` is in use |

A failed install leaves `.vfox/tmp/<name>` under `$VFOX_HOME`, or under your home directory, behind. Delete it. The next install of the same name deletes it anyway.

A fetch that moves less than 1 KB/s for a minute is abandoned and counts as a failed attempt, which is how a stalled connection ends up in `failed to fetch tag`.

### OpenHarmony builds

| Message | Meaning |
| --- | --- |
| `OpenHarmony releases are unavailable from https://gitcode.com/api/v5/...: HTTP 429` | Installing an OpenHarmony build: five attempts to read the releases failed. The text after the colon is the last error, here gitcode.com's rate limit, see [below](#gitcodecom-is-rate-limited). Listing versions never prints this message, it prints the warning below and goes on without the OpenHarmony ones |
| `Warning: the OpenHarmony releases could not be read from gitcode.com (<error>), so only the official releases are listed.` | Printed on stderr by `vfox search`, and by the `latest` of `vfox install`, when two attempts did not get the list. The official releases are listed as usual, and an OpenHarmony build still installs by its name. Unreleased: release 0.2.4 prints nothing, and waits up to 6.5 minutes first |
| `flutter 3.47.7-ohos-1.0.0 is not an OpenHarmony release` | The name has `-ohos-` in it, and gitcode.com has no release by that name |
| `flutter 3.41.10-ohos-1.0.0 has no architecture variants` | The name had `-x64` or `-arm64` after it |
| `failed to fetch <commit> from https://gitcode.com/CPF-Flutter/flutter_flutter.git` | All three fetches failed |

See [ohos.md](ohos.md).

### `bin/internal/shared.sh: line 5: $'\r': command not found`

A source install on Linux (Linux ARM64, or an OpenHarmony build) whose first `flutter` run fails like this was checked out with CRLF line endings, because of `core.autocrlf=true` in your git configuration. The plugin now sets `core.autocrlf=false` in the checkout. Unreleased: release 0.2.4 takes your setting, so run `git config --global core.autocrlf input`, uninstall the version and install it again, see [arm64.md](arm64.md#limits).

### `Building flutter tool...` and `It appears that the downloaded file is corrupt`

The first `flutter` run of a source install builds the Flutter tool and downloads the Dart SDK, so it is slow and needs the network. An install from an archive does not build the tool on its first run: the plugin touches `packages/flutter_tools/pubspec.lock` after unpacking for that, see [development.md](development.md#contracts-that-cost-time).

`It appears that the downloaded file is corrupt; please try again.` is what the Flutter tool says when the Dart SDK it downloaded is not a valid zip file, which is what a missing file (HTTP 404) gives. That happens for OpenHarmony builds on ARM64.

## Network

The plugin reaches `storage.googleapis.com` (or your mirror), `gitcode.com` and, for source installs, `github.com`, see [platforms.md](platforms.md#where-the-plugin-connects). It repeats a request that fails:

| Request | Attempts | Waits between attempts |
| --- | --- | --- |
| The release index, when listing or installing a version | 3 | 5 seconds |
| The release index, once before that for a channel | 1 | none |
| OpenHarmony releases from gitcode.com, to install an OpenHarmony build | 5 | 10 seconds, but 30, 60, 120 and 180 seconds after HTTP 429 |
| OpenHarmony releases from gitcode.com, to list versions | 2 | 2 seconds. HTTP 429 ends the attempts |
| `git fetch` of a source install or an OpenHarmony build | 3 | none. A transfer under 1 KB/s for a minute counts as failed |

vfox's own proxy setting covers the plugin's requests and the archive download:

```bash
vfox config proxy.enable true
vfox config proxy.url http://127.0.0.1:7890
```

While `proxy.enable` is `false`, the usual `HTTP_PROXY`, `HTTPS_PROXY` and `NO_PROXY` environment variables apply. `git`, which source installs and OpenHarmony builds run, does not read vfox's setting. It reads its own: `HTTPS_PROXY` or `git config --global http.proxy`.

### gitcode.com is rate-limited

The plugin asks gitcode.com for the OpenHarmony releases in two cases. Installing an OpenHarmony build needs them, and waits for them. `vfox search flutter` (vfox answers from its cache for 12 hours, so only the first one asks), and the `latest` of `vfox install`, list them, and do not wait. Installing an official release does not ask gitcode.com at all.

gitcode.com limits what anonymous clients may ask. Over the limit it answers HTTP 429:

```
{"error_code":429,"error_code_name":"UN_KNOW","error_message":"429 The number of times the user invokes this API is too large. Threshold: 10W times per user per hour. Limited account:p_repoRobot.", ...}
```

This is gitcode.com's limit for requests without a login, not a limit of yours: the message names the account the request is counted against, `p_repoRobot`. What the plugin does with it:

- A listing makes two attempts, two seconds apart, and HTTP 429 ends them at once. When it gets no list it prints one line on stderr and goes on with the official releases:

  ```
  Warning: the OpenHarmony releases could not be read from gitcode.com (HTTP 429), so only the official releases are listed.
  ```

  An unreachable gitcode.com costs the same two attempts, so about 2 seconds with a connection that fails at once (measured through a proxy that refused it: 2.1 seconds). `vfox search flutter` is then cached without the OpenHarmony names for 12 hours, and `vfox config cache.availableHookDuration 0` turns the cache off.
- Installing an OpenHarmony build makes up to five attempts and waits 30, 60, 120 and 180 seconds between them after a 429, so it can wait for 6.5 minutes and print nothing.

Unreleased: release 0.2.4 waits like that for every command that lists versions, and for every install, official releases included. Measured on 2026-10-21, while gitcode.com was answering 429:

| Command | Took | Result |
| --- | --- | --- |
| `vfox search flutter` | 392 seconds | 434 official releases, no OpenHarmony ones, exit status 0 |
| `vfox install flutter@3.47.4` | 212 seconds | installed. The fourth attempt got through |

Minutes later the same API answered in a second. Without a 429 a failing request cost 10 seconds per retry, so 40 seconds in all.

## Things that look wrong and are not

- **`vfox install flutter@latest` installs `3.47.7-x64`, not `3.47.7`.** `latest` is the first line of `vfox search flutter`, the newest stable release, and it carries the architecture suffix, so the same Flutter installs twice if you also install `stable`, see [versions.md](versions.md#searching). Unreleased: release 0.2.4 installed the newest beta.
- **A version appears more than once in `vfox search flutter`.** Flutter's index lists it in more than one channel, see [versions.md](versions.md#searching).
- **Unreleased: `vfox search flutter` or `vfox install` waits for minutes and prints nothing.** Release 0.2.4 waits for gitcode.com when it limits its API, see [gitcode.com is rate-limited](#gitcodecom-is-rate-limited). The command finishes by itself.
- **`(installed)` is missing for a version you installed.** The mark follows listed names, such as `3.47.4-x64`, and not the bare name you installed. `vfox list flutter` is the truth.
- **A release you expect is missing from `vfox search`.** vfox keeps the result for 12 hours. `vfox config cache.availableHookDuration 0` turns the cache off. Flutter's index may not have it yet either, or your mirror's copy may not.
- **`3.47.4` and `3.47.4-x64` are two installs.** On an x64 machine they are the same Flutter, see [versions.md](versions.md#installed-names).
- **Uninstalling a version switched the global one.** vfox selects the first entry left in `vfox list flutter` when you uninstall the version in use, and that can be a beta.
- **`flutter` is a different Flutter than `vfox use` says.** Another Flutter earlier in your `PATH` wins, such as a manual install in `~/develop/flutter` or one from a package manager. `command -v flutter` shows which one runs, and its path should start with `~/.vfox/sdks/flutter/bin` or, in a project, `.vfox/sdks/flutter/bin`.
- **Flutter says "A new version of Flutter is available!" and suggests `flutter upgrade`.** Ignore it: `flutter upgrade` moves the SDK under vfox, see [flutter-upgrade.md](flutter-upgrade.md). `vfox install flutter@stable` is the upgrade. `flutter --no-version-check` leaves the banner out.
- **`FLUTTER_ROOT` is not set.** The plugin sets only `PATH`. The `flutter` script finds its own directory.
- **`dart` is there without a Dart plugin.** The Flutter SDK includes the Dart SDK, and `dart` is in its `bin`. There is no need to add the [vfox-dart](https://github.com/version-fox/vfox-dart) plugin next to it.
- **`.vfox-manifest` is untracked in the SDK's git.** The plugin writes it, see [flutter-upgrade.md](flutter-upgrade.md).
- **`flutter pub get` is slow or fails in China.** Packages come from `PUB_HOSTED_URL`, which the plugin does not touch, see [mirror.md](mirror.md#which-installs-use-which-mirror).
- **The first `flutter` command downloads a lot.** The Flutter tool fetches what it needs the first time you build for a platform, and it reads `FLUTTER_STORAGE_BASE_URL` for it, so keep the mirror variable set, see [mirror.md](mirror.md#what-the-variable-does).

## Where Flutter is

Each install is a directory of its own in the vfox home, `~/.vfox` unless `VFOX_HOME` is set (`storage.sdkPath` moves the SDKs elsewhere, see vfox's [configuration](https://vfox.dev/guides/configuration.html)). `vfox info flutter@3.47.4` prints the directory above the SDK, and the SDK is the `flutter-3.47.4` directory inside it:

```
$ vfox info flutter@3.47.4
/home/user/.vfox/cache/flutter/v-3.47.4
$ ls /home/user/.vfox/cache/flutter/v-3.47.4
flutter-3.47.4
```

`vfox use` also makes a link to the SDK you chose, which is the same path whichever version it points at:

| Scope | Link |
| --- | --- |
| `--global` | `~/.vfox/sdks/flutter` (`%USERPROFILE%\.vfox\sdks\flutter` on Windows) |
| `--project` | `.vfox/sdks/flutter` in the project directory |
| `--session` | `flutter` in a directory under `~/.vfox/tmp` |

`PATH` holds the `bin` directory of that link, so `flutter` and `dart` come from it. An IDE or a build tool that should follow your global choice can use the link as its Flutter SDK path (Android Studio's *Flutter SDK path*, the `dart.flutterSdkPath` setting of VS Code), and then needs no change when you switch versions. For a fixed version use the directory `vfox info` prints and its `flutter-<version>` directory. Where there is no shell hook, `vfox exec flutter@3.47.4 -- <command>` runs a command with that Flutter, see [versions.md](versions.md#using).

## Reporting a problem

Open an issue at [version-fox/vfox-flutter](https://github.com/version-fox/vfox-flutter/issues) with the output of `vfox --version` and `vfox info flutter`, the operating system and CPU, the command, and everything it printed. `vfox --debug <command>` prints more. A problem of Flutter itself belongs with [flutter/flutter](https://github.com/flutter/flutter/issues), and one of the OpenHarmony fork with [CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter).
