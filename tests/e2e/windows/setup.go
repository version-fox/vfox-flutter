package e2e

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	tc "github.com/testcontainers/testcontainers-go"
)

// NOTE: keep the Flutter defaults in sync with tests/e2e/linux/setup.go.
// The two Go modules share no config format, so the versions are duplicated
// on purpose. Bump both together.
const (
	defaultOfficialVersion = "3.47.4"
	defaultOhosVersion     = "3.41.10-ohos-1.0.0"
	// goWindowsVersion pins the Go toolchain MSI used to build vfox@main
	// inside the container (was setup.ps1).
	goWindowsVersion = "1.27.1"
)

const bogusMirror = "https://invalid.example.invalid"

// pwshQuote renders a single-quoted PowerShell string literal.
func pwshQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}

// resolveFlutterVersion honours $FLUTTER_VERSION / $OHOS_VERSION, else the
// defaults above (was lib.ps1 Resolve-FlutterVersion).
func resolveFlutterVersion(t *testing.T, flavor string) string {
	t.Helper()
	switch flavor {
	case "official":
		if v := os.Getenv("FLUTTER_VERSION"); v != "" {
			return v
		}
		return defaultOfficialVersion
	case "ohos":
		if v := os.Getenv("OHOS_VERSION"); v != "" {
			return v
		}
		return defaultOhosVersion
	default:
		t.Fatalf("unknown flavor %s", flavor)
		return ""
	}
}

// releasesIndex mirrors the preflight probe for windows.
func releasesIndex(mirror string) string {
	return strings.TrimSuffix(mirror, "/") + "/flutter_infra_release/releases/releases_windows.json"
}

// checkMirrorReachable fails fast when the mirror does not serve the release
// index. Official flavours download from $FLUTTER_STORAGE_BASE_URL when set.
func checkMirrorReachable(ctx context.Context, t *testing.T, ctr tc.Container, flavor, mirror string) {
	t.Helper()
	if flavor != "official" || mirror == "default" {
		return
	}
	index := releasesIndex(mirror)
	execRetry(ctx, t, ctr, "mirror "+index,
		fmt.Sprintf("curl.exe -fsSL --max-time 20 -o NUL %s", pwshQuote(index)))
	t.Logf("PASS mirror %s serves the releases index", mirror)
}

// withEnv returns box.vars plus extra entries, without mutating the shared
// backing array.
func withEnv(box slotBox, extra ...string) []string {
	out := make([]string, 0, len(box.vars)+len(extra))
	out = append(out, box.vars...)
	return append(out, extra...)
}

// slotBox carries the per-combo isolated profile locations from setup.ps1
// plus the exec env overrides that apply them (each exec starts a fresh
// process, so the $env: assignments cannot persist and must ride along).
type slotBox struct {
	slot     string
	slotRoot string
	tmp      string
	workDir  string
	vfoxExe  string
	pluginZw string
	vars     []string
}

