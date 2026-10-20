# Install from source

[中文](zh-CN/install-from-source.md) | [English](install-from-source.md)

`vfox add flutter` installs the latest release. To try `main` before its next release, or a
change you are working on, build the plugin from source. A plugin is a `metadata.lua` plus
the `hooks` and `lib` directories, and vfox adds one from a zip of them.

## Ubuntu 26.04.1

Execute in Bash,

```bash
sudo apt install --assume-yes git zip
git clone --depth 1 https://github.com/version-fox/vfox-flutter.git
cd ./vfox-flutter/
zip -qr ./flutter.zip metadata.lua hooks lib
vfox add flutter --source ./flutter.zip
rm ./flutter.zip
```

You can verify this using the following command,

```bash
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
flutter --version --no-version-check
dart --version
```

macOS is the same, with the `git` and `zip` you already have.

## Windows 11

Assume that PowerShell 7 is already installed. Execute in PowerShell 7,

```powershell
winget install --id Git.Git --source winget --exact
git clone --depth 1 https://github.com/version-fox/vfox-flutter.git
cd ./vfox-flutter/
tar -a -cf ./flutter.zip metadata.lua hooks lib
vfox add flutter --source ./flutter.zip
Remove-Item ./flutter.zip
```

You can verify this using the following command,

```powershell
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
flutter --version --no-version-check
dart --version
```

## When flutter is already added

`vfox add` refuses with `plugin named flutter already exists`. You can replace the plugin or
add the source build next to it.

To replace it, `vfox remove flutter` comes first, and it removes the Flutter SDKs installed
through the plugin as well: vfox says `Removing this plugin will remove the installed sdk
along with the plugin.` before it asks. Reinstall them afterwards. An archive alone is 1.6 to
2.3 GB, so this is the expensive way.

To keep both, give the new one another name:

```bash
vfox add flutter --source ./flutter.zip --alias flutter-dev
vfox install flutter-dev@3.47.4
vfox remove -y flutter-dev            # removes only flutter-dev and what it installed
```

The alias has its own list of installed Flutters, and its own downloads under
`cache/flutter-dev` in the vfox home. The link that `vfox use` makes is `~/.vfox/sdks/flutter`
for both, and so is the `bin` directory that lands in your `PATH`. Select a version from only
one of them per scope: for the global scope, `vfox unuse --global flutter` before you
`vfox use --global flutter-dev@...`, or the other way round.

## Updating

Pull, build the zip again and add it again. A plugin added under its own name has to be
removed first, and that takes the installed Flutters with it, so the alias is the easier route
when you update often:

```bash
vfox remove -y flutter-dev
vfox add flutter --source ./flutter.zip --alias flutter-dev
```

`vfox update flutter` compares the version in `metadata.lua` with the registry's and prints
`flutter is already the latest version` while they are equal, so it does not pick up a change
that has the same version number as the release. Add the source build again for that.

To work on the plugin, see [development.md](development.md).
