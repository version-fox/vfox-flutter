# vfox-flutter

[中文](README_CN.md) | [English](README.md)

[Flutter](https://flutter.dev/) plugin for [vfox](https://vfox.dev/).

It installs the Flutter SDK from the release archives that Google publishes for Linux x64, macOS
and Windows x64, checked against the SHA-256 checksums of Flutter's release index. On Linux ARM64
and Windows ARM64, where there is no archive, it installs the official `flutter/flutter` git tag
instead. It also installs the OpenHarmony builds of Flutter from gitcode.com.

## Install

After installing [vfox](https://github.com/version-fox/vfox), install the plugin by running:

```bash
vfox add flutter
```

vfox has to be hooked into your shell for `flutter` to be on the `PATH`, see its
[quick start](https://vfox.dev/guides/quick-start.html).

The Flutter SDK includes the Dart SDK; 
if you install the Flutter SDK via the current vfox plugin, 
there is no need to separately install the Dart SDK using the vfox plugin from 
https://github.com/version-fox/vfox-dart .

### Example: Ubuntu 26.04.1

```bash
vfox add flutter
vfox install flutter@3.47.4
sudo apt install --assume-yes curl git unzip xz-utils zip libglu1-mesa
vfox use --global flutter@3.47.4
```

You can verify this using the following command:

```bash
flutter --version --no-version-check
dart --version
```

`vfox search flutter` lists the versions you can install. In an interactive terminal it lets you
pick one and installs it.

Behavior that only exists on `main` and not in the latest release is marked "Unreleased" in the
pages below. [docs/changes.md](docs/changes.md) lists it, and
[docs/install-from-source.md](docs/install-from-source.md) gets you `main`.

## Versions and names

A version is a release as `vfox search flutter` prints it: `3.47.4`, or a beta such as
`3.50.0-0.1.pre`. `-x64` or `-arm64` after it asks for that architecture instead of the
machine's, and `stable` and `beta` stand for the release the channel points to. Versions are
matched whole, so `flutter@3.47` does not select the newest 3.47.x. `vfox use`, `vfox uninstall`
and `vfox exec` take the name that is installed, as `vfox list flutter` shows it.
`flutter@latest` is the first line of the list, the newest stable release. See
[docs/versions.md](docs/versions.md) for the names, how installs are named and the order of the
list.

## Channels

`vfox install flutter@stable` and `flutter@beta` install the release the channel points to today,
and name the install after that release (`3.47.7`), so `vfox use flutter@stable` fails: use the
version. Flutter retired the `dev` channel. See [docs/channels.md](docs/channels.md) for details.

## Platforms

Linux, macOS and Windows on x64 and ARM64. See [docs/platforms.md](docs/platforms.md) for what
installs from where, what vfox and `git` have to be there, which hosts the plugin connects to
and what the tests cover.

## Architecture selection

`flutter@3.47.4-x64` and `flutter@3.47.4-arm64` install a specific build, and a plain name takes
the one for the machine. Linux ARM64 and Windows ARM64 install from a git tag, and offer the
releases that run with a native Dart SDK. See [docs/arm64.md](docs/arm64.md) for details.

## Mirror

`FLUTTER_STORAGE_BASE_URL` selects a mirror such as CFUG's or CERNET's for the release index and the
archives, and `VFOX_FLUTTER_GITHUB_MIRROR` one for the GitHub clone of the source installs. See
[docs/mirror.md](docs/mirror.md) for details.

## OpenHarmony builds

`vfox install flutter@3.41.10-ohos-1.0.0` installs the OpenHarmony fork of Flutter from gitcode.com
as a git checkout. These builds are listed after the official releases, and `@latest` never
selects one. See [docs/ohos.md](docs/ohos.md) for details.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for the messages the plugin and vfox print,
proxies, a rate-limited gitcode.com, the things that look wrong and are not, and where Flutter is.

## FAQ

### About `flutter upgrade`

See [docs/flutter-upgrade.md](docs/flutter-upgrade.md) for details.

### Install from source

See [docs/install-from-source.md](docs/install-from-source.md) for details.

### Development

See [docs/development.md](docs/development.md) for how the plugin works and how to change it, and
[docs/e2e.md](docs/e2e.md) for the container tests.

### Changes

See [docs/changes.md](docs/changes.md) for what changed in each release.

## Releasing this plugin

Maintainers can publish from **Actions → Plugin → Run workflow** on the default
branch by entering a stable plugin version without the `v` prefix. The shared
workflow updates `metadata.lua`, creates the version commit and tag, and publishes
the ZIP and manifest in this repository. No local tag or extra release token is
needed. Pull requests run checks only; PR titles no longer trigger publication.

Existing version-tag pushes are supported when `PLUGIN.version` already matches
the tag. If publication fails, re-run the original failed job to resume it.

The workflow follows the shared `@v1` release-tool version. Updating the tool does
not release this plugin. See the [shared workflow documentation](https://github.com/version-fox/plugin-manifest-action)
for the package contract and first-rollout requirements.

## Thanks

- [Flutter](https://github.com/flutter/flutter), whose release index and archives the plugin installs from
- [CFUG and CERNET](docs/mirror.md), whose mirrors of Flutter's storage the plugin can use
- [CPF-Flutter](https://gitcode.com/CPF-Flutter/flutter_flutter), whose OpenHarmony builds of Flutter the plugin installs
