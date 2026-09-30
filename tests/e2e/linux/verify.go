package e2e

import (
	"context"
	"encoding/json"
	"fmt"
	"path"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	tc "github.com/testcontainers/testcontainers-go"
)

// NOTE: the drift-warning strings asserted here are part of the plugin's
// user-facing contract (see hooks/ lib/). If the Lua side rewords them,
// update this file and tests/e2e/windows/verify.Tests.ps1 together.

// sdkDir prints the SDK root for the active flutter on PATH
// (was lib.sh sdk_dir).
func sdkDir(ctx context.Context, t *testing.T, ctr tc.Container) string {
	t.Helper()
	flutter := strings.TrimSpace(execOK(ctx, t, ctr, activated("command -v flutter")))
	return path.Dir(path.Dir(flutter))
}

// verifySdkLayout asserts the installed SDK shape: pristine for official, a
// git checkout with tracked engine pins for OpenHarmony.
func verifySdkLayout(ctx context.Context, t *testing.T, ctr tc.Container, flavor, sdk string) {
	t.Helper()
	if flavor == "official" {
		subject := execOK(ctx, t, ctr, fmt.Sprintf("git -C %q log --max-count=1 --format=%%s", sdk))
		require.NotContains(t, subject, "vfox install", "the official SDK carries no vfox commit")
		return
	}
	if code, out := execRun(ctx, t, ctr, fmt.Sprintf("test -d %q/.git", sdk)); code != 0 {
		t.Fatalf("the OpenHarmony SDK is not a git checkout\n--- output ---\n%s", out)
	}
	pins := execOK(ctx, t, ctr, fmt.Sprintf("git -C %q ls-files bin/internal/engine.version", sdk))
	if strings.TrimSpace(pins) == "" {
		t.Fatal("the OpenHarmony engine version pin is not tracked")
	}
	t.Log("PASS the OpenHarmony SDK is a git checkout with its engine pins tracked")
}

// manifest is the anchored-install record the plugin writes into the SDK.
type manifest struct {
	ExpectedHead string `json:"expected_head"`
}

// verifyManifestDrift anchors the installed HEAD via .vfox-manifest, proves
// `vfox use` reports drift exactly when the SDK moves (simulated
// `flutter upgrade`), and goes quiet again once restored.
func verifyManifestDrift(ctx context.Context, t *testing.T, ctr tc.Container, version, sdk string) {
	t.Helper()
	manifestPath := sdk + "/.vfox-manifest"
	raw := execOK(ctx, t, ctr, fmt.Sprintf("cat %q", manifestPath))
	var m manifest
	if err := json.Unmarshal([]byte(raw), &m); err != nil {
		t.Fatalf("the .vfox-manifest is not valid JSON: %v\n--- actual ---\n%s", err, raw)
	}
	if m.ExpectedHead == "" {
		t.Fatal("the .vfox-manifest has no expected_head")
	}
	anchor := m.ExpectedHead
	t.Log("PASS the SDK carries a .vfox-manifest")

	installedHead := strings.TrimSpace(execOK(ctx, t, ctr, fmt.Sprintf("git -C %q rev-parse HEAD", sdk)))
	if anchor != installedHead {
		t.Fatalf("the .vfox-manifest anchor %s does not match the installed git HEAD %s", anchor, installedHead)
	}
	t.Log("PASS the .vfox-manifest anchor matches the installed git HEAD")

	use := func() string {
		return execOK(ctx, t, ctr, activated(fmt.Sprintf("vfox use --global flutter@%s", version)))
	}

	require.NotContains(t, use(), "has drifted", "a freshly installed SDK reports no drift")

	execOK(ctx, t, ctr, fmt.Sprintf("git -C %q commit --allow-empty --quiet -m 'simulated flutter upgrade'", sdk),
		"GIT_AUTHOR_NAME=e2e",
		"GIT_AUTHOR_EMAIL=e2e@vfox.flutter",
		"GIT_COMMITTER_NAME=e2e@vfox.flutter",
		"GIT_COMMITTER_EMAIL=e2e@vfox.flutter")
	driftedHead := strings.TrimSpace(execOK(ctx, t, ctr, fmt.Sprintf("git -C %q rev-parse HEAD", sdk)))

	drifted := use()
	require.Contains(t, drifted, "has drifted from the version vfox installed", "drift warning")
	require.Contains(t, drifted, anchor, "drift warning expected head")
	require.Contains(t, drifted, driftedHead, "drift warning current head")
	require.Contains(t, drifted, "vfox uninstall flutter@"+version, "drift warning restore command")
	require.Contains(t, drifted, "vfox install  flutter@"+version, "drift warning restore command")
	require.Contains(t, drifted, "vfox use      flutter@"+version, "drift warning restore command")
	require.Contains(t, drifted, "vfox install flutter@<new-version>", "drift warning upgrade command")

	execOK(ctx, t, ctr, fmt.Sprintf("git -C %q reset --quiet --hard %q", sdk, anchor))
	require.NotContains(t, use(), "has drifted", "a restored SDK reports no drift")
}

// toolsDart extracts the Dart version from `flutter --version` output
// (was: awk '/Tools/ { print $4 }').
func toolsDart(flutterVersion string) string {
	for _, line := range strings.Split(flutterVersion, "\n") {
		if strings.Contains(line, "Tools") {
			if f := strings.Fields(line); len(f) >= 4 {
				return f[3]
			}
		}
	}
	return ""
}

// verifyToolchain boots the toolchain (pub.dev reachable) and checks the
// dart/flutter versions agree with each other and the SDK checkout.
func verifyToolchain(ctx context.Context, t *testing.T, ctr tc.Container, sdk string) {
	t.Helper()
	execRetry(ctx, t, ctr, "pub.dev",
		"curl --fail --silent --show-error --location --max-time 20 --output /dev/null https://pub.dev/api/packages/args")
	dart := execRetry(ctx, t, ctr, "dart --version", activated("dart --version"))
	flutter := execRetry(ctx, t, ctr, "flutter --version", activated("flutter --version --no-version-check"))

	head := strings.TrimSpace(execOK(ctx, t, ctr, fmt.Sprintf("git -C %q rev-parse HEAD", sdk)))
	require.Contains(t, flutter, head[:10], "flutter --version revision")

	dartWant := toolsDart(flutter)
	if dartWant == "" {
		t.Fatalf("flutter --version has no Tools line\n--- actual ---\n%s", flutter)
	}
	require.Contains(t, dart, dartWant, "dart --version")
}
