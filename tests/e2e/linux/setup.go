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
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	tc "github.com/testcontainers/testcontainers-go"
)

// releasesIndex mirrors config.sh releases_index_for_mirror for linux.
func releasesIndex(mirror string) string {
	return strings.TrimSuffix(mirror, "/") + "/flutter_infra_release/releases/releases_linux.json"
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
		fmt.Sprintf("curl --fail --silent --show-error --location --max-time 20 --output /dev/null %q", index))
	t.Logf("PASS mirror %s serves the releases index", mirror)
}

// setupVfox installs vfox (release, or builds main with the in-image Go
// toolchain) and registers the local flutter plugin.
func setupVfox(ctx context.Context, t *testing.T, ctr tc.Container, vfoxVersion string) {
	t.Helper()
	work := strings.TrimSpace(execOK(ctx, t, ctr, "mktemp --directory"))
	// The container is removed after the test, but clean up anyway so
	// repeated local runs don't leak /tmp.
	defer func() {
		_, _ = execRun(ctx, t, ctr, fmt.Sprintf("rm --recursive --force %q", work))
	}()

	if vfoxVersion == "main" {
		execOK(ctx, t, ctr, fmt.Sprintf(
			"git clone --depth 1 https://github.com/version-fox/vfox %q/src && (cd %q/src && CGO_ENABLED=0 go build -trimpath -o /usr/local/bin/vfox .)",
			work, work))
	} else {
		execOK(ctx, t, ctr,
			"curl --fail --silent --show-error --location https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash")
	}
	execOK(ctx, t, ctr, fmt.Sprintf(
		"(cd /e2e && zip -qr %q/flutter.zip metadata.lua hooks lib) && vfox add flutter --source %q/flutter.zip",
		work, work))
}

// checkBogusMirrorRejected proves the plugin honours $FLUTTER_STORAGE_BASE_URL:
// installing through a bogus mirror must fail naming the host.
func checkBogusMirrorRejected(ctx context.Context, t *testing.T, ctr tc.Container, flavor, version string) {
	t.Helper()
	if flavor != "official" {
		return
	}
	bogus := "https://invalid.example.invalid"
	code, out := execRun(ctx, t, ctr,
		fmt.Sprintf("vfox install flutter@%s", version),
		"FLUTTER_STORAGE_BASE_URL="+bogus)
	if code == 0 {
		t.Fatalf("bogus mirror install unexpectedly succeeded\n--- output ---\n%s", out)
	}
	require.Contains(t, out, "invalid.example.invalid", "bogus mirror error")
}

// checkBogusGithubMirrorRejected proves the plugin honours
// $VFOX_FLUTTER_GITHUB_MIRROR on ARM64, where official installs from git.
func checkBogusGithubMirrorRejected(ctx context.Context, t *testing.T, ctr tc.Container, flavor, version string) {
	t.Helper()
	if flavor != "official" {
		return
	}
	machine := strings.TrimSpace(execOK(ctx, t, ctr, "uname --machine"))
	if machine != "aarch64" {
		return
	}
	bogus := "https://invalid.example.invalid"
	code, out := execRun(ctx, t, ctr,
		fmt.Sprintf("vfox install flutter@%s", version),
		"VFOX_FLUTTER_GITHUB_MIRROR="+bogus)
	if code == 0 {
		t.Fatalf("bogus GitHub mirror install unexpectedly succeeded\n--- output ---\n%s", out)
	}
	require.Contains(t, out, "invalid.example.invalid", "bogus GitHub mirror error")
}
