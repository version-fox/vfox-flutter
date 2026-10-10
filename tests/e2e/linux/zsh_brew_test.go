// Copyright 2026 Han Li and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package linux

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	tc "github.com/testcontainers/testcontainers-go"

	"github.com/version-fox/vfox-flutter/tests/e2e/common"
)

// This file covers https://github.com/version-fox/vfox/issues/523
// ("macOS M1 Homebrew vfox new tab global version is N/A").
//
// The matrix suite in e2e_test.go installs vfox via install.sh and drives it
// from bash with an explicit `eval "$(vfox activate bash)"` per exec. Issue
// 523 follows a different distribution path: zsh + Linuxbrew/Homebrew +
// `eval "$(vfox activate zsh)"` persisted in ~/.zshrc. A regression there
// (activation not restoring the global version in a fresh shell) would be
// invisible to the matrix suite, so this standalone test reproduces the exact
// user flow in an independent container:
//
//	zsh -> Homebrew (via zsh) -> `brew install vfox` (via zsh) ->
//	pack local plugin -> `vfox add` -> `vfox install/use flutter@<version>`
//	-> assert `flutter --version --no-version-check` and `dart --version`
//	in the current zsh and in a brand-new zsh (login + interactive,
//	simulating a new terminal tab).
//
// The test name starts with TestE2E so the existing CI command
// (`go test -run TestE2E ./linux`, see tests/e2e/linux/compose.yaml) picks
// it up without extra flags. It is skipped in `-short` mode like TestE2E.

const (
	zshBrewTester  = "tester"
	zshBrewPrefix  = "/home/linuxbrew/.linuxbrew"
	zshBrewBin     = zshBrewPrefix + "/bin/brew"
	zshBrewHome    = "/home/tester"
	zshBrewZshrc   = zshBrewHome + "/.zshrc"
	zshBrewPlugin  = "/tmp/flutter-523.zip"
	zshBrewTimeout = 50 * time.Minute
)

// shQuote renders a single-quoted POSIX shell string literal.
func shQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
}

// execZshRun runs script in a fresh zsh-as-tester and returns exit code plus
// combined output. extraEnv entries ("K=V") are prepended as `env` assignments
// inside the tester context so sudo does not strip them.
func execZshRun(ctx context.Context, t *testing.T, ctr tc.Container, script string, login bool, extraEnv ...string) (int, string) {
	t.Helper()
	flag := "-i -c"
	if login {
		flag = "-l -i -c"
	}
	wrapped := "sudo -u " + zshBrewTester
	if len(extraEnv) > 0 {
		quoted := make([]string, 0, len(extraEnv))
		for _, kv := range extraEnv {
			parts := strings.SplitN(kv, "=", 2)
			if len(parts) == 2 {
				quoted = append(quoted, parts[0]+"="+shQuote(parts[1]))
			} else {
				quoted = append(quoted, shQuote(kv))
			}
		}
		wrapped += " env " + strings.Join(quoted, " ")
	}
	wrapped += " zsh " + flag + " " + shQuote(script)
	return execRun(ctx, t, ctr, wrapped)
}

// execZshOK runs script in a fresh zsh and fatals unless it exits 0.
func execZshOK(ctx context.Context, t *testing.T, ctr tc.Container, script string, login bool, extraEnv ...string) string {
	t.Helper()
	code, out := execZshRun(ctx, t, ctr, script, login, extraEnv...)
	if code != 0 {
		t.Fatalf("zsh exec exited with code %d\n--- script ---\n%s\n--- output ---\n%s", code, script, out)
	}
	return out
}

// execZshRetry runs script in a fresh zsh through the shared retry helper.
func execZshRetry(ctx context.Context, t *testing.T, ctr tc.Container, label, script string, login bool, extraEnv ...string) string {
	t.Helper()
	return common.Retry(ctx, t, label, func() (int, string) {
		return execZshRun(ctx, t, ctr, script, login, extraEnv...)
	})
}

