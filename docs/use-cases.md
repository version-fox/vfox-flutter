# Use cases

[中文](zh-CN/use-cases.md) | [English](use-cases.md)

What the plugin is for, as situations you may be in. Each one gives the commands with the plugin, says what the same takes by hand where that helps, and links to the page that has the details. The commands were run in Bash on Ubuntu 26.04.1 (x64) with vfox 1.0.13 and plugin 0.2.5 on 2026-11-03, when Flutter's release index had `3.47.9` as `stable` and `3.50.0-0.3.pre` as `beta`. What vfox itself does (the shell hook, the scopes, `vfox install --all`) is what 1.0.13 does, and other versions may differ.

## A new machine

Installing Flutter by hand is a download, an unpack and an edit of `~/.bashrc`, and the address of the download depends on the operating system, the channel and the version. The plugin does the same with three commands.

### Ubuntu 26.04.1

Execute in Bash,

```bash
curl --location --output /tmp/flutter_linux.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.4-stable.tar.xz
mkdir -p ~/develop/
tar -xf /tmp/flutter_linux.tar.xz -C ~/develop/
rm -rf /tmp/flutter_linux.tar.xz
echo 'export PATH="$HOME/develop/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

With the plugin that is,

```bash
vfox add flutter
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
```

Both end with the same Flutter on the `PATH`, and `flutter --version --no-version-check` starts with `Flutter 3.47.4 • channel stable • https://github.com/flutter/flutter.git`. The archive is the same file, too. Step by step:

| By hand | With the plugin |
| --- | --- |
| Build the address of the archive from the operating system, the channel and the version, and `curl` it | `vfox install flutter@3.47.4` finds the release in Flutter's release index, which lists the archive for your operating system and CPU |
| Nothing compares the download with a checksum | vfox verifies it against the SHA-256 of the index and prints `Verifying checksum ...` |
| `mkdir -p ~/develop/` and `tar -xf ...` put one Flutter in one place, `~/develop/flutter` | Every version gets a directory of its own, `~/.vfox/cache/flutter/v-3.47.4/flutter-3.47.4/` |
| `rm -rf /tmp/flutter_linux.tar.xz` | vfox removes the archive after unpacking |
| `echo ... >> ~/.bashrc` and `source ~/.bashrc` | `vfox use --global flutter@3.47.4` |

