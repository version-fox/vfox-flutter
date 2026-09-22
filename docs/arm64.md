# Architecture selection

Available releases include architecture suffixes such as `3.47.4-arm64` and
`3.47.4-x64`. You can install both builds and switch between them:

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

Only architectures provided by Flutter for the current operating system are
listed. On Apple Silicon, running an x64 build requires Rosetta.

## Linux ARM64

On Linux ARM64 the plugin installs the official `flutter/flutter` git tag
instead of a prebuilt bundle. The Flutter tool bootstraps the matching native
`dart-sdk-linux-arm64` itself on first run, so the result is a native SDK.
This follows the same pattern as the OpenHarmony builds (`lib/ohos.lua`):
`Available` advertises one `-arm64` entry per `x64` release whose `url` is the
clone URL, and `PreInstall` materializes the tag into a local directory under
`~/.vfox/tmp` that vfox consumes. `PostInstall` removes that throwaway
checkout.

Explicit `-x64` requests still resolve to the upstream archive, which cannot
run on Linux ARM64.

## Windows ARM64

Not supported: upstream publishes no `windows-arm64` archives, so no `-arm64`
entries are listed and installs fail instead of handing out an unusable `x64`
bundle.

# Limits

- **`git` is required.** The checkout runs `git init` / `fetch` / `checkout`
  against `https://github.com/flutter/flutter.git`.
- **The first `flutter` run is slow.** It downloads the native Dart SDK and
  builds the Flutter tool, so it needs a network connection.
- **No checksum is verified.** Git history is the integrity check.
- **No `-arm64` variants for legacy releases.** Versions without architecture
  metadata (such as `2.10.0`) keep their existing x64-only behavior.
- **Mirrors don't apply.** `FLUTTER_STORAGE_BASE_URL` (see `mirror.md`) only
  affects archive downloads; source installs clone from GitHub.
