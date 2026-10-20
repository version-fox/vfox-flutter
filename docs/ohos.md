# OpenHarmony builds

[中文](zh-CN/ohos.md) | [English](ohos.md)

OpenHarmony builds are a third-party fork of Flutter that targets OpenHarmony. The
plugin lists the releases of [CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter/releases)
on gitcode.com next to the official ones and installs them as source checkouts.

## Prerequisites

`git` is required:

1. `sudo apt install --assume-yes git` on Ubuntu 26.04.1
2. `winget install --id Git.Git --source winget --exact` on Windows 11

## Instructions for Use

OpenHarmony Flutter releases from
[gitcode.com](https://gitcode.com/CPF-Flutter/flutter_flutter/releases) install as
source checkouts,

```bash
vfox install flutter@3.41.10-ohos-1.0.0
vfox use --global flutter@3.41.10-ohos-1.0.0
```

The newest releases of the 3.41, 3.35 and 3.27 lines are `3.41.10-ohos-1.0.0`,
`3.35.8-ohos-1.0.3` and `3.27.5-ohos-1.0.7`, and [Names and releases](#names-and-releases)
lists all of them. List the current ones with,

```bash
vfox search flutter
```

## Names and releases

A name is a version number, `-ohos-` or `+ohos-`, and the fork's own release number: `3.41.10-ohos-1.0.0`
is release 1.0.0 of the fork's 3.41.10 line. In a `-ohos-` name the first number is the fork's own label, and
it does not always name a Flutter release: Flutter has no 3.41.10, 3.35.8, 3.27.5 or 3.22.4, and the branch
behind `3.41.10-ohos-1.0.0` is called `oh-3.41.9-release`. The fork's newer tags, from 2026-10-15, use the number
of the official release instead, with `+ohos-` after it (`3.41.9+ohos-1.0.2`). These were the 25
releases the plugin listed on 2026-10-21, newest first within each line:

| Starts with | Releases (after `-ohos-` or `+ohos-`) |
| --- | --- |
| 3.41.10-ohos- | `1.0.0`, `0.0.1-canary1` |
| 3.41.9+ohos- | `1.0.2` |
| 3.35.8-ohos- | `1.0.3`, `1.0.1`, `0.0.3` |
| 3.35.7+ohos- | `1.0.5` |
| 3.27.5-ohos- | `1.0.7`, `1.0.6`, `1.0.5`, `1.0.3`, `1.0.0` |
| 3.27.4+ohos- | `1.0.9` |
| 3.22.4-ohos- | `1.1.4`, `1.1.3` |
| 3.22.3+ohos- | `1.1.6` |
| 3.22.1-ohos- | `1.1.1`, `1.0.9`, `1.0.1`, `0.1.2`, `0.1.1` |
| 3.7.12-ohos- | `1.1.7`, `1.1.1`, `1.0.7`, `1.0.6` |

`vfox search flutter` shows them last, after every official release, each as
`3.41.10-ohos-1.0.0 (OpenHarmony)` with no Dart version. That order is why
`vfox install flutter@latest` never selects one.

The plugin recognizes a release by `-ohos-` or `+ohos-` in the name of its tag. Unreleased: release 0.2.4
knows `-ohos-` only. It lists the 21 releases above that have it, and
`vfox install flutter@3.41.9+ohos-1.0.2` ends with `no installable runtime provided`.

## How an install works

1. The plugin asks `https://gitcode.com/api/v5/repos/CPF-Flutter/flutter_flutter/releases`
   for the releases, up to five times, and finds the release by the name of its tag. Its
   `target_commitish` is the commit to install.
2. It runs `git init` in `.vfox/tmp/<name>` under `$VFOX_HOME`, or under your home
   directory when `VFOX_HOME` is not set (`~/.vfox/tmp/3.41.10-ohos-1.0.0`), then
   `git fetch --depth 1 https://gitcode.com/CPF-Flutter/flutter_flutter.git <commit>`, up to
   three times, and `git checkout FETCH_HEAD`.
3. It checks that `bin/internal/engine.version` exists, and hands the directory to vfox,
   which moves it to the install location.

The result is a shallow clone of one commit, 224 MB for 3.41.10-ohos-1.0.0, and the install
took 19 seconds on a fast connection. An install waits for gitcode.com: when its API answers
HTTP 429 (rate limited) the plugin waits 30, 60, 120 and 180 seconds between its five attempts,
and ten seconds between attempts after any other error.

`vfox search flutter` asks the same API for the list of releases, but it does not wait for it:
two attempts, two seconds apart, and HTTP 429 ends them. When the API does not answer, the list
has no OpenHarmony names and says so on stderr. Installing an official release does not ask
gitcode.com at all. Unreleased: release 0.2.4 asks it with the same five attempts for every
command that lists versions, and for every install of an official release.

## Limits

- **Install by exact version.** OpenHarmony versions sort after the official releases,
  so `@latest` never selects one. The `stable` and `beta` channels (see [channels.md](channels.md))
  resolve through Flutter's official release index, which lists no OpenHarmony builds.
- **No architecture variants.** `flutter@3.41.10-ohos-1.0.0-x64` is not supported, it fails
  with `flutter 3.41.10-ohos-1.0.0 has no architecture variants`.
- **Only the names above.** `flutter@3.47.7-ohos-1.0.0` fails with
  `flutter 3.47.7-ohos-1.0.0 is not an OpenHarmony release`.
- **`linux-arm64` and `windows-arm64`.** Upstream publishes only x64 Dart SDKs, so the first
  `flutter` run fails there (`It appears that the downloaded file is corrupt`).
  The ARM64 e2e runs the official flavor only.
- **The first `flutter` command is slow.** It builds the tool and downloads the Dart SDK
  from Huawei's OBS, so it needs a network connection.
- **No checksum is verified.** Git history is the integrity check, and this is a
  third-party fork, so review its source before trusting it.
- **Mirrors don't apply.** `FLUTTER_STORAGE_BASE_URL` and `VFOX_FLUTTER_GITHUB_MIRROR` (see [mirror.md](mirror.md)) only affect
  official SDK downloads; OpenHarmony builds are cloned from gitcode, so both variables
  are ignored.
- **Stalled clones are retried.** A fetch from gitcode that stalls (under 1 KB/s for a
  minute) is abandoned and retried, up to three attempts; `GIT_HTTP_LOW_SPEED_LIMIT` /
  `GIT_HTTP_LOW_SPEED_TIME` change the threshold.
- **gitcode.com rate-limits its API.** An install of an OpenHarmony build waits for it, see
  above. See [troubleshooting.md](troubleshooting.md#gitcodecom-is-rate-limited).
- **Line endings.** The checkout sets `core.autocrlf=false`. Unreleased: release 0.2.4 takes your
  git configuration, and with `core.autocrlf=true` a checkout on Linux has CRLF line endings in
  `bin/internal/shared.sh`, so that `flutter` stops with `$'\r': command not found`, see
  [arm64.md](arm64.md#limits).

### Building OpenHarmony applications

DevEco Studio and the OpenHarmony SDK are required as well; vfox does not install them.
