# About `flutter upgrade`

[中文](zh-CN/flutter-upgrade.md) | [English](flutter-upgrade.md)

The Flutter release archives this plugin installs contain a full `.git`
checkout, so `flutter upgrade` (and its siblings `flutter downgrade`,
`flutter channel`, and any `git checkout` / `git pull` run inside the SDK
directory) can move the SDK's HEAD to a newer commit in place. vfox manages
SDK versions by directory and does not track in-place mutations, so the next
`vfox use flutter@3.47.0` will silently hand you whatever the SDK has drifted
to, not 3.47.0.

Do not run `flutter upgrade` inside a vfox-managed Flutter SDK. Change
versions through vfox:

```bash
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
```

Source installs (Linux ARM64, Windows ARM64, OpenHarmony builds) are git checkouts
too, and the same goes for them.

## Recovering a drifted SDK

If you already upgraded in place, this plugin prints a warning on every
`vfox use` of that version and shows the commands that restore it:

```bash
vfox uninstall flutter@3.47.0
vfox install  flutter@3.47.0
vfox use      flutter@3.47.0
```

## The warning

This is what `vfox use flutter@3.47.4` prints once the SDK's HEAD is not the commit vfox
installed:

```
Warning: flutter SDK at ~/.vfox/cache/flutter/v-3.47.4 has drifted from the version vfox installed.
  vfox installed: flutter@3.47.4 (git HEAD 9584c6713b324636289d067944a46fd6b49df14b)
  current git HEAD: abaf9c523780a608bd46686fd5e53740a07077f8
  reason: the SDK's git HEAD no longer matches the commit vfox installed

This typically happens when `flutter upgrade` or a similar in-place command
is run inside a vfox-managed SDK. vfox manages SDK versions by directory and
does not track in-place mutations, so the version you get may differ from
the one you asked for.

To restore flutter@3.47.4:
  vfox uninstall flutter@3.47.4
  vfox install  flutter@3.47.4
  vfox use      flutter@3.47.4

To upgrade to a newer version, use vfox directly:
  vfox install flutter@<new-version>
  vfox use     flutter@<new-version>
```

There are two reasons, and the line after `reason:` says which:

| Reason | Meaning |
| --- | --- |
| `the SDK's git HEAD no longer matches the commit vfox installed` | The commit changed. This is what `flutter upgrade`, `flutter downgrade`, `flutter channel` and `git checkout` do |
| `vfox can no longer read the SDK's git HEAD (its .git may be broken)` | `git` fails in the SDK: the `.git` directory is damaged, or `git` is not installed any more |

The path in the first line is the directory that `vfox info flutter@3.47.4` prints. The
SDK is the `flutter-3.47.4` directory inside it.

## How the check works

On install the plugin writes a `.vfox-manifest` file next to the SDK's `.git`,
recording the expected git HEAD, and re-checks it on each `vfox use`.

The manifest is a small JSON file in the root of the SDK, `flutter-3.47.4/.vfox-manifest`:

```json
{"expected_head":"9584c6713b324636289d067944a46fd6b49df14b","installed_at":1792523751,"plugin":"vfox-flutter","plugin_version":"0.2.4","version":"3.47.4"}
```

`expected_head` is what `git rev-parse HEAD` printed right after vfox unpacked the SDK, and
`installed_at` is the time of the install in seconds since 1970. The check runs
`git rev-parse HEAD` again on `vfox use` and compares the two. Archive installs, source
installs and OpenHarmony builds all get a manifest. `git status` in the SDK lists the file
as untracked.

The warning is only a warning: `vfox use` still selects the version you asked
for, and exits with 0. SDKs without a `.git` directory are left alone.

Nothing is checked when there is nothing to compare with: an SDK without a manifest (one
installed by a plugin older than 0.2.3), a manifest without `expected_head` (the install
ran where `git` was missing), and a version vfox does not know are all silent.

## Disabling the check

Delete the `.vfox-manifest` file of the affected installation. The file is
written by a real install, so it comes back only after you uninstall and
reinstall that version; `vfox install` alone skips an already-installed
version and leaves it absent.

`vfox info --format '{{.Path}}' flutter@3.47.0` prints the directory above the SDK, so the
manifest is one level further down, in `flutter-3.47.0`. The directory is named after the
installed name, which carries an architecture suffix if you installed with one
(`flutter-3.47.0-x64`).

### Ubuntu 26.04.1

Execute in Bash,

```bash
rm "$(vfox info --format '{{.Path}}' flutter@3.47.0)/flutter-3.47.0/.vfox-manifest"
```

### Windows 11

Assume that PowerShell 7 is already installed. Execute in PowerShell 7,

```powershell
Remove-Item "$(vfox info --format '{{.Path}}' flutter@3.47.0)/flutter-3.47.0/.vfox-manifest"
```
