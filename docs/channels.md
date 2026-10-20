# Channels

[中文](zh-CN/channels.md) | [English](channels.md)

`stable` and `beta` install the release the channel currently points to, and also accept an architecture suffix such as `stable-x64` (see [arm64.md](arm64.md)):

```bash
vfox install flutter@stable
```

On 2026-10-21 `stable` pointed to 3.47.7 and `beta` to 3.50.0-0.1.pre.

## How a channel is resolved

Flutter's release index (`releases_linux.json`, `releases_macos.json` and `releases_windows.json`, see [versions.md](versions.md#installing)) names the commit each channel points to under `current_release`. The plugin reads that commit and installs the release built from it. When the request has an architecture suffix, or the machine has more than one build of the commit (macOS has an x64 and an arm64 archive of every recent release), the plugin takes the build for that architecture:

| You run | Installs |
| --- | --- |
| `vfox install flutter@stable` | the stable release, for the architecture of this machine, as `3.47.7` |
| `vfox install flutter@stable-x64` | the x64 build of it, as `3.47.7-x64` |
| `vfox install flutter@stable-arm64` | the arm64 build of it, as `3.47.7-arm64`, where there is one, see [arm64.md](arm64.md) |
| `vfox install flutter@beta` | the beta release, as `3.50.0-0.1.pre` |

A channel request reads the release index once more than a version request does, and it does so without retrying. A mirror (see [mirror.md](mirror.md)) serves its own copy of the index, so the channel points to what that copy says. Google's, CFUG's and CERNET's copies agreed on 2026-10-21.

## What you get

- **Resolved at install time.** The SDK is installed under the version the channel points to, such as `flutter@3.47.7` (`flutter@3.47.7-x64` for `stable-x64`), and vfox prints that version when the install finishes:

  ```
  $ vfox install flutter@stable
  Preinstalling flutter@3.47.7...
  ...
  Install flutter@3.47.7 success!
  Please use `vfox use flutter@3.47.7` to use it.
  ```

- **Use the version, not the channel.** The channel name is not an installed name, see below.
- **Channels are not followed.** Once the channel moves to a new release, `vfox install flutter@stable` installs it next to the old one; switch to it with `vfox use`. Nothing changes the SDK you already use.

## Use the version, not the channel

vfox only knows installed names. A channel is replaced by a release while the plugin installs, so afterwards there is no `stable` in `vfox list flutter`, and everything that looks an installed name up fails with it:

- `vfox use flutter@stable` fails with `flutter@stable is not installed`; run `vfox use --global flutter@3.47.7` instead.
- `vfox uninstall flutter@stable` fails the same way; `vfox uninstall` takes the version as well.
- `vfox exec flutter@stable -- flutter --version` installs the release (or finds it installed), prints `failed to get runtime package for flutter@stable: open .../cache/flutter/v-stable: no such file or directory`, exits with 1 and does not run the command. Write `vfox exec flutter@3.47.7 -- flutter --version`.
- `stable` in a `.vfox.toml` or a `.tool-versions` selects nothing: `vfox current` shows `flutter -> N/A` and `flutter` comes from the next scope. A project file needs the version.

The version a channel stands for is the newest `(stable)` or `(beta)` line of `vfox search flutter` in practice, see [versions.md](versions.md#searching). To keep a project on one Flutter whatever the channel does, pin the version with `vfox use --project flutter@3.47.7` and commit the `.vfox.toml` it writes.

## `latest` is not a channel

`vfox install flutter@latest` is vfox's own shorthand for the first line of `vfox search flutter`. That line is the newest stable release, with an architecture suffix (`3.47.7-x64` on 2026-10-21), so `latest` and `stable` install the same Flutter under different names (`3.47.7-x64` and `3.47.7`). Prefer `stable`, see [versions.md](versions.md#searching). Unreleased: release 0.2.4 lists the pre-releases among the stable releases by their numbers, so its first line is the newest beta, and its `latest` installed `3.50.0-0.1.pre-x64`.

## `dev`

Flutter retired the `dev` channel, whose last release is `2.13.0-0.1.pre` from April 2022, so the plugin does not accept it. `releases_<os>.json` still names a commit for it under `current_release`, but the plugin no longer looks at that entry, and `vfox install flutter@dev` ends with:

```
no installable runtime provided
failed to install flutter
```

Releases that were published to `dev` in the past are still listed by their version, such as `2.13.0-0.1.pre`, with `(dev)` after it in `vfox search flutter`.