// TestE2EZshBrew reproduces issue 523 via zsh + Homebrew + `brew install vfox`.
func TestE2EZshBrew(t *testing.T) {
	if testing.Short() {
		t.Skip("skip container E2E in short mode")
	}
	t.Parallel()

	arch, err := common.DetectArch()
	if err != nil {
		t.Fatal(err)
	}
	platform := "linux/" + arch
	image := "vfox-flutter-e2e:linux-" + arch

	here, err := filepath.Abs(".")
	if err != nil {
		t.Fatal(err)
	}
	repoRoot := filepath.Join(here, "..", "..", "..")

	ctx := context.Background()
	buildImage(t, ctx, repoRoot, image, platform)

	ctr, err := tc.GenericContainer(ctx, tc.GenericContainerRequest{
		ContainerRequest: tc.ContainerRequest{
			Image:         image,
			ImagePlatform: platform,
			Name:          common.ContainerName("zsh-brew-523"),
		},
		Started: true,
	})
	if err != nil {
		t.Fatalf("start container: %v", err)
	}
	t.Cleanup(func() {
		_ = ctr.Terminate(context.Background())
	})

	ctx, cancel := context.WithTimeout(ctx, zshBrewTimeout)
	defer cancel()

	version := common.ResolveFlutterVersion(t, "official")
	if v := os.Getenv("FLUTTER_VERSION"); v != "" {
		version = v
	}
	machine := strings.TrimSpace(execOK(ctx, t, ctr, "uname --machine"))
	t.Logf("=== issue 523: zsh + brew + vfox + flutter %s on %s (%s) ===", version, platform, machine)

	setupZshBrewUser(ctx, t, ctr)
	installBrewViaZsh(ctx, t, ctr)
	brewInstallVfoxViaZsh(ctx, t, ctr)
	addLocalFlutterPluginViaZsh(ctx, t, ctr)
	installFlutterViaZsh(ctx, t, ctr, version)

	// Current terminal: first fresh zsh after `vfox use --global`.
	verifyZshToolchain(ctx, t, ctr, version, "current", false)
	// New terminal tab: brand-new login+interactive zsh, same assertions.
	// macOS Terminal opens login shells; covering `-l -i` proves ~/.zshrc
	// alone (the documented setup) restores the global version without
	// needing ~/.zprofile workarounds from the issue thread.
	verifyZshToolchain(ctx, t, ctr, version, "new-tab", true)

	t.Log("PASS issue 523: flutter/dart survive a fresh zsh via Homebrew vfox")
}

func setupZshBrewUser(ctx context.Context, t *testing.T, ctr tc.Container) {
	t.Helper()
	execOK(ctx, t, ctr,
		"apt-get update && apt-get install --assume-yes "+
			"zsh curl git sudo build-essential procps file zip unzip xz-utils ca-certificates")
	execOK(ctx, t, ctr, "zsh --version")
	execOK(ctx, t, ctr,
		"id tester 2>/dev/null || useradd -m -s /usr/bin/zsh tester; "+
			"echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester; "+
			"chmod 440 /etc/sudoers.d/tester; id tester")
	t.Log("PASS zsh + brew build deps ready with non-root tester user")
}

func installBrewViaZsh(ctx context.Context, t *testing.T, ctr tc.Container) {
	t.Helper()
	// Driven from zsh on purpose: the issue flow installs Homebrew from a zsh
	// terminal, so the parent shell here is `zsh -c` (the payload itself
	// re-execs bash, exactly like the official installer snippet pasted into
	// a zsh prompt).
	execZshRetry(ctx, t, ctr, "install homebrew via zsh",
		`NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`,
		false)
	execOK(ctx, t, ctr, "test -x "+shQuote(zshBrewBin)+" && "+shQuote(zshBrewBin)+" --version")
	// Brew shellenv must come before the vfox hook so fresh shells find brew
	// (and later vfox) on PATH. Single-quote the payload so the outer bash
	// writes it literally instead of expanding $().
	brewLine := `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"`
	execOK(ctx, t, ctr, "touch "+shQuote(zshBrewZshrc)+
		" && grep -qF 'brew shellenv' "+shQuote(zshBrewZshrc)+
		" || printf '%s\\n' "+shQuote(brewLine)+" >> "+shQuote(zshBrewZshrc)+
		"; chown tester:tester "+shQuote(zshBrewZshrc)+"; cat "+shQuote(zshBrewZshrc))
	out := execZshOK(ctx, t, ctr, "brew --version", false)
	t.Logf("PASS Homebrew installed via zsh:\n%s", strings.TrimSpace(out))
}

