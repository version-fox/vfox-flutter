# vfox-flutter

Flutter plugin for [vfox](https://vfox.dev/).

## Install

After installing [vfox](https://github.com/version-fox/vfox), install the plugin by running:

```bash
vfox add flutter
```

The Flutter SDK includes the Dart SDK; 
if you install the Flutter SDK via the current vfox plugin, 
there is no need to separately install the Dart SDK using the vfox plugin from 
https://github.com/version-fox/vfox-dart .

### Example: Ubuntu 26.04

```bash
vfox add flutter
vfox install flutter@3.47.4
sudo apt install --assume-yes curl git unzip xz-utils zip libglu1-mesa
vfox use --global flutter@3.47.4
```

You can verify this using the following command:

```bash
dart --version
flutter --version --no-version-check
```

## Architecture selection

See [docs/arm64.md](docs/arm64.md) for details.

## Mirror

See [docs/mirror.md](docs/mirror.md) for details.

## OpenHarmony builds

See [docs/ohos.md](docs/ohos.md) for details.

## Install from source

See [docs/install-from-source.md](docs/install-from-source.md) for details.

### Testing

See [docs/e2e.md](docs/e2e.md) for details.

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