// setupSlotEnv replicates the slot isolation header of setup.ps1:
// USERPROFILE/VFOX_HOME/TEMP/TMP point under vfox-e2e-runs\<slot> so
// parallel combos on one daemon never share vfox state.
func setupSlotEnv(ctx context.Context, t *testing.T, ctr tc.Container, slot string) slotBox {
	t.Helper()
	userProfile := strings.TrimSpace(execOK(ctx, t, ctr, "$env:USERPROFILE"))
	containerPath := strings.TrimSpace(execOK(ctx, t, ctr, "$env:PATH"))
	procArch := strings.TrimSpace(execOK(ctx, t, ctr, "$env:PROCESSOR_ARCHITECTURE"))

	box := slotBox{slot: slot}
	box.slotRoot = userProfile + `\vfox-e2e-runs\` + slot
	box.tmp = box.slotRoot + `\tmp`
	box.workDir = box.tmp + `\vfox-flutter-e2e`
	box.vfoxExe = box.workDir + `\vfox.exe`
	box.pluginZw = box.workDir + `\flutter.zip`
	box.vars = []string{
		"USERPROFILE=" + box.slotRoot,
		"VFOX_HOME=" + box.slotRoot + `\.vfox`,
		"TEMP=" + box.tmp,
		"TMP=" + box.tmp,
		"PATH=" + box.workDir + ";" + containerPath,
	}

	execOK(ctx, t, ctr, fmt.Sprintf(
		"New-Item -ItemType Directory -Force -Path %s | Out-Null; "+
			"New-Item -ItemType Directory -Force -Path %s | Out-Null",
		pwshQuote(box.tmp), pwshQuote(box.workDir)))
	t.Logf("PASS slot %s isolated at %s (arch %s)", slot, box.slotRoot, procArch)
	return box
}

// procArchOfContainer reports $env:PROCESSOR_ARCHITECTURE (AMD64/ARM64/x86).
func procArchOfContainer(ctx context.Context, t *testing.T, ctr tc.Container) string {
	t.Helper()
	return strings.TrimSpace(execOK(ctx, t, ctr, "$env:PROCESSOR_ARCHITECTURE"))
}

// curlRetry flags shared by every curl.exe download (was setup.ps1).
const curlRetry = "--retry 3 --retry-delay 5 --retry-all-errors"

// installVfoxRelease replicates Install-VfoxRelease: resolve the latest tag,
// download the windows zip, extract, and stage vfox.exe into the work dir.
func installVfoxRelease(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, procArch string) {
	t.Helper()
	effective := strings.TrimSpace(execOK(ctx, t, ctr,
		`curl.exe `+curlRetry+` -fsSLI -o NUL -w '%{url_effective}' https://github.com/version-fox/vfox/releases/latest`,
		box.vars...))
	parts := strings.Split(effective, "/tag/")
	tag := strings.TrimSpace(parts[len(parts)-1])
	if tag == "" {
		t.Fatalf("could not resolve the latest vfox tag from %q", effective)
	}
	vfoxArch := "x86_64"
	if procArch == "ARM64" {
		vfoxArch = "aarch64"
	}
	zipPath := box.workDir + `\vfox.zip`
	url := fmt.Sprintf("https://github.com/version-fox/vfox/releases/download/%s/vfox_%s_windows_%s.zip",
		tag, strings.TrimPrefix(tag, "v"), vfoxArch)
	execOK(ctx, t, ctr, fmt.Sprintf(
		"curl.exe %s -fsSL -o %s %s",
		curlRetry, pwshQuote(zipPath), pwshQuote(url)), box.vars...)
	execOK(ctx, t, ctr, fmt.Sprintf(
		"tar -xf %s -C %s; Remove-Item %s; "+
			"Copy-Item -Path (Get-ChildItem -Path %s -Recurse -Filter 'vfox.exe') -Destination %s",
		pwshQuote(zipPath), pwshQuote(box.workDir), pwshQuote(zipPath),
		pwshQuote(box.workDir), pwshQuote(box.vfoxExe)), box.vars...)
	t.Logf("PASS installed vfox %s (%s)", tag, vfoxArch)
}

// installVfoxMain replicates Install-VfoxMain: install the pinned Go MSI,
// clone vfox, and build vfox.exe. msiexec exit codes 0/3010/1937 all mean
// success (ok / reboot-required / in-use-files), same as setup.ps1.
func installVfoxMain(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, procArch string) {
	t.Helper()
	goArch := "amd64"
	if procArch == "ARM64" {
		goArch = "arm64"
	}
	goMsi := box.tmp + `\go.msi`
	execOK(ctx, t, ctr, fmt.Sprintf(
		"curl.exe %s -fsSL -o %s %s",
		curlRetry, pwshQuote(goMsi),
		pwshQuote(fmt.Sprintf("https://go.dev/dl/go%s.windows-%s.msi", goWindowsVersion, goArch))),
		box.vars...)
	execOK(ctx, t, ctr, fmt.Sprintf(`$goInstall = $null
for ($attempt = 1; $attempt -le 5; $attempt++) {
  $goInstall = Start-Process msiexec.exe -Wait -PassThru -ArgumentList '/i', %s, '/quiet', '/norestart'
  if ($goInstall.ExitCode -in 0, 3010, 1937) { break }
  Start-Sleep -Seconds 15
}
if ($goInstall.ExitCode -notin 0, 3010, 1937) { throw ('FAIL the Go MSI install exited with code ' + $goInstall.ExitCode) }
Remove-Item %s`, pwshQuote(goMsi), pwshQuote(goMsi)), box.vars...)

	src := box.workDir + `\vfox-src`
	execOK(ctx, t, ctr,
		fmt.Sprintf("git clone --depth 1 https://github.com/version-fox/vfox %s", pwshQuote(src)),
		box.vars...)
	execOK(ctx, t, ctr, fmt.Sprintf(
		`& 'C:\Program Files\Go\bin\go.exe' -C %s build -trimpath -o %s .`,
		pwshQuote(src), pwshQuote(box.vfoxExe)), box.vars...)
	t.Logf("PASS built vfox from main with Go %s (%s)", goWindowsVersion, goArch)
}

