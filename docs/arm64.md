# Architecture selection

[中文](zh-CN/arm64.md) | [English](arm64.md)

Available releases include architecture suffixes such as `3.47.4-arm64` and
`3.47.4-x64`. You can install both builds and switch between them. On an Apple
silicon Mac:

```bash
vfox install flutter@3.47.4-arm64
vfox install flutter@3.47.4-x64
vfox use --global flutter@3.47.4-x64
```

Commands without an architecture, such as `vfox install flutter@3.47.4` or
`vfox install flutter@stable`, continue to select the host architecture and keep
their existing version names. Channels also accept a suffix, such as
`vfox install flutter@stable-x64`. The version list shows the default architecture
first, followed by other architectures, with each group ordered by version.
This keeps `@latest` on the default architecture.

Only architectures provided by Flutter for the current operating system are listed.
A request for another one fails with `no installable runtime provided`.

## What each machine gets

| Machine | `3.47.4`, `stable` | `3.47.4-x64` | `3.47.4-arm64` |
| --- | --- | --- | --- |
| Linux x64 | the Linux archive | the same archive, installed as `3.47.4-x64` | not offered |
| Linux ARM64 | a source install of the git tag | the Linux x64 archive, which does not run here | a source install, named `3.47.4-arm64` |
| macOS Apple silicon | the arm64 archive | the x64 archive, which needs Rosetta | the arm64 archive, named `3.47.4-arm64` |
| macOS Intel | the x64 archive | the same archive, named `3.47.4-x64` | the arm64 archive, which does not run here |
| Windows x64 | the Windows archive | the same archive, installed as `3.47.4-x64` | not offered |
| Windows ARM64 | a source install of the git tag | the Windows x64 archive | a source install, named `3.47.4-arm64` |

