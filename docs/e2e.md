# End-to-end (E2E) compatibility test

## Why

[vfox#680](https://github.com/version-fox/vfox/issues/680) is a **vfox** bug, not a
plugin bug: after loading the `vfox activate` shell hook, a `vfox use --global`
stopped making `flutter` resolvable on `PATH` ("the term 'flutter' is not recognized").
It happens to be *reported through* the Flutter plugin, which is why the reproduction
lives here.

This plugin's CI cannot fix vfox, but it can (and does) guard the contract vfox broke:
**with the real plugin loaded into the real vfox, `activate` + `use --global` must make
the Flutter SDK resolve on `PATH`.** If a vfox regression breaks that again, this suite
turns red — which is the correct, unambiguous signal; there is no "tolerate it on the
released binary" mode. Offline Lua unit tests (`tests/hooks_test.lua`) can't catch this
because it depends on the live vfox shell hook and `PATH` plumbing, so the suite drives a
real vfox binary, loads this working-tree plugin, installs a real Flutter SDK, and checks
the result in a fresh shell.

## What runs

[`.github/workflows/e2e.yml`](../.github/workflows/e2e.yml) runs on every `pull_request`
and on pushes to `main`, gated to `github.repository == 'version-fox/vfox-flutter'` so
forks don't spend the (heavy) minutes. It builds one container per OS and exercises both
vfox variants inside it:

| OS runner | Container base | Script | vfox variants |
|-----------|----------------|--------|---------------|
| `ubuntu-latest` | `ubuntu:26.04` | `tests/e2e/run.sh` (bash) | `latest`, `main` |
| `windows-latest` | `servercore:ltsc2025` | `tests/e2e/run.ps1` (PowerShell 7) | `latest`, `main` |

Each image is a **toolchain only** (`curl`/`git`/`zip` …); vfox, this plugin, and the
Flutter SDK are installed at **runtime** by the script, so one image serves both vfox
variants and always reflects the working-tree plugin. The Linux `Dockerfile` is kept
minimal: no `ENV HOME`/`WORKDIR` (the container runtime already gives root `HOME=/root`),
files are `COPY`'d to an absolute `/e2e/…` (copying to `/` would clobber system `/lib`
and `/hooks`), and there is no `rm -rf /var/lib/apt/lists` (it only trims image size,
which is irrelevant to an ephemeral CI image and unrelated to buildx caching). For `latest` the Linux script uses
vfox's own installer (`curl -sSL …/vfox/main/install.sh | bash`, which installs to
`/usr/local/bin` — already on `PATH` in the root container), while `run.ps1` uses the
release archive directly (install.sh is
POSIX-only). `main` clones <https://github.com/version-fox/vfox> and builds it (needs Go —
installed on demand, only for that leg).

## The check

The scripts do the #680 flow the way a real user would — activate, then add + install +
use globally — and verify from a *fresh* shell:

```
eval "$(vfox activate <shell>)"          # the hook (vfox refuses `use` without it)
vfox add flutter --source <plugin.zip>   # this working tree's plugin
vfox install flutter@<v>
vfox use --global flutter@<v>

# a brand-new activated shell (what the reporter's $PROFILE / .bashrc produces):
vfox activate <shell>  ->  dart --version;  flutter --version --no-version-check
```

The scripts then **run `dart`/`flutter` and let any failure abort** the leg:
- If the SDK isn't on `PATH` (the exact #680 symptom), the command isn't found → a hard
  error.
- If a command runs but exits non-zero, `set -e` (bash) / `$ErrorActionPreference` +
  `$PSNativeCommandUseErrorActionPreference` (pwsh) aborts and the error is printed.

So the check proves the plugin's `EnvKeys`/global selection actually yields a *usable*
SDK, not just a PATH entry. (Running `flutter` bootstraps Flutter's own toolchain, which
needs `git` and `where.exe`; those are on `PATH` in the image — see the Windows notes.)

### Script mechanics (why the scripts look the way they do)

- **`use` needs the hook.** vfox 1.x refuses `vfox use` unless the shell already ran
  `vfox activate`, so activation precedes `use`.
- **Re-activating in a new shell reflects the persisted global.** `vfox activate` exports
  the current global selection into `PATH` at shell start, so a fresh activated shell sees
  `flutter`/`dart` — no need to simulate an interactive prompt refresh.
