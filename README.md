# vfox-flutter
Flutter plugin for [vfox](https://vfox.lhan.me/).


## Install

After installing [vfox](https://github.com/version-fox/vfox), install the plugin by running:

```bash
vfox add flutter
```

### Example: Ubuntu 26.04

```bash
vfox add flutter
vfox install flutter@3.44.0
sudo apt install --assume-yes curl git unzip xz-utils zip libglu1-mesa
vfox use --global flutter@3.44.0
```

## Architecture selection

Available releases include architecture suffixes such as `3.44.0-arm64` and
`3.44.0-x64`. You can install both builds and switch between them:

```bash
vfox install flutter@3.44.0-arm64
vfox install flutter@3.44.0-x64
vfox use --global flutter@3.44.0-x64
```

On Apple Silicon, running an x64 build requires Rosetta. Only architectures
provided by Flutter for the current operating system are listed.

Commands without an architecture, such as `vfox install flutter@3.44.0` or
`vfox install flutter@stable`, continue to select the host architecture and keep
their existing version names. Channels also accept a suffix, such as
`vfox install flutter@stable-x64`. The version list shows the default architecture
first, followed by other architectures, with each group ordered by version.
This keeps `@latest` on the default architecture.

## Mirror

By default, Flutter SDK is downloaded from `https://storage.googleapis.com`.
If you have difficulty accessing it, you can set the `FLUTTER_STORAGE_BASE_URL` environment variable to use a mirror.

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

Common mirror values:

| Mirror                               | URL                                        |
|--------------------------------------|--------------------------------------------|
| China Flutter User Group (CFUG)      | `https://storage.flutter-io.cn`            |
| SJTU (Shanghai Jiao Tong University) | `https://mirror.sjtu.edu.cn/flutter_infra` |

For an up-to-date list of available mirrors, refer to the MirrorZ Help site: https://help.mirrors.cernet.edu.cn/flutter/ .

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
