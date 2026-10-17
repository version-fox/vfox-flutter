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

// Package windows is the Windows container E2E suite, driven entirely from
// Go via testcontainers-go.
//
// TestE2E builds the image in tests/e2e/windows/Dockerfile once (and vfox
// main alongside it, see vfoxmain.go), then runs one long-lived container
// per (vfox version x flavor x mirror) combination and drives setup ->
// install -> verify through pwsh exec calls (setup.go, install.go,
// verify.go), asserting in Go. Target-independent logic (matrix expansion
// and friends) is reused from the common package.
package windows

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/containerd/platforms"
	specs "github.com/opencontainers/image-spec/specs-go/v1"
	tc "github.com/testcontainers/testcontainers-go"

	client "github.com/moby/moby/client"

	"github.com/version-fox/vfox-flutter/tests/e2e/common"
)

// TestE2E builds the image once, then runs one container per matrix combo.
// Bounded parallelism via common.RunCombos (E2E_MAX_JOBS), slowest first.
//
// Full matrix runs in CI; locally scope it down, e.g.:
// VFOX_VERSION=latest FLAVOR=official MIRROR=default E2E_MAX_JOBS=1 go test -v ./windows/
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("skip container E2E in short mode")
	}
	// Ryuk has no Windows image, so the reaper can never start here.
	// Every container is terminated explicitly via t.Cleanup instead.
	t.Setenv("TESTCONTAINERS_RYUK_DISABLED", "true")

	arch, err := common.DetectArch()
	if err != nil {
		t.Fatal(err)
	}
	platform := "windows/" + arch
	image := "vfox-flutter-e2e:windows-" + arch
	baseImage := "mcr.microsoft.com/windows/servercore:ltsc2025-KB5122871-" + arch

	here, err := filepath.Abs(".")
	if err != nil {
		t.Fatal(err)
	}
	repoRoot := filepath.Join(here, "..", "..", "..")

	combos, err := common.Matrix()
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) == 0 {
		t.Fatal("empty matrix: nothing to run")
	}

	// vfox main builds in the background while the image does.
	var vfoxMain *vfoxMainBuild
	if slices.ContainsFunc(combos, func(c common.Combo) bool { return c.Vfox == "main" }) {
		vfoxMain = startVfoxMainBuild(t.Context(), t.TempDir(), arch)
	}

	ctx := context.Background()
	buildImage(t, ctx, repoRoot, image, platform, baseImage)

	common.RunCombos(t, common.SlowestFirst(combos), maxJobs(), func(t *testing.T, c common.Combo) {
		runOne(t, ctx, image, platform, c, vfoxMain)
	})
}

// buildImage replicates `docker build --pull --platform $platform
// --build-arg BASE_IMAGE=$baseImage -f tests/e2e/windows/Dockerfile
// -t $image $repoRoot`.
func buildImage(t *testing.T, ctx context.Context, repoRoot, image, platform, baseImage string) {
	t.Helper()

	provider, err := tc.NewDockerProvider()
	if err != nil {
		t.Fatalf("new docker provider: %v", err)
	}
	t.Cleanup(func() { _ = provider.Close() })

	pf, err := platforms.Parse(platform)
	if err != nil {
		t.Fatalf("invalid platform %s: %v", platform, err)
	}

	tag, err := provider.BuildImage(ctx, &tc.ContainerRequest{
		FromDockerfile: tc.FromDockerfile{
			Context:        repoRoot,
			Dockerfile:     "tests/e2e/windows/Dockerfile",
			Repo:           "vfox-flutter-e2e",
			Tag:            image[strings.LastIndex(image, ":")+1:],
			BuildArgs:      map[string]*string{"BASE_IMAGE": &baseImage},
			KeepImage:      true,
			BuildLogWriter: os.Stdout,
			BuildOptionsModifier: func(opts *client.ImageBuildOptions) {
				opts.Platforms = []specs.Platform{pf}
				opts.PullParent = true
			},
		},
	})
	if err != nil {
		t.Fatalf("build image %s: %v", image, err)
	}
	if tag != image {
		t.Fatalf("built tag %s, want %s", tag, image)
	}
}

