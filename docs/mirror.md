# Mirror

[中文](zh-CN/mirror.md) | [English](mirror.md)

By default, Flutter SDK is downloaded from `https://storage.googleapis.com`.
If you have difficulty accessing it, you can set the `FLUTTER_STORAGE_BASE_URL` environment variable to use a mirror.

Common mirror values:

| Mirror                                        | URL                                     |
|-----------------------------------------------|-----------------------------------------|
| CFUG (China Flutter User Group)               | `https://storage.flutter-io.cn`         |
| CERNET (China Education and Research Network) | `https://mirrors.cernet.edu.cn/flutter` |

For an up-to-date list of available mirrors, refer to the MirrorZ Help
site: https://help.mirrors.cernet.edu.cn/flutter/ .

## What the variable does

`FLUTTER_STORAGE_BASE_URL` is Flutter's own variable, and it matters in three places:

- **The plugin reads the release index from it**: `<mirror>/flutter_infra_release/releases/releases_linux.json`
  (`releases_macos.json` and `releases_windows.json` on those systems). The index decides
  what `vfox search flutter` lists and what a channel stands for, see
  [channels.md](channels.md).
- **The archive comes from it.** The plugin builds the address that vfox downloads from the
  index's `archive` field, `<mirror>/flutter_infra_release/releases/<archive>`, and does not
  use the `base_url` that the index itself carries. The checksum is the one from the same
  index.
- **The `flutter` tool reads it too.** Downloads that the tool makes itself, such as the
  Dart SDK of a source install (see [arm64.md](arm64.md)) and engine artifacts, go through
  it. That is why it has to stay set in your shell, not only while you run `vfox install`.

A trailing slash is removed, so `https://storage.flutter-io.cn/` works, and an empty value
counts as unset. A mirror has to keep Google's layout under `flutter_infra_release/` and
answer for the index and the archives. The mirror's index is the list of what you can
install: a release it has not copied yet is missing, and `stable` points where its copy
says. On 2026-10-21 Google, CFUG and CERNET served the same index.

To check a mirror before you use it, ask it for the index of your system:

```bash
curl --fail --silent --show-error --location --output /dev/null \
  https://storage.flutter-io.cn/flutter_infra_release/releases/releases_linux.json
```

The test suite runs the same request against `https://storage.flutter-io.cn` before it
installs through it.

## Which installs use which mirror

| Install | Release index | Download |
| --- | --- | --- |
| Archive: Linux x64, macOS, Windows x64, and `-x64` anywhere | `FLUTTER_STORAGE_BASE_URL` | `FLUTTER_STORAGE_BASE_URL` |
| Source: Linux ARM64 and Windows ARM64 | `FLUTTER_STORAGE_BASE_URL` | GitHub, with `VFOX_FLUTTER_GITHUB_MIRROR` |
| OpenHarmony | gitcode.com, no mirror | gitcode.com, no mirror |

Installing an OpenHarmony build does not read the release index at all, but
`vfox search flutter` does, because it lists the official releases next to them.
`PUB_HOSTED_URL`, the address that `flutter pub get` fetches packages from, is not read by
the plugin. If you use CFUG's mirror, Flutter's
[guide for China](https://docs.flutter.dev/community/china) sets it to
`https://pub.flutter-io.cn` next to `FLUTTER_STORAGE_BASE_URL`.

## Ubuntu 26.04.1

For Bash, 

1. You can make the setting take effect temporarily in the current shell using the following command.

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

2. To ensure that environment variables always take effect, you can perform the following steps:

```bash
sudo tee /etc/profile.d/myenvvars.sh <<EOF
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
EOF

source /etc/profile.d/myenvvars.sh
```

A file in `/etc/profile.d` is read by login shells, so other terminals pick it up after you
log in again.

## macOS

For zsh, add the line to `~/.zshrc` and open a new terminal:

```bash
echo 'export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn' >> ~/.zshrc
```

## Windows 11

For PowerShell 7,

1. You can make the setting take effect temporarily in the current shell using the following command.

```powershell
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

2. To ensure that environment variables always take effect, you can perform the following steps:

```powershell
[Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL', 'https://storage.flutter-io.cn', 'Machine')
```

The `Machine` scope needs a PowerShell started as administrator, and applies to programs
you start afterwards. Use `'User'` instead to set it for your account only.

## GitHub mirror for source installs

On Linux ARM64 and Windows ARM64,
the plugin installs Flutter from git source instead of a prebuilt archive.
If you have difficulty accessing `https://github.com`,
you can set the `VFOX_FLUTTER_GITHUB_MIRROR` environment variable to use a mirror
instead. The value is a URL prefix that is prepended to the GitHub URL.

Common mirror values:

| Mirror               | Value                    |
|----------------------|--------------------------|
| gh-proxy             | `https://gh-proxy.org/`  |

For Bash,

1. You can make the setting take effect temporarily in the current shell using the following command.

```bash
export VFOX_FLUTTER_GITHUB_MIRROR=https://gh-proxy.org/
```

2. To ensure that environment variables always take effect, you can perform the following steps:

```bash
sudo tee /etc/profile.d/myenvvars.sh <<EOF
export VFOX_FLUTTER_GITHUB_MIRROR="https://gh-proxy.org/"
EOF

source /etc/profile.d/myenvvars.sh
```

For PowerShell 7,

1. You can make the setting take effect temporarily in the current shell using the following command.

```powershell
$env:VFOX_FLUTTER_GITHUB_MIRROR = "https://gh-proxy.org/"
```

2. To ensure that environment variables always take effect, you can perform the following steps:

```powershell
[Environment]::SetEnvironmentVariable('VFOX_FLUTTER_GITHUB_MIRROR', 'https://gh-proxy.org/', 'Machine')
```

The mirror only rewrites URLs that start with `https://github.com/`,
so the `FLUTTER_STORAGE_BASE_URL` variable above is unaffected.

A value without a trailing slash gets one, and the install prints the address it
clones from:

```
Using GitHub mirror https://gh-proxy.org/https://github.com/flutter/flutter.git
```

Only the clone of `flutter/flutter` goes through it. The mirror has to be a service that
takes the full GitHub address after its prefix, as gh-proxy does. A mirror that does not
answer makes the install fail with `failed to fetch tag 3.47.4 from <address>`, after three
attempts, see [troubleshooting.md](troubleshooting.md#source-installs-linux-arm64-and-windows-arm64).

## Proxies

A proxy is not a mirror. vfox's own proxy setting covers the plugin's requests and the
archive download, and `git` reads its own (`HTTPS_PROXY`, `http.proxy`), see
[troubleshooting.md](troubleshooting.md#network).
