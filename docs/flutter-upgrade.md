# About `flutter upgrade`

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

## Recovering a drifted SDK

If you already upgraded in place, this plugin prints a warning on every
`vfox use` of that version and shows the commands that restore it:

```bash
vfox uninstall flutter@3.47.0
vfox install  flutter@3.47.0
vfox use      flutter@3.47.0
```

## How the check works

On install the plugin writes a `.vfox-manifest` file next to the SDK's `.git`,
recording the expected git HEAD, and re-checks it on each `vfox use`.

The warning is only a warning: `vfox use` still selects the version you asked
for. SDKs without a `.git` directory are left alone.

## Disabling the check

Delete the `.vfox-manifest` file of the affected installation. The file is
written by a real install, so it comes back only after you uninstall and
reinstall that version; `vfox install` alone skips an already-installed
version and leaves it absent.

### Ubuntu 26.04.1

Execute in Bash,

```bash
find ~/.vfox/cache/flutter/v-3.47.0 -name .vfox-manifest -print -delete
```

### Windows 11

Assume that PowerShell 7 is already installed. Execute in PowerShell 7,

```powershell
Get-ChildItem "$env:USERPROFILE\.vfox\cache\flutter\v-3.47.0" -Recurse -Force -Filter .vfox-manifest |
    Remove-Item
```
