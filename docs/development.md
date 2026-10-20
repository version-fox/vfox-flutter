# Development

[中文](zh-CN/development.md) | [English](development.md)

## Layout

```
metadata.lua              plugin name, version, oldest vfox, and the note that `vfox add` prints
hooks/available.lua       vfox search: the list of every name
hooks/pre_install.lua     vfox install: resolve a name to a package; and PostInstall
hooks/pre_use.lua         vfox use: warn when the SDK has drifted
hooks/env_keys.lua        PATH
lib/util.lua              the mirror, the platform, version names and their order
lib/git.lua               git commands, the GitHub mirror, the work directory
lib/source.lua            source installs on Linux ARM64 and Windows ARM64
lib/ohos.lua              OpenHarmony releases and checkouts
lib/manifest.lua          .vfox-manifest and the pubspec.lock fix
tests/hooks_test.lua      offline hook tests
tests/e2e/                container tests, see e2e.md
Injection.lua             type hints for what vfox injects, never loaded
.luarc.json, stylua.toml  Lua language server and formatter settings (Lua 5.1, 120 columns, 4 spaces)
.devcontainer/            the Linux development container, see e2e.md
.github/workflows/        lint, license headers, hook tests, e2e, and the release workflow
```

vfox loads `metadata.lua`, calls a hook when a command needs it, and puts `PLUGIN` and `RUNTIME` (`osType`, `archType`, `version`) in scope. `osType` and `archType` are Go's `GOOS` and `GOARCH` of the vfox binary. The hooks run in gopher-lua, a Lua 5.1 interpreter written in Go, with vfox's `http` and `json` modules. Files in `lib` are loaded with `require`, and `lib/util.lua` defines globals.

## What runs for a command

| You run | Hooks |
| --- | --- |
| `vfox search flutter` | `Available` |
| `vfox install flutter@3.47.4` | `PreInstall` returns the package, and calls `Available` itself to find it. vfox downloads, verifies and unpacks, then calls `PostInstall` |
| `vfox use flutter@3.47.4` | `PreUse` checks the SDK and returns the name. `EnvKeys` provides `PATH` |
| `vfox uninstall flutter@3.47.4` | none, the name has to be exact |

## Contracts that cost time