The names in the last two columns are the installed names, see
[versions.md](versions.md#installed-names). Installing `3.47.4` and `3.47.4-x64` on an
x64 machine gives two installs of the same Flutter. Write the suffix always or never.

## Releases without architecture metadata

Flutter's release index gives an architecture (`dart_sdk_arch`) for most releases,
and none for some old ones. On 2026-10-21 these were the stable releases `1.17.0`
to `1.17.5`, `1.22.5` and `1.22.6`, and the pre-releases up to `2.10.0-0.3.pre`,
114 versions in all. The plugin lists them without a suffix on every machine and
installs the one archive Flutter published, an x64 build:

```bash
vfox install flutter@1.22.6
```

They are never offered as `-arm64` or `-x64`, so `vfox install flutter@1.22.6-arm64` and
`vfox install flutter@1.22.6-x64` fail. Because they count as the default
architecture, they sort among the native builds and not after the foreign ones.
On Linux ARM64 and Windows ARM64 they get no source install either (see
[Limits](#limits)), so `vfox install flutter@1.22.6` installs the x64 archive there.

## macOS

### Apple silicon

Running an x64 build requires Rosetta.

Flutter published arm64 builds from `2.12.0-4.1.pre` (pre-releases) and `3.0.0`
(stable) on. An older release has an x64 build only, and the plain name does not fall
back to it, so ask for it:

```bash
vfox install flutter@2.10.5-x64
```

`vfox install flutter@2.10.5` fails with `no installable runtime provided`.

### Intel

The macOS release index holds arm64 builds whatever the Mac, so they are listed on an
Intel Mac too, and `vfox install flutter@3.47.4-arm64` installs one. It cannot run on an
Intel Mac.

## Linux ARM64

On Linux ARM64 the plugin installs the official `flutter/flutter` git tag
instead of a prebuilt bundle. The Flutter tool bootstraps the matching native
`dart-sdk-linux-arm64` itself on first run, so the result is a native SDK.

Explicit `-x64` requests still resolve to the upstream archive, which cannot
run on Linux ARM64.

## Windows ARM64

On Windows ARM64 the plugin installs the official `flutter/flutter` git tag
instead of a prebuilt bundle, for the same reason as Linux ARM64: upstream
publishes no `windows-arm64` archives. The Flutter tool bootstraps the matching
native `dart-sdk-windows-arm64` itself on first run, so the result is a native
SDK.

Explicit `-x64` requests still resolve to the upstream x64 archive. It is not a
native build, and the plugin's tests do not run it.

## How a source install works

Linux ARM64 and Windows ARM64 list a `-arm64` source install for the releases that have
an x64 build and run with a native Dart SDK (288 on Linux and 37 on Windows on 2026-10-21),
taken from the same release index, see [Releases that run natively](#releases-that-run-natively).
Installing one:

1. starts from an empty directory `.vfox/tmp/<name>` under `$VFOX_HOME`, or under your
   home directory when `VFOX_HOME` is not set (`~/.vfox/tmp/3.47.4`, and for
   `3.47.4-arm64` `~/.vfox/tmp/3.47.4-arm64`),
2. runs `git init` there and sets `core.longpaths=true` and `core.autocrlf=false`,
3. runs `git fetch --depth 1 https://github.com/flutter/flutter.git refs/tags/3.47.4`,
   up to three times,
4. checks out `FETCH_HEAD` and checks that `bin/internal/engine.version` exists,
5. hands the directory to vfox, which moves it to the install location (vfox prints
   `Moving ... to ...`).

The result is a shallow clone of one commit, checked out at a tag and not on a branch.
It is about 225 MB, and fetching it for 3.47.7 took 10 seconds on a fast connection. That
checkout is also why `flutter --version` on such an install says `channel [user-branch]`
and `unknown source`, and not `channel stable`.

A failed install leaves the directory behind. The next install of the same name starts
by deleting it, and it is safe to delete yourself.

## Releases that run natively

The point of an `-arm64` source install is a native Dart SDK. The Flutter tool takes the ARM64
Dart SDK on its first run only when two things hold: the release's own bootstrap script
(`bin/internal/update_dart_sdk.sh`, `update_dart_sdk.ps1` on Windows) has to ask for it, and
Flutter's storage has to have it (`dart-sdk-<os>-arm64.zip` under the engine revision of the
release). This is the oldest release for which both hold, checked on 2026-10-21 for the 300
releases that have an x64 build:

| Machine | Native Dart SDK from | Before it |
| --- | --- | --- |
| Linux ARM64 | Flutter 2.2.0 | The script asks for the x64 SDK, `1.20.0` to `2.0.6` (17 releases). Storage has the ARM64 SDK from 2.0.0 on, but these scripts do not ask for it, and an ARM64 machine does not run the x64 SDK |
| Windows ARM64 | Flutter 3.44.0-0.1.pre | The script asks for the ARM64 SDK from `3.20.0-1.1.pre` on and, when storage has none, says `The current channel's Dart SDK does not support Windows Arm64, falling back to Windows x64...` and takes the x64 SDK, which Windows runs through its emulation. Storage has the ARM64 SDK for seven older betas, three of which the tool would use (`3.20.0-1.1.pre`, `3.21.0-0.0.pre` and `3.30.0-0.1.pre`) |

The plugin offers a `-arm64` source install from that release on. `vfox install flutter@1.20.0`
on Linux ARM64, and `vfox install flutter@3.43.0-0.3.pre` on Windows ARM64, end with
`no installable runtime provided`. The x64 archives of the older releases are still listed:
`vfox install flutter@3.43.0-0.3.pre-x64` installs one, which Windows ARM64 runs emulated,
and `flutter@1.20.0-x64` on Linux ARM64 is for where you can run x64 programs. The table is
data in `lib/source.lua`, and [development.md](development.md#refreshing-the-dart-sdk-table)
shows how to check it.

## Limits

### Linux ARM64 and Windows ARM64

- **`git` is required.** The checkout runs `git init` / `fetch` / `checkout`
  against `https://github.com/flutter/flutter.git`. A fetch that stalls (under
  1 KB/s for a minute) is abandoned and retried, up to three attempts;
  `GIT_HTTP_LOW_SPEED_LIMIT` / `GIT_HTTP_LOW_SPEED_TIME` change the threshold.
- **The first `flutter` run is slow.** It downloads the native Dart SDK and
  builds the Flutter tool, so it needs a network connection.
- **No checksum is verified.** Git history is the integrity check.
- **No `-arm64` variants for legacy releases.** Versions without architecture
  metadata (such as `1.22.6`, see above) keep their existing x64-only behavior.
- **Mirrors don't apply to the clone.** `FLUTTER_STORAGE_BASE_URL`
  (see [mirror.md](mirror.md)) only affects the release index, the x64 archives and the
  Flutter tool's own downloads; source installs clone from GitHub. Set
  `VFOX_FLUTTER_GITHUB_MIRROR` (see [mirror.md](mirror.md)) to mirror the GitHub source
  install.
- **Old releases are not offered.** They do not run with a native Dart SDK, see [Releases
  that run natively](#releases-that-run-natively).
- **Your git configuration applies.** The plugin runs `git` as you do, except for line
  endings: it sets `core.autocrlf=false` in the checkout, so that a global `true` (which the Git
  for Windows installer proposes by default) cannot write Flutter's shell scripts with CRLF
  line endings. Flutter's `.gitattributes` forces LF only for `bin/flutter`, `bin/flutter-dev`
  and `bin/dart`, so with `true` the checkout of a Linux ARM64 install or of an OpenHarmony
  build on Linux would have CRLF in `bin/internal/shared.sh` and Flutter's other `.sh` files,
  and the first `flutter` run would stop with
  `bin/internal/shared.sh: line 5: $'\r': command not found`. Releases before 0.2.5 take your
  setting, see
  [troubleshooting.md](troubleshooting.md#bininternalsharedsh-line-5-r-command-not-found).
- **Leftovers.** A failed install leaves `.vfox/tmp/<name>` behind, see
  [How a source install works](#how-a-source-install-works).