// setupVfox installs vfox (release, or builds main) and registers the local
// flutter plugin (was setup.ps1).
func setupVfox(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, vfoxVersion string) {
	t.Helper()
	procArch := procArchOfContainer(ctx, t, ctr)
	if vfoxVersion == "main" {
		installVfoxMain(ctx, t, ctr, box, procArch)
	} else {
		installVfoxRelease(ctx, t, ctr, box, procArch)
	}
	execOK(ctx, t, ctr, fmt.Sprintf(
		"tar -a -cf %s -C 'C:\\e2e' metadata.lua hooks lib",
		pwshQuote(box.pluginZw)), box.vars...)
	execOK(ctx, t, ctr,
		fmt.Sprintf("vfox add flutter --source %s", pwshQuote(box.pluginZw)), box.vars...)
}

// fetchActivation captures `vfox activate pwsh` once per container; the
// output is prepended to every later script via activated(), since each exec
// starts a fresh process (same reason run.ps1 dot-sourced it per process).
func fetchActivation(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox) string {
	t.Helper()
	out := execOK(ctx, t, ctr, "vfox activate pwsh", box.vars...)
	if strings.TrimSpace(out) == "" {
		t.Fatal("vfox activate pwsh produced no output")
	}
	return out
}

// activated prepends captured activation code to a script.
func activated(activation, script string) string {
	return activation + "\r\n" + script
}

// activatedEnv is activated plus a fresh `vfox env` export. vfox's pwsh
// activation refreshes the toolchain env lazily through a prompt hook, which
// never runs in non-interactive `pwsh -Command` execs, so each call must pull
// the export explicitly (mirrors what the prompt hook itself runs).
// Only valid after a version is selected via `vfox use`.
func activatedEnv(activation, script string) string {
	return activation + "\r\n$__vfoxExport = vfox env -s pwsh | Out-String; " +
		"if ($__vfoxExport.Trim()) { Invoke-Expression -Command $__vfoxExport }\r\n" + script
}

// checkBogusMirrorRejected proves the plugin honours $FLUTTER_STORAGE_BASE_URL:
// installing through a bogus mirror must fail naming the host.
func checkBogusMirrorRejected(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, flavor, version string) {
	t.Helper()
	if flavor != "official" {
		return
	}
	code, out := execRun(ctx, t, ctr,
		fmt.Sprintf("vfox install %s", pwshQuote("flutter@"+version)),
		withEnv(box, "FLUTTER_STORAGE_BASE_URL="+bogusMirror)...)
	if code == 0 {
		t.Fatalf("bogus mirror install unexpectedly succeeded\n--- output ---\n%s", out)
	}
	require.Contains(t, out, "invalid.example.invalid", "bogus mirror error")
}

// checkBogusGithubMirrorRejected proves the plugin honours
// $VFOX_FLUTTER_GITHUB_MIRROR on ARM64, where official installs from git.
func checkBogusGithubMirrorRejected(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, flavor, version string) {
	t.Helper()
	if flavor != "official" {
		return
	}
	if procArchOfContainer(ctx, t, ctr) != "ARM64" {
		return
	}
	code, out := execRun(ctx, t, ctr,
		fmt.Sprintf("vfox install %s", pwshQuote("flutter@"+version)),
		withEnv(box, "VFOX_FLUTTER_GITHUB_MIRROR="+bogusMirror)...)
	if code == 0 {
		t.Fatalf("bogus GitHub mirror install unexpectedly succeeded\n--- output ---\n%s", out)
	}
	require.Contains(t, out, "invalid.example.invalid", "bogus GitHub mirror error")
}