The last row is the point. vfox has to be hooked into your shell once, with a line that has nothing to do with Flutter and that every SDK you manage with vfox shares (vfox's [quick start](https://vfox.dev/guides/quick-start.html) has the line for other shells):

```bash
echo 'eval "$(vfox activate bash)"' >> ~/.bashrc
source ~/.bashrc
```

After that nothing about Flutter is ever added to `~/.bashrc`, edited in it or removed from it: not when you install another version, not when you switch, not when you uninstall. `vfox use` stops in a shell without the hook: `vfox requires hook support. Please ensure vfox is properly initialized with 'vfox activate'`. The hook runs before each prompt, so a terminal that was open before you switched picks the new choice up at its next prompt. By hand every open terminal has to run `source ~/.bashrc` or be restarted, and the `echo` line puts the `PATH` line in a second time when you run it a second time.

On macOS and Windows the steps by hand are the same, with the `.zip` for your CPU (`flutter_macos_arm64_3.47.4-stable.zip`, `flutter_windows_3.47.4-stable.zip`) and `~/.zshrc` or your user `Path` variable. The three commands with the plugin stay the same, and only the line that hooks vfox into your shell depends on the shell, see [platforms.md](platforms.md).

## You already installed Flutter by hand

Until you select a version with vfox, `flutter` is still the copy in `~/develop/flutter`. Install the version you use, select it, and ask which `flutter` runs.

### Ubuntu 26.04.1

Execute in Bash,

```bash
vfox install flutter@3.47.4
vfox use --global flutter@3.47.4
command -v flutter
```

`command -v flutter` prints `~/.vfox/sdks/flutter/bin/flutter` with your home directory spelled out. vfox puts its directory in front of the old one in `PATH`, whether the `PATH` line comes before or after the hook in `~/.bashrc`, so the new Flutter runs without any other change. To tidy up, look up the old line:

```bash
grep -n 'develop/flutter/bin' ~/.bashrc
```

Delete the line it prints in your editor, open a new terminal (the one you are in still has the old `PATH`), and remove the old SDK:

```bash
rm -rf ~/develop/flutter
```

Flutter's own settings (`~/.config/flutter`) and the pub cache (`~/.pub-cache`) are in your home directory, not in the SDK, so they carry over to the new install.

## Projects on different Flutter versions

An older app has to stay on `3.44.0` while a new one uses `3.47.4`. By hand that is two directories and a `PATH` that you change whenever you switch. With the plugin each version is installed once, and each project says which one it uses:

```bash
vfox install flutter@3.44.0
vfox install flutter@3.47.4
cd ~/work/legacy_app
vfox use --project flutter@3.44.0
cd ~/work/new_app
vfox use --project flutter@3.47.4
```

`vfox use --project` writes the choice to `.vfox.toml` in the project directory (`flutter = "3.44.0"` under `[tools]`) and links the SDK at `.vfox/sdks/flutter`. While you are in that directory `flutter` is the project's Flutter, and in any other directory it is the one you chose with `--global`:

```
$ cd ~/work/legacy_app
$ flutter --version --no-version-check | sed -n 1p
Flutter 3.44.0 • channel stable • https://github.com/flutter/flutter.git
$ cd ~/work/new_app
$ flutter --version --no-version-check | sed -n 1p
Flutter 3.47.4 • channel stable • https://github.com/flutter/flutter.git
```

Every version is a full SDK on disk, see [platforms.md](platforms.md#requirements). Three things about the scopes:

- **The choice applies in the directory that holds `.vfox.toml`, not in its subdirectories.** In `~/work/legacy_app/lib`, `flutter` comes from the session or the global choice. `vfox current flutter` shows which version applies where you are.
- **The hook changes `PATH` when the prompt is shown.** `cd ~/work/new_app && flutter run` on one line still runs the Flutter of the directory you came from. `cd` first and run `flutter` after.
- **`.vfox/` stays out of git.** vfox adds it to the `.gitignore` of the project when there is one and prints `Added '.vfox/' to .gitignore`. It does not create a `.gitignore`.

## A team on one Flutter

Commit `.vfox.toml` and the `.gitignore` change, and everybody builds the project with the Flutter it was written for, and not with whichever one their machine happens to have. Someone who clones the project runs this in its directory:

```bash
vfox add flutter
vfox install --all
vfox use --project flutter@3.44.0
```

`vfox install --all` installs the versions that `.vfox.toml` lists, and asks first (`--yes` skips the question). It does not select them. That is what `vfox use --project` is for, with the version from `.vfox.toml`, and it writes the same `.vfox.toml` again, so git has nothing new to commit. `vfox add flutter` comes first because on a machine without the plugin, `vfox install --all` only adds the plugin, and the SDK follows with the next one.

## Upgrading, and going back

A new Flutter is installed next to the old one, and nothing changes until you select it. `vfox install flutter@stable` installs the release the stable channel points to (`3.47.9` on 2026-11-03):

```bash
vfox install flutter@stable
vfox use --global flutter@3.47.9
```

If the new release breaks something, the old one is still installed:

```bash
vfox use --global flutter@3.47.4
```

`vfox uninstall flutter@3.47.9` removes the release you do not want, and only its directory. `flutter upgrade` changes the SDK in place instead, where vfox does not see it, and what `vfox list flutter` says is then no longer what runs, see [flutter-upgrade.md](flutter-upgrade.md). That is why you can ignore the "A new version of Flutter is available!" box that suggests `flutter upgrade`: `vfox install flutter@stable` is the upgrade, see [troubleshooting.md](troubleshooting.md#things-that-look-wrong-and-are-not).

## Trying a beta in one terminal

```bash
vfox install flutter@beta
vfox use --session flutter@3.50.0-0.3.pre
```

The session choice is for this terminal. The others keep the version they had, and a new terminal does not have the beta. The beta stays installed until you `vfox uninstall flutter@3.50.0-0.3.pre`. `flutter@beta` is replaced by the release it points to (`3.50.0-0.3.pre` on 2026-11-03), and `vfox use` takes that name, see [channels.md](channels.md#use-the-version-not-the-channel).

## A mirror

When `storage.googleapis.com` is slow or cannot be reached, the address by hand changes its host, for example to the CFUG mirror:

```bash
curl --location --output /tmp/flutter_linux.tar.xz https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.4-stable.tar.xz
```

With the plugin you set `FLUTTER_STORAGE_BASE_URL` once, and every install takes the index and the archive from there:

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
vfox install flutter@3.47.4
```

The `flutter` tool reads the same variable for what it downloads when you first use it, so keep it set in your shell and not only while you install. How to make it permanent, the other mirrors, and `PUB_HOSTED_URL` for packages, which the plugin does not touch, are in [mirror.md](mirror.md).

## Scripts, containers and IDEs

`vfox use` needs the hook, which a script, a container build or a CI step does not have. `vfox exec` runs one command with the Flutter you name, hook or not:

```bash
vfox exec flutter@3.47.4 -- flutter --version --no-version-check
```

An IDE that should follow your global choice can take `~/.vfox/sdks/flutter` as its Flutter SDK path, and then needs no change when you switch versions. See [Where Flutter is](troubleshooting.md#where-flutter-is).

## ARM64 machines and OpenHarmony

Google publishes no Flutter archive for Linux ARM64 or Windows ARM64, so by hand Flutter comes from a `git clone` of `flutter/flutter`. The plugin does that for the plain name:

```bash
vfox install flutter@3.47.4
```

It offers the releases whose Flutter tool runs with a native Dart SDK there, see [arm64.md](arm64.md). The OpenHarmony fork of Flutter on gitcode.com installs the same way (`vfox install flutter@3.41.10-ohos-1.0.0`), see [ohos.md](ohos.md).