- **The check runs in a separate process** (a nested `bash -c` / `pwsh -File`) to emulate
  the reporter's "brand-new terminal", not to re-do work. On Windows the check body is a
  temp `.ps1` because `pwsh -Command "<multi-line>"` quoting is fragile across the process
  boundary.
- **The pwsh activate hook is multi-line**, so its output is joined with real newlines
  (`-join "\`n"`) before `Invoke-Expression` — collapsing it to spaces would break the
  `function prompt { … }` block and skip the `PATH` export.
- **`go` is installed by MSI on demand** (only for `main`); Go's silent-install location
  varies (`C:\Go` vs `C:\Program Files\Go`), so after `msiexec` the script probes those
  `…\bin` dirs for `go.exe` and puts the one it finds on `PATH`.

## Notes

- **Quiet on success, `set -e` on failure.** The scripts stop at the first failing command
  with its own error output visible; there is no separate log file or trap machinery.
- **Inputs.** `VFOX_VERSION` is the only thing the workflow varies
  (`docker run -e VFOX_VERSION=latest|main`); anything that isn't `main` (including unset)
  means the latest release. The Flutter version (`3.44.0`) is pinned in the scripts (old
  releases stay in Flutter's index, so it needs no override), and the scratch dir is always
  a fresh temp dir.
- **Windows image specifics.** `windows-latest` is Server 2025 (build 26100), matching the
  `servercore:ltsc2025` base (a process-isolated container's base build must equal the
  host's). No `powershell` MCR image exists for ltsc2025, so the Windows image installs the
  build-time tools through their **official installers** (`bootstrap-tools.ps1`): PowerShell
  7 via its MSI, Git for Windows via its self-extracting installer (`/VERYSILENT`; Git ships
  no MSI). `bootstrap-tools.ps1` runs under the base image's stock Windows PowerShell 5.1 and
  downloads with the base's bundled `curl.exe`, resolving each installer URL from GitHub
  `releases/latest`. Go is *not* in the image — `run.ps1` installs it on demand (MSI), only
  for the `main` leg (see Script mechanics). vfox's latest release (1.0.12) ships no
  `windows_setup.exe` — only the portable zip (it was dropped after 1.0.11) — so `run.ps1`
  uses that zip, which is also the form winget itself exposes for vfox.
- **Why not `winget`.** vfox, PowerShell and Git *are* all in the winget catalog, and winget
  can be coerced into a Windows container (its `.msixbundle` unpacked to loose,
  unregistered binaries on the larger `windows/server` base — issue microsoft/winget-cli#4144
  is still open, so this is unsupported). But winget would then just orchestrate the same
  official installers we already run directly, behind a fragile, unverifiable bootstrap — so
  we call the installers themselves instead.
- **Legacy builder & PATH.** `bootstrap-tools.ps1` is a copied `.ps1` run via `RUN`, not a
  Dockerfile `RUN <<heredoc>`, because the runner's `docker build` uses the *legacy* builder
  (no heredoc/`# syntax` support). The image's `ENV PATH` lists the system dirs + tool dirs
  **explicitly** rather than `...;${PATH}`, because `${PATH}` didn't reliably keep
  `C:\Windows\System32` on this base — losing it made runtime `curl.exe`/`where.exe` vanish
  despite being present at build time. Docker itself is pre-installed on the runner and
  already runs Windows containers here.
- **Reproducibility.** PS7/Git/vfox resolve to "latest" each build (matches the suite's
  "current tools" intent); to pin, replace the API lookups with fixed-version URLs.

## Running locally

```bash
docker build -f tests/e2e/Dockerfile -t vfox-flutter-e2e:linux .
docker run --rm -e VFOX_VERSION=main vfox-flutter-e2e:linux
```

On Windows (daemon in Windows-container mode):

```powershell
docker build -f tests/e2e/Dockerfile.windows -t vfox-flutter-e2e:windows .
docker run --rm -e VFOX_VERSION=main vfox-flutter-e2e:windows
```

Each run downloads a ~1 GB Flutter SDK, so expect a few minutes per leg. The Linux leg is
fully reproducible locally; the Windows leg is validated on `windows-latest` (Windows
containers can't run on a Linux Docker host).
