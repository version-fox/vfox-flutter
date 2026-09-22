# OpenHarmony builds

## Prerequisites

`git` is required:

1. `winget install --id Git.Git --source winget --exact` on Windows 11.

## Instructions for Use

OpenHarmony Flutter releases from
[gitcode.com](https://gitcode.com/CPF-Flutter/flutter_flutter/releases) install as
source checkouts,

```bash
vfox install flutter@3.41.10-ohos-1.0.0
vfox use --global flutter@3.41.10-ohos-1.0.0
```

Known versions are `3.41.10-ohos-1.0.0`, `3.35.8-ohos-1.0.3` and
`3.27.5-ohos-1.0.7`. List the current ones with,

```bash
vfox search flutter
```

## Limits

- **Install by exact version.** OpenHarmony versions sort after the official releases,
  so `@latest` and the `stable`/`beta`/`dev` channels never select one.
- **No architecture variants.** `flutter@3.41.10-ohos-1.0.0-x64` is not supported.
- **`linux-arm64`.** Newer releases have no published `dart-sdk-linux-arm64`, so use a
  `3.2x.x-ohos-*` version there.
- **A Windows home containing a space** (`C:\Users\John Doe\.vfox`) is not supported;
  point vfox at a path without spaces with `$env:VFOX_HOME = 'D:\vfox'`.
- **The first `flutter` command is slow.** It builds the tool and downloads the Dart SDK
  from Huawei's OBS, so it needs a network connection.
- **No checksum is verified.** Git history is the integrity check, and this is a
  third-party fork, so review its source before trusting it.
- **Mirrors don't apply.** `FLUTTER_STORAGE_BASE_URL` (see `mirror.md`) only affects
  official SDK downloads; OpenHarmony builds are cloned from gitcode, so the variable
  is ignored.

### Building OpenHarmony applications

DevEco Studio and the OpenHarmony SDK are required as well; vfox does not install them.