// runOne starts one long-lived container per combo and drives the whole
// E2E flow (setup -> preflight -> install -> verify) through pwsh exec
// calls, asserting in Go. A combo passes when every phase exits 0 and the
// outputs carry the expected markers. Every combo runs against a VFOX_HOME
// containing a space (see spacedVfoxHome); main combos also receive the
// vfox.exe built from main (vfoxMainStaged).
func runOne(t *testing.T, ctx context.Context, image, platform string, c common.Combo, vfoxMain *vfoxMainBuild) {
	t.Helper()
	prefix := c.Prefix(platform)

	env := map[string]string{
		"VFOX_VERSION":  c.Vfox,
		"FLAVOR":        c.Flavor,
		"VFOX_E2E_SLOT": c.Slug(),
	}
	if c.Mirror != "default" {
		env["FLUTTER_STORAGE_BASE_URL"] = c.Mirror
	}
	for _, name := range common.PassThroughEnvs {
		if v, ok := os.LookupEnv(name); ok && v != "" {
			env[name] = v
		}
	}

	// Stock Windows daemons have no "bridge" network (only "nat"), and
	// CreateContainer unconditionally ensures the provider's default bridge
	// network, creating it when missing. Point it at "nat" — the daemon
	// default that plain `docker run` also uses — or every start fails with
	// "could not find plugin bridge".
	provider, err := tc.NewDockerProvider(tc.WithDefaultBridgeNetwork("nat"))
	if err != nil {
		t.Fatalf("[%s] new docker provider: %v", prefix, err)
	}
	req := tc.ContainerRequest{
		Image:         image,
		ImagePlatform: platform,
		Name:          common.ContainerName(c.Slug()),
		Env:           env,
	}
	if c.Vfox == "main" {
		// Copied in before the container starts, which Hyper-V isolated
		// containers (the Windows client default) also allow.
		req.Files = []tc.ContainerFile{{
			HostFilePath:      vfoxMain.wait(t),
			ContainerFilePath: vfoxMainStaged,
			FileMode:          0o755,
		}}
	}
	// NB: no provider.Close here: the container below terminates through
	// this very provider in t.Cleanup.
	ctr, err := provider.RunContainer(ctx, req)
	if err != nil {
		t.Fatalf("[%s] start container: %v", prefix, err)
	}
	// The idle pwsh loop ignores the stop signal, so a graceful stop only
	// waits out its timeout: kill right away instead.
	common.Cleanup(t, func() {
		_ = ctr.Terminate(context.Background(), tc.StopTimeout(0))
	})

	// One overall budget per combo; the CI job timeout stays the outer bound.
	ctx, cancel := context.WithTimeout(ctx, 45*time.Minute)
	defer cancel()

	flavor := c.Flavor
	mirror := c.Mirror
	version := common.ResolveFlutterVersion(t, flavor)
	procArch := procArchOfContainer(ctx, t, ctr)
	t.Logf("=== vfox %s, flutter %s, %s, mirror %s, %s ===", c.Vfox, version, flavor, mirror, procArch)

	box := setupSlotEnv(ctx, t, ctr, c.Slug())
	checkMirrorReachable(ctx, t, ctr, flavor, mirror)
	setupVfox(ctx, t, ctr, box, c.Vfox)
	checkBogusMirrorRejected(ctx, t, ctr, box, flavor, version)
	checkBogusGithubMirrorRejected(ctx, t, ctr, box, flavor, version)

	activation := fetchActivation(ctx, t, ctr, box)
	installFlutterVersion(ctx, t, ctr, box, version)

	sdk := sdkDir(ctx, t, ctr, box, activation)
	verifySdkLayout(ctx, t, ctr, box, flavor, sdk)
	verifyManifestDrift(ctx, t, ctr, box, activation, version, sdk)
	verifyToolchain(ctx, t, ctr, box, activation, sdk)
}