func brewInstallVfoxViaZsh(ctx context.Context, t *testing.T, ctr tc.Container) {
	t.Helper()
	execZshRetry(ctx, t, ctr, "brew install vfox via zsh", "brew install vfox", false)
	vfoxVersion := strings.TrimSpace(execZshOK(ctx, t, ctr, "vfox --version", false))
	t.Logf("PASS `brew install vfox` via zsh: %s", vfoxVersion)
	// Persist the documented zsh hook. A fresh `zsh -i -c` sources ~/.zshrc,
	// so every later execZsh* call exercises the same activation path as a
	// new terminal tab in the issue.
	vfoxLine := `eval "$(vfox activate zsh)"`
	execOK(ctx, t, ctr, "grep -qF 'vfox activate zsh' "+shQuote(zshBrewZshrc)+
		" || printf '%s\\n' "+shQuote(vfoxLine)+" >> "+shQuote(zshBrewZshrc)+
		"; chown tester:tester "+shQuote(zshBrewZshrc)+"; cat "+shQuote(zshBrewZshrc))
	activated := strings.TrimSpace(execZshOK(ctx, t, ctr, "vfox --version", false))
	require.Equal(t, vfoxVersion, activated, "fresh zsh must see the Homebrew vfox")
	// Also prove a login shell (macOS new-tab semantics) sees it.
	loginVfox := strings.TrimSpace(execZshOK(ctx, t, ctr, "vfox --version", true))
	require.Equal(t, vfoxVersion, loginVfox, "fresh login zsh must see the Homebrew vfox")
}

func addLocalFlutterPluginViaZsh(ctx context.Context, t *testing.T, ctr tc.Container) {
	t.Helper()
	execOK(ctx, t, ctr, fmt.Sprintf(
		"(cd /e2e && zip -qr %q metadata.lua hooks lib) && chown tester:tester %q && ls -la %q",
		zshBrewPlugin, zshBrewPlugin, zshBrewPlugin))
	execZshOK(ctx, t, ctr, "vfox add flutter --source "+shQuote(zshBrewPlugin), false)
	t.Log("PASS local vfox-flutter plugin added via zsh + Homebrew vfox")
}

func installFlutterViaZsh(ctx context.Context, t *testing.T, ctr tc.Container, version string) {
	t.Helper()
	execZshRetry(ctx, t, ctr, fmt.Sprintf("vfox install flutter@%s via zsh", version),
		"vfox install flutter@"+version, false)
	execZshOK(ctx, t, ctr, "vfox use --global flutter@"+version, false)
	current := execZshOK(ctx, t, ctr, "vfox current", false)
	t.Logf("--- vfox current after use --global ---\n%s", current)
	require.Contains(t, current, "flutter", "vfox current must list flutter after --global")
	require.NotContains(t, current, "N/A", "vfox current must not be N/A (issue 523)")
}

func verifyZshToolchain(ctx context.Context, t *testing.T, ctr tc.Container, version, label string, login bool) {
	t.Helper()
	shellKind := "zsh -i"
	if login {
		shellKind = "zsh -l -i"
	}
	execZshRetry(ctx, t, ctr, "pub.dev reachable",
		"curl --fail --silent --show-error --location --max-time 20 --output /dev/null https://pub.dev/api/packages/args",
		login)

	current := execZshOK(ctx, t, ctr, "vfox current", login)
	require.Contains(t, current, "flutter", label+" "+shellKind+" vfox current")
	require.NotContains(t, current, "N/A", label+" "+shellKind+" vfox current N/A (issue 523)")

	flutter := execZshRetry(ctx, t, ctr, label+" "+shellKind+" flutter --version",
		"flutter --version --no-version-check", login)
	// NOTE: linux/arm64 official installs are source checkouts (no prebuilt
	// flutter_tools.snapshot), so `flutter --version` reports
	// `Flutter • channel [user-branch] • unknown source` instead of
	// `Flutter 3.47.4 • channel stable` (see docs/arm64.md and the SKIP in
	// verifyFirstRunMatchesOfficial). Assert the stable markers that hold on
	// both archive (amd64) and source (arm64) installs.
	require.Contains(t, flutter, "Framework • revision", label+" flutter framework")
	require.Contains(t, flutter, "Tools • Dart", label+" flutter tools")

	dart := execZshRetry(ctx, t, ctr, label+" "+shellKind+" dart --version",
		"dart --version", login)
	dartWant := common.ToolsDart(flutter)
	if dartWant == "" {
		t.Fatalf("%s %s: flutter --version has no Tools line\n--- actual ---\n%s", label, shellKind, flutter)
	}
	require.Contains(t, dart, dartWant, label+" "+shellKind+" dart --version")

	t.Logf("PASS [%s via %s] flutter %s + dart %s", label, shellKind, version, dartWant)
}