- `Available` returns one table per name with `version`, `url`, `sha256`, `key`, `note` and `addition`. `key` is the git commit of the release, which is how a channel finds its release: `current_release.stable` in the index is a commit, and `PreInstall` takes the entries whose `key` is that commit. `note` is the channel, shown in parentheses. `addition` is the Dart version, shown in brackets. `source = true` is the plugin's own mark for a `-arm64` source install.
- `PreInstall` returns `version`, `url` and `sha256`. `version` becomes the name of the install. It is the name without the architecture suffix unless the request had one (`3.47.4` stays `3.47.4`, `3.47.4-x64` stays `3.47.4-x64`), and for a channel the release it stands for. A source install returns the path of a local directory as `url` and no checksum, and vfox moves the directory into place.
- `PreInstall` calls `self:Available({ officialOnly = true })` and so does not use vfox's 12-hour cache of the list. Every install reads the index. `officialOnly` leaves out the OpenHarmony releases: an official install has no use for them, and gitcode.com rate-limits the API they come from. vfox calls `Available` with its own context (`vfox search`, and the `latest` of `vfox install`), and those lists have them.
- `PreInstall` returns `nil` for a name it cannot resolve, which vfox reports as `no installable runtime provided`. It raises an error for a failure: the message of `error()` shows up in the `plugin [PreInstall] method error:` line.
- The index lists some releases more than once. `newestPublications` in `hooks/available.lua` keeps the newest entry (`release_date`) of each archive of a version, because a file that was uploaded again has the checksum of the newest entry only (see [troubleshooting.md](troubleshooting.md#checksum-error)). Different versions never merge, and a release in two channels has an archive in each and keeps both. `table.sort` is not stable, so the comparator has to tell any two entries apart, or equal entries come out in an order that depends on the whole input, and `PreInstall` takes the first match. It ends with the version and the channel for that.
- `PostInstall` reads `ctx.sdkInfo[PLUGIN.name]`. It runs the manifest and the `pubspec.lock` fix under `pcall`, so a failure there never fails the install.
- vfox unpacks a `.tar.xz` with Go's `archive/tar`, which stamps files with the time of the extraction and not with the time stored in the archive. The official `tar -xf` flow keeps those times, and `packages/flutter_tools/pubspec.lock` is newer than `pubspec.yaml` after it. After a vfox install the two share the time of the extraction, and whichever is written last looks newer, so `bin/internal/shared.sh` can find `pubspec.yaml` newer than `pubspec.lock` and rebuild the tool on the first run (`Building flutter tool...`). `manifest.touchPubspecLock` rewrites `pubspec.lock`, on every platform, to restore the order ([#37](https://github.com/version-fox/vfox-flutter/issues/37)). Source installs build the tool on the first run by design.
- A Windows command line reaches `cmd.exe` as vfox 1.0.13 and later write it, unchanged ([vfox#712](https://github.com/version-fox/vfox/pull/712)), and older versions quote it again. `quote` in `lib/git.lua` and `lib/manifest.lua` puts double quotes around a path that contains whitespace, and leaves other paths bare, so that a path with a space works on 1.0.13 and a path without one still works on older versions.
- `os.execute` reports success as `0` or as `true`, depending on the Lua it runs in, and `exec` in `lib/git.lua` accepts both. `io.popen` is how the plugin reads the output of `git`; a command that prints nothing or fails reads as `nil`, which is why a missing `git` goes unnoticed in `lib/manifest.lua`.
- `lib/git.lua` takes the work directory from `VFOX_HOME`, then `HOME`, then `USERPROFILE`, and appends `.vfox/tmp/<name>`. With `VFOX_HOME` set that is `$VFOX_HOME/.vfox/tmp/<name>`, one `.vfox` below the vfox home. The directory is not removed when the install fails.
- `git` runs with your configuration, except for two settings that `git.init` writes into the checkout: `core.longpaths=true`, and `core.autocrlf=false`, because a global `true` writes Flutter's shell scripts with CRLF (see [arm64.md](arm64.md#limits)). On Windows `false` writes the same CRLF files `true` does, since `core.eol` is native there. That is how git works, and it was checked on Linux with `core.eol=crlf` and Flutter's `.gitattributes`, which starts with `* text=auto`: the same files came out CRLF for both settings, and `bin/flutter` stayed LF. The Windows ARM64 container tests install from a checkout like this one. Fetches get `http.lowSpeedLimit=1000` and `http.lowSpeedTime=60`, which `GIT_HTTP_LOW_SPEED_LIMIT` and `GIT_HTTP_LOW_SPEED_TIME` override.
- `lib/ohos.lua` waits for gitcode.com in two ways. Installing a build needs the releases, and makes five attempts: 10 seconds apart, and 30, 60, 120 and 180 seconds after HTTP 429. Listing them is a courtesy to `vfox search`, so `ohos.list()` makes two attempts 2 seconds apart, stops at HTTP 429, and returns `nil` and the reason. `Available` then writes one warning line to stderr and lists the official releases.
- A tag is an OpenHarmony release when its name contains `-ohos-` or `+ohos-` (`ohos.isOhosVersion`).
- `source.list` offers a `-arm64` source install of a release only from `OLDEST_NATIVE` on, the first release whose Flutter tool runs with a native Dart SDK on that machine, see [Refreshing the Dart SDK table](#refreshing-the-dart-sdk-table).
- `EnvKeys` sets `PATH` only. It sets no `FLUTTER_ROOT`.
- Lua has no sleep, so `sleep` in `lib/util.lua` is `os.execute("sleep N")`, or `timeout /t N` on Windows. The retries in `hooks/available.lua` and `lib/ohos.lua` wait with it.

## Names and order

`splitVersionAndArch` in `lib/util.lua` splits `3.47.4-x64` into `3.47.4` and `x64`, and only `x64` and `arm64` count as a suffix: `3.50.0-0.1.pre` has none. `compare_versions` ignores the suffix and compares the numbers in the version one by one. A version with fewer numbers sorts above one that continues the same numbers, so `3.47.0` is above `3.47.0-0.4.pre`.

`Available` sorts by these rules, one after the other:

1. OpenHarmony names after all others (`ohos.isOhosVersion`).
2. The architecture of the machine, and names without a suffix, before the other architecture.
3. Entries of the stable channel (`note == "stable"`) before the others, so that `@latest`, the first line, is the newest stable release and not a beta that has a higher number.
4. `compare_versions`, newest first.
5. The architecture of the machine before the other one, and then the plain string order.
6. The channel (`beta` before `dev`), for the same name in two channels.

Rules 2 and 3 keep `@latest` on the machine's own architecture and on a stable release. The unit tests check both.

## Resolving a name

`PreInstall` splits the request into a name and an architecture (`requestedArch`), and then:

1. An OpenHarmony name goes to `ohos.checkout`, which refuses a suffix.
2. `beta` and `stable` read `current_release` from the index, and its commit becomes `channelKey`. A channel that the index does not name ends the lookup with `nil`. `dev` is not a channel any more, so it is looked up as a version name and found nowhere.
3. It walks `Available`, and takes the first entry whose commit is `channelKey`, or whose name equals the request, and whose architecture is the one requested (or the machine's). An entry without architecture metadata is kept as `legacy` for a request without a suffix, and returned when nothing else matched.
4. A source entry goes to `source.checkout`. The others return `url` and `sha256`.

## Tests

The hook tests run offline under `gopher-lua`, the Lua interpreter vfox embeds:

```bash
go run github.com/yuin/gopher-lua/cmd/glua@v1.1.1 tests/hooks_test.lua
```

Run it from the repository root. The test stubs `http`, `json` and `os.getenv`, and keeps a small index in a table: two architectures that share a commit, a beta, a dev release and a release without architecture metadata. It checks that:

- every variant is listed, the machine's architecture first;
- an explicit suffix selects the matching archive, and a plain name keeps the machine's;
- `@latest` stays on the machine's architecture even when the other one is newer;
- channels pick the machine's architecture although both share a commit, and `dev` resolves to nothing;
- pre-release names keep their text, and the suffix does not change the order;
- the mirror serves the index and every archive;
- a release without architecture metadata stays installable and gets no invented variant;
- a missing architecture never falls back to an incompatible archive;
- a fetch gives up on a stalled transfer and retries;
- installing an official release never asks gitcode.com, while a listing asks it once;
- a rate-limited gitcode.com costs a listing no wait and one warning, and a failed request is tried once more;
- installing an OpenHarmony build waits out a rate-limited gitcode.com (30, 60, 120 and 180 seconds);
- OpenHarmony tags with `+ohos-` are listed, sorted and installable, and refuse an architecture suffix;
- stable releases come before pre-releases, so the first line is the newest stable release;
- an archive that was published again keeps its newest entry, and different versions or channels never merge;
- ARM64 source installs start at the first release that runs with a native Dart SDK;
- a checkout does not take `core.autocrlf` from your git configuration (this one runs real `git`, and skips itself without it);
- an unsupported CPU is named in the message.

The manifest and `PreUse` are not in this file, and source installs and OpenHarmony builds only up to their `git` commands. The container tests cover them, see [e2e.md](e2e.md). Lint, license headers and the container tests are in [e2e.md](e2e.md#local-checks).

To call a single hook, vfox 1.0.13 and later has `vfox plugin run`. It does not register the plugin, and `--os` and `--arch` answer for another platform:

```bash
vfox plugin run . Available --os windows --arch arm64 --json
vfox plugin run . PreInstall --input '{"version":"stable"}' --os darwin --arch arm64 --json
```

Both ask the real index and gitcode.com. A source install (`--os linux --arch arm64`) runs the real `git` in its work directory, whatever the operating system you are on. `vfox --debug <command>` shows what vfox does with a hook, which is how to find an error it swallows.

### Trying a change without downloading gigabytes

An archive is 1.6 to 2.3 GB, so a change to the resolution is cheaper to try against a fake mirror: a copy of the real index whose archives are one tiny SDK. The SDK holds a `flutter/bin/flutter` script and a real git repository, so the manifest and the drift check run for real. Run it on Linux, from the root of the repository. It sets `HOME` and `VFOX_HOME` to a scratch directory, which vfox needs both of, so your real vfox is left alone.

```bash
work=$(mktemp -d)
python3 - "$work" <<'EOF'
import hashlib, io, json, os, subprocess, sys, tarfile, urllib.request

work = sys.argv[1]
base = "https://storage.googleapis.com/flutter_infra_release/releases/"
index = json.load(urllib.request.urlopen(base + "releases_linux.json"))

sdk = os.path.join(work, "sdk", "flutter")
os.makedirs(os.path.join(sdk, "bin"))
with open(os.path.join(sdk, "bin", "flutter"), "w") as f:
    f.write('#!/bin/sh\necho "fake flutter in $(cd "$(dirname "$0")/.." && pwd)"\n')
os.chmod(os.path.join(sdk, "bin", "flutter"), 0o755)
git = ["git", "-C", sdk, "-c", "user.name=x", "-c", "user.email=x@x", "-c", "core.autocrlf=false"]
subprocess.run(["git", "init", "-q", sdk], check=True)
subprocess.run(git + ["add", "."], check=True)
subprocess.run(git + ["commit", "-q", "-m", "fake"], check=True)

path = os.path.join(work, "flutter.tar.xz")
with tarfile.open(path, "w:xz") as tar:
    tar.add(sdk, arcname="flutter")
sha = hashlib.sha256(open(path, "rb").read()).hexdigest()

root = os.path.join(work, "mirror", "flutter_infra_release", "releases")
os.makedirs(os.path.join(root, "fake"))
os.rename(path, os.path.join(root, "fake", "flutter.tar.xz"))
for release in index["releases"]:
    release["archive"], release["sha256"] = "fake/flutter.tar.xz", sha
with open(os.path.join(root, "releases_linux.json"), "w") as f:
    json.dump(index, f)
EOF
```

The scratch directory now holds the mirror. Build the plugin the way [install-from-source.md](install-from-source.md) does:

```bash
zip -qr "$work/flutter.zip" metadata.lua hooks lib
```

Serve the mirror, in the background of a shell you keep, and run vfox against it:

```bash
python3 -m http.server 8000 --bind 127.0.0.1 --directory "$work/mirror" >/dev/null 2>&1 &
server=$!
export HOME="$work/home" VFOX_HOME="$work/vfox" FLUTTER_STORAGE_BASE_URL=http://127.0.0.1:8000
mkdir -p "$HOME" "$VFOX_HOME"
vfox add flutter --source "$work/flutter.zip"
vfox search flutter
vfox install flutter@stable
eval "$(vfox activate bash)"
vfox use --global flutter@3.47.7
flutter
```

Stop the server with `kill "$server"`, not with `pkill -f` and its command line, which matches your own shell as well. To try the next change, edit the plugin in the repository, repeat the `zip` line above, and run `vfox remove -y flutter` before `vfox add` again. The plugin asks gitcode.com for the OpenHarmony releases when `vfox search` lists versions, and an unreachable gitcode.com only costs two attempts and a warning. The real index has `3.47.7` as `stable` on 2026-10-21; use whatever `vfox install flutter@stable` printed.

### Refreshing the Dart SDK table

`OLDEST_NATIVE` in `lib/source.lua` holds, for each ARM64 platform, the oldest release whose Flutter tool runs with a native Dart SDK. A source install of an older release clones fine, but its tool takes the x64 Dart SDK, so the plugin does not give it an `-arm64` name. Two things make a release native: its bootstrap script asks for the ARM64 Dart SDK, and Flutter's storage has it. Old releases do not change, so the table needs a look when a platform joins, and not for every release. To check a release:

```bash
release=2.0.6
curl -fsSL "https://raw.githubusercontent.com/flutter/flutter/$release/bin/internal/update_dart_sdk.sh" | grep 'DART_ZIP_NAME="dart-sdk-linux'
curl -fsSL "https://raw.githubusercontent.com/flutter/flutter/$release/bin/internal/update_dart_sdk.ps1" | grep -c -i arm64
engine=$(curl -fsSL "https://raw.githubusercontent.com/flutter/flutter/$release/bin/internal/engine.version")
for platform in linux windows; do
  printf '%s ' "$platform"
  curl -s -o /dev/null -I -w '%{http_code}\n' "https://storage.googleapis.com/flutter_infra_release/flutter/$engine/dart-sdk-$platform-arm64.zip"
done
```

The first command prints the zip that the Linux script asks for: `dart-sdk-linux-x64.zip` up to `2.0.6`, and `dart-sdk-linux-${ARCH}.zip` from `2.2.0` on, where `uname -m` decides `ARCH`. The second counts the lines about ARM64 in the Windows script: `0` up to `3.19.6`, and `6` from `3.20.0-1.1.pre` on. The loop asks the storage for the ARM64 Dart SDK of the engine, `200` for there and `404` for not there. On 2026-10-21 `2.0.6` printed `linux 200` and `windows 404`, `3.43.0-0.3.pre` the same, and `3.44.0-0.1.pre` printed `200` for both.

The Linux row of the table is where the script starts to ask (storage has the SDK from `2.0.0`), and the Windows row is where storage starts to have it (the script asks from `3.20.0-1.1.pre` and falls back to the x64 SDK without it). The table was made by running these checks for the 300 releases of `releases_linux.json` that have `"dart_sdk_arch": "x64"`, which are the ones that get a `-arm64` source install, and it holds for every one of them: the scripts of 283 releases choose the Linux zip by CPU and the 17 oldest do not, and the Windows scripts of 148 mention ARM64 and the 152 oldest do not. On Windows seven older betas (listed in `lib/source.lua`) have the SDK in storage and are left out. The Linux scripts of `1.20.0`, `1.22.4`, `2.0.0` and `2.0.6` were also run as an ARM64 machine, with a `uname` that says `aarch64` and a `curl` that prints the URL it is asked for, and asked for `dart-sdk-linux-x64.zip`, while those of `2.2.0`, `2.5.0`, `3.0.0` and `3.24.0` asked for `dart-sdk-linux-arm64.zip`.

## Adding to the plugin

- **A new way to name or choose.** Change `hooks/available.lua` (the order) or `hooks/pre_install.lua` (the choice), add a case to `tests/hooks_test.lua`, and update [versions.md](versions.md), [channels.md](channels.md) and [arm64.md](arm64.md) where they describe it.
- **A new platform.** `getOsTypeAndArch` in `lib/util.lua` lists the CPUs. A platform that installs from git adds itself to `SOURCE_INSTALL_PLATFORMS` and `OLDEST_NATIVE` in `lib/source.lua`. Update [platforms.md](platforms.md) and the tables in [arm64.md](arm64.md), and add it to the container tests if a runner exists ([e2e.md](e2e.md)).
- **A new source of builds** like OpenHarmony: a module in `lib/` that lists names and checks them out, a branch in `Available`, `PreInstall` and `PostInstall`, a flavor in `tests/e2e/common/common.go` (`DefaultFlavours`, `DefaultOhosVersion`), and a page in `docs/`.
- **A message.** The container tests assert parts of the drift warning (`tests/e2e/linux/verify.go` and `tests/e2e/windows/verify.go`). Change the Lua and both files together, and the text in [flutter-upgrade.md](flutter-upgrade.md).

## Known gaps

- Source installs and OpenHarmony builds are not verified against a checksum.
- Only releases from Flutter 1.17 on are listed.
- `OLDEST_NATIVE` is data taken on 2026-10-21 and does not follow Flutter's storage or scripts. It is about the Dart SDK only: the plugin does not check the rest of an old release on ARM64.
- A failed source install leaves its work directory behind.
- `vfox search` marks only the names it prints as installed, see [versions.md](versions.md#searching).
- Releases without architecture metadata (stable `1.22.6` and older, and the pre-releases up to `2.10.0-0.3.pre`) install an x64 archive on every machine, ARM64 Linux and Windows included, where it does not run natively.
- The OpenHarmony fork changes its tag names (`-ohos-`, since 2026-10-15 `+ohos-`). A name with another marker is not listed.

## Releasing

A maintainer runs **Actions → Plugin → Run workflow** on the default branch with the version, without `v`. The [README](../README.md#releasing-this-plugin) describes what the shared workflow does. Afterwards `plugins/flutter.json` in [vfox-plugins](https://github.com/version-fox/vfox-plugins) shows the version that `vfox add flutter` serves. That lags the release by hours: 1 h 22 min for 0.2.2, 4 h for 0.2.3 and 2 h 28 min for 0.2.4. Then bring the docs up to date, in both languages: move the "Unreleased" entries of [changes.md](changes.md) under the new version, dated with the day of the release, name that version as the newest one in its first paragraph, put it in the `plugin_version` of the manifest in [flutter-upgrade.md](flutter-upgrade.md#how-the-check-works), and take the "Unreleased" marks out of the other pages, see [Writing the docs](#writing-the-docs).

## Writing the docs

English pages are in `docs/`, the Chinese ones in `docs/zh-CN/` under the same names (the Chinese README is `README_CN.md`), and each page starts with a link to the other language. Change both when you change one: the Chinese pages are translations, and they keep the commands, the paths and the messages of the plugin and of vfox as they are. The README is the way in: a few sentences for each subject and a link. The details are in `docs/`, one page for a subject. Pages that quote data from outside (Flutter's index, gitcode.com, vfox) give the day the data was taken, or the vfox version. Nothing in CI checks the docs, so run the commands you add.

Commands for a platform go under a heading with the platform (`## Ubuntu 26.04.1`, `## Windows 11`) and begin with `Execute in Bash,` or `Execute in PowerShell 7,` (`在 Bash 中执行：` in Chinese), as the pages already do. The examples install `3.47.4`, the default of the container tests (`DefaultOfficialVersion` in `tests/e2e/common/common.go`); move them together when it moves.

Behavior that is only on `main` and not in the latest release is marked "Unreleased" ("未发布" in Chinese), with an entry under "Unreleased" in [changes.md](changes.md). After a release, move those entries under the new version and take the marks out, in both languages: `grep -rn -i -e unreleased -e 未发布 docs README*`.
