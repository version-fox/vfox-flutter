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

If you already upgraded in place, restore the version with:

```bash
vfox install --reinstall flutter@3.47.0
```

`vfox doctor` reports the same finding (`sdk.drift`), and a linked SDK that
changed reports it as a notice only: vfox does not own that SDK.

## The warning

This needs vfox 1.1.0 or later, which records the installation and compares it
again on every `vfox use`. This is what `vfox use flutter@3.47.4` prints once
the SDK's HEAD is not the commit vfox installed:

```
flutter@3.47.4 has changed since vfox installed it (head: 9584c6713b32… -> abaf9c523780…).
  Something modified the SDK in place, for example a self-update command. vfox manages versions by directory and does not track that.
  To move to a newer version, install it with vfox instead: vfox install flutter@<new-version>
  Fix: vfox install --reinstall flutter@3.47.4
```

The `head:` part names the recorded commit first and the current one second,
both shortened. When the current HEAD cannot be read at all (its `.git` is
damaged), it reads `unreadable` instead of a commit.

The warning is only a warning: `vfox use` still selects the version you asked
for, and exits with 0. SDKs without a `.git` directory are left alone.

With vfox older than 1.1.0 the plugin prints its own warning instead (it never
loads the `Fingerprint` hook), with the commands that reinstall the version by
hand. Update vfox to get the check above.

## How the check works

On install and on `vfox link` the plugin reports the commit the SDK checkout
is at through its `Fingerprint` hook, by reading `.git/HEAD` (and the ref or
`packed-refs` it points to) from files only. vfox keeps that fact in the
version's receipt, `.vfox-receipt.json` in the directory that
`vfox info flutter@3.47.4` prints:

```json
{
  "schema": 1,
  "sdk": "flutter",
  "version": "3.47.4",
  "origin": "installed",
  "facts": {
    "head": "9584c6713b324636289d067944a46fd6b49df14b"
  }
}
```

`vfox use` and `vfox doctor` report `sdk.drift` when the fact is no longer the
same. Archive installs, source installs and OpenHarmony builds all report it.
A fact the plugin can no longer read counts as a change too.

Nothing is checked when there is nothing to compare with: an SDK without a
fact (one installed where there was no `.git` to read), a version installed
before vfox kept receipts (see `vfox doctor --adopt` below), and a version
vfox does not know are all silent.

Versions installed by a plugin older than this one may still carry a
`.vfox-manifest` file in the SDK root (`flutter-3.47.0/.vfox-manifest`). The
current plugin neither writes nor reads it; it is ignored and can be deleted.
It shows as untracked in the SDK's `git status` while it is there.

A version installed before vfox kept receipts has no receipt to compare with.
`vfox doctor` says so (`sdk.no-receipt`), and takes the current state as the
baseline on request:

```bash
vfox doctor --adopt flutter@3.47.0
```

## Disabling the check

The check is one of the fast checks `vfox use` runs after it selects a version.
To stop running them:

```bash
vfox config diagnostics.onUse false
```

To silence only this finding for one version, add it to `diagnostics.ignore` in
your `config.yaml`:

```yaml
diagnostics:
  ignore:
    - "sdk.drift:flutter@3.47.0"
```

See vfox's [configuration](https://vfox.dev/guides/configuration.html#diagnostics-settings)
and [`vfox doctor`](https://vfox.dev/usage/core-commands.html#doctor) for the
rest of the findings.
