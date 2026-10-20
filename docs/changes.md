# Changes

[中文](zh-CN/changes.md) | [English](changes.md)

What changed in each release, as a user notices it. GitHub's release pages and the pull requests linked below have the rest. The newest release is 0.2.5. When `main` is ahead of it, the changes it has are listed first, under "Unreleased", and [install-from-source.md](install-from-source.md) gets you those now.

## 0.2.5 (2026-10-21)

- Installing an official release no longer asks gitcode.com ([#50](https://github.com/version-fox/vfox-flutter/pull/50)). Release 0.2.4 asked it for every install, and when gitcode.com rate-limited its API (HTTP 429) an install or a `vfox search` waited up to 6.5 minutes and printed nothing: 212 and 392 seconds on 2026-10-21. `vfox search` and the `latest` of `vfox install` still list the OpenHarmony releases, but they make two attempts, give up at HTTP 429, and print a warning on stderr when they get no list. Installing an OpenHarmony build waits as before. See [troubleshooting.md](troubleshooting.md#gitcodecom-is-rate-limited).
- `3.13.3`, `3.9.0-0.1.pre` and `3.17.0-0.0.pre` install ([#50](https://github.com/version-fox/vfox-flutter/pull/50)). Flutter uploaded their files again and left the old checksums in the index next to the new ones, and release 0.2.4 could take an old one and end with `checksum error`. The list keeps the newest entry of an archive now, which has the checksum of the file. See [troubleshooting.md](troubleshooting.md#checksum-error).
- OpenHarmony builds that are tagged `+ohos-` are listed and install ([#50](https://github.com/version-fox/vfox-flutter/pull/50)): `3.41.9+ohos-1.0.2`, `3.35.7+ohos-1.0.5`, `3.27.4+ohos-1.0.9` and `3.22.3+ohos-1.1.6`. See [ohos.md](ohos.md#names-and-releases).
- The checkout of a source install sets `core.autocrlf=false` ([#50](https://github.com/version-fox/vfox-flutter/pull/50)). With a global `core.autocrlf=true` release 0.2.4 wrote Flutter's shell scripts with CRLF line endings on Linux, for Linux ARM64 and for OpenHarmony builds, and `flutter` stopped with `bin/internal/shared.sh: line 5: $'\r': command not found`. See [arm64.md](arm64.md#limits).
- Linux ARM64 and Windows ARM64 offer a `-arm64` source install only from the first release that runs with a native Dart SDK there, Flutter 2.2.0 and 3.44.0-0.1.pre ([#50](https://github.com/version-fox/vfox-flutter/pull/50)). Release 0.2.4 offered older ones too, with the x64 Dart SDK: an ARM64 Linux machine does not run it, and Windows runs it through its emulation under a name that says arm64. The `-x64` archives of those releases are still listed. See [arm64.md](arm64.md#releases-that-run-natively).
- `vfox search` lists the stable releases before the pre-releases ([#50](https://github.com/version-fox/vfox-flutter/pull/50)), so `vfox install flutter@latest` installs the newest stable release (`3.47.7-x64` on 2026-10-21) and not the newest beta (`3.50.0-0.1.pre-x64`). See [versions.md](versions.md#searching).
- The message for a CPU the plugin does not support has its spaces: `flutter does not support the arm architecture` ([#50](https://github.com/version-fox/vfox-flutter/pull/50)).

## 0.2.4 (2026-10-17)

- The `dev` channel is gone. Flutter retired it (its last release is `2.13.0-0.1.pre` from April 2022), and `vfox install flutter@dev` no longer resolves. `stable` and `beta` are documented in [channels.md](channels.md) ([#47](https://github.com/version-fox/vfox-flutter/pull/47)).
- Windows accounts whose home directory contains a space, such as `C:\Users\John Doe`, work with vfox 1.0.13 or later ([#48](https://github.com/version-fox/vfox-flutter/pull/48)).
- A `git fetch` that stalls, under 1 KB/s for a minute, is abandoned and tried again, up to three times. It applies to the source installs of Linux ARM64 and Windows ARM64 and to OpenHarmony builds ([#49](https://github.com/version-fox/vfox-flutter/pull/49)).

## 0.2.3 (2026-10-10)

- Linux ARM64 ([#23](https://github.com/version-fox/vfox-flutter/pull/23)) and Windows ARM64 ([#24](https://github.com/version-fox/vfox-flutter/pull/24)) install the official `flutter/flutter` git tag, since Google publishes no archive for them. See [arm64.md](arm64.md).
- OpenHarmony builds from gitcode.com, such as `3.41.10-ohos-1.0.0` ([#16](https://github.com/version-fox/vfox-flutter/pull/16)). Fixes for installing them on Windows ([#17](https://github.com/version-fox/vfox-flutter/pull/17), [#18](https://github.com/version-fox/vfox-flutter/pull/18)), and a wait before the next attempt when gitcode.com answers with HTTP 429 ([#31](https://github.com/version-fox/vfox-flutter/pull/31)). See [ohos.md](ohos.md).
- `vfox use` warns when `flutter upgrade` or a similar command has moved a vfox-managed SDK to another commit, and shows the commands that restore it ([#27](https://github.com/version-fox/vfox-flutter/pull/27)). See [flutter-upgrade.md](flutter-upgrade.md).
- The first `flutter` run after an install from an archive no longer rebuilds the Flutter tool ([#39](https://github.com/version-fox/vfox-flutter/pull/39), [#37](https://github.com/version-fox/vfox-flutter/issues/37)).
- `VFOX_FLUTTER_GITHUB_MIRROR` mirrors the GitHub clone of the source installs ([#34](https://github.com/version-fox/vfox-flutter/pull/34), which replaced the automatic fallback of [#29](https://github.com/version-fox/vfox-flutter/pull/29)). A fetch that fails is tried up to three times. See [mirror.md](mirror.md).
- The release index is asked up to three times, five seconds apart, and the error names the HTTP status ([#24](https://github.com/version-fox/vfox-flutter/pull/24)).
- `vfox add flutter` prints a link to the README ([#30](https://github.com/version-fox/vfox-flutter/pull/30)).

## 0.2.2 (2026-09-12)

- Every architecture variant is listed, such as `3.47.4-x64` and `3.47.4-arm64`, so you can install either and switch between them. Plain names keep the architecture of the machine and their installed names ([#6](https://github.com/version-fox/vfox-flutter/pull/6)). See [arm64.md](arm64.md).

## 0.2.1 (2026-09-12)

- `FLUTTER_STORAGE_BASE_URL` selects a mirror for the release index and the archives ([#8](https://github.com/version-fox/vfox-flutter/pull/8)), and the list of mirrors is up to date ([#10](https://github.com/version-fox/vfox-flutter/pull/10)). See [mirror.md](mirror.md).

## 0.2.0 (2024-07-01)

- macOS gets the build for its architecture, Apple silicon or Intel, and the list is sorted with the newest release first ([#3](https://github.com/version-fox/vfox-flutter/pull/3)).

## 0.1.x (2024-04-01)

- 0.1.0 is the first release. It lists the releases of Flutter's index for the operating system, installs the archive and verifies its SHA-256 checksum, and knows the `stable`, `beta` and `dev` channels.
- 0.1.1 changes the version number only.
