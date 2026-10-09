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

package windows

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	tc "github.com/testcontainers/testcontainers-go"

	"github.com/version-fox/vfox-flutter/tests/e2e/common"
)

// NOTE: the drift-warning strings asserted here are part of the plugin's
// user-facing contract (see hooks/ lib/). If the Lua side rewords them,
// update this file and tests/e2e/linux/verify.go together.

// winDir is filepath.Dir for container paths, which always use backslashes
// even when the test binary itself runs on a non-Windows host.
func winDir(p string) string {
	p = strings.TrimSuffix(strings.TrimSpace(p), `\`)
	if i := strings.LastIndexByte(p, '\\'); i >= 0 {
		return p[:i]
	}
	return p
}

// sdkDir prints the SDK root for the active flutter on PATH: the parent of
// the parent of the flutter application (was verify.Tests.ps1 BeforeAll).
func sdkDir(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, activation string) string {
	t.Helper()
	flutter := strings.TrimSpace(execOK(ctx, t, ctr,
		activatedEnv(activation, "(Get-Command flutter -CommandType Application | Select-Object -First 1).Source"),
		box.vars...))
	return winDir(winDir(flutter))
}

// verifySdkLayout asserts the installed SDK shape: pristine for official, a
// git checkout with tracked engine pins for OpenHarmony.
func verifySdkLayout(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, flavor, sdk string) {
	t.Helper()
	if flavor == "official" {
		subject := execOK(ctx, t, ctr,
			"git -C "+pwshQuote(sdk)+" log -1 --format=%s", box.vars...)
		require.NotContains(t, subject, "vfox install", "the official SDK carries no vfox commit")
		return
	}
	isGit := strings.TrimSpace(execOK(ctx, t, ctr,
		"Test-Path "+pwshQuote(sdk+`\.git`), box.vars...))
	require.Equal(t, "True", isGit, "the OpenHarmony SDK is not a git checkout")
	pins := execOK(ctx, t, ctr,
		"git -C "+pwshQuote(sdk)+" ls-files bin/internal/engine.version", box.vars...)
	require.Contains(t, pins, "bin/internal/engine.version", "the OpenHarmony engine version pin is not tracked")
	t.Log("PASS the OpenHarmony SDK is a git checkout with its engine pins tracked")
}

// manifestAnchor reads .vfox-manifest and returns its expected_head.
func manifestAnchor(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, sdk string) string {
	t.Helper()
	raw := execOK(ctx, t, ctr,
		"Get-Content -Raw "+pwshQuote(sdk+`\.vfox-manifest`), box.vars...)
	var m common.Manifest
	if err := json.Unmarshal([]byte(raw), &m); err != nil {
		t.Fatalf("the .vfox-manifest is not valid JSON: %v\n--- actual ---\n%s", err, raw)
	}
	require.NotEmpty(t, m.ExpectedHead, "the .vfox-manifest has no expected_head")
	return m.ExpectedHead
}

// verifyManifestDrift anchors the installed HEAD via .vfox-manifest, proves
// `vfox use` reports drift exactly when the SDK moves (simulated
// `flutter upgrade`), and goes quiet again once restored.
func verifyManifestDrift(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, activation, version, sdk string) {
	t.Helper()
	anchor := manifestAnchor(ctx, t, ctr, box, sdk)
	t.Log("PASS the SDK carries a .vfox-manifest")

	installedHead := strings.TrimSpace(execOK(ctx, t, ctr,
		"git -C "+pwshQuote(sdk)+" rev-parse HEAD", box.vars...))
	require.Equal(t, installedHead, anchor, "the .vfox-manifest anchor does not match the installed git HEAD")
	t.Log("PASS the .vfox-manifest anchor matches the installed git HEAD")

	use := func() string {
		return execOK(ctx, t, ctr,
			activatedEnv(activation, fmt.Sprintf("vfox use --global %s", pwshQuote("flutter@"+version))),
			box.vars...)
	}

	require.NotContains(t, use(), "has drifted", "a freshly installed SDK reports no drift")

	execOK(ctx, t, ctr,
		"git -C "+pwshQuote(sdk)+" commit --allow-empty -q -m 'simulated flutter upgrade'",
		withEnv(box,
			"GIT_AUTHOR_NAME=e2e",
			"GIT_AUTHOR_EMAIL=e2e@vfox.flutter",
			"GIT_COMMITTER_NAME=e2e",
			"GIT_COMMITTER_EMAIL=e2e@vfox.flutter")...)
	driftedHead := strings.TrimSpace(execOK(ctx, t, ctr,
		"git -C "+pwshQuote(sdk)+" rev-parse HEAD", box.vars...))

	drifted := use()
	require.Contains(t, drifted, "has drifted from the version vfox installed", "drift warning")
	require.Contains(t, drifted, anchor, "drift warning expected head")
	require.Contains(t, drifted, driftedHead, "drift warning current head")
	require.Contains(t, drifted, "vfox uninstall flutter@"+version, "drift warning restore command")
	require.Contains(t, drifted, "vfox install  flutter@"+version, "drift warning restore command")
	require.Contains(t, drifted, "vfox use      flutter@"+version, "drift warning restore command")
	require.Contains(t, drifted, "vfox install flutter@<new-version>", "drift warning upgrade command")

	execOK(ctx, t, ctr,
		"git -C "+pwshQuote(sdk)+" reset -q --hard "+pwshQuote(anchor), box.vars...)
	require.NotContains(t, use(), "has drifted", "a restored SDK reports no drift")
}

// NOTE: there is deliberately no first-run rebuild check on Windows.
// Issue #37 is Linux-specific: the Linux tarball ships a flutter_tools.stamp
// matching its git HEAD, so the official first run skips the tool rebuild.
// The Windows release zip instead ships a stale stamp (e.g. 3.47.5 carries
// "fa78ae3..." while its HEAD is 6a19cca...), so the official Windows
// first run always rebuilds too and vfox already matches it.

// verifyToolchain boots the toolchain (pub.dev reachable) and checks the
// dart/flutter versions agree with each other and the SDK checkout.
func verifyToolchain(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, activation, sdk string) {
	t.Helper()
	execRetry(ctx, t, ctr, "pub.dev",
		"curl.exe -fsSL --max-time 20 -o NUL https://pub.dev/api/packages/args",
		box.vars...)
	dart := execRetry(ctx, t, ctr, "dart --version",
		activatedEnv(activation, "dart --version"), box.vars...)
	flutter := execRetry(ctx, t, ctr, "flutter --version",
		activatedEnv(activation, "flutter --version --no-version-check"), box.vars...)

	head := strings.TrimSpace(execOK(ctx, t, ctr,
		"git -C "+pwshQuote(sdk)+" rev-parse HEAD", box.vars...))
	require.Contains(t, flutter, head[:10], "flutter --version revision")

	dartWant := common.ToolsDart(flutter)
	require.NotEmpty(t, dartWant, "flutter --version has no Tools line:\n"+flutter)
	require.Contains(t, dart, dartWant, "dart --version")
}
