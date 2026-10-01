package e2e

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/containerd/platforms"
	specs "github.com/opencontainers/image-spec/specs-go/v1"
	tc "github.com/testcontainers/testcontainers-go"

	client "github.com/moby/moby/client"
)

// passThroughEnvs are host env knobs the suite honours. Forwarded only when
// set, so unset stays default. (The old e2e.ps1 only passed VFOX_VERSION,
// FLAVOR, VFOX_E2E_SLOT and FLUTTER_STORAGE_BASE_URL into the container;
// forwarding the rest is a strict improvement shared with the Linux suite.)
var passThroughEnvs = []string{
	"FLUTTER_VERSION",
	"OHOS_VERSION",
	"VFOX_FLUTTER_GITHUB_MIRROR",
	"E2E_RETRY_ATTEMPTS",
}

// TestE2E builds the image once, then runs one container per matrix combo.
// Bounded parallelism via t.Parallel + semaphore (like E2E_MAX_JOBS).
//
// Full matrix runs in CI; locally scope it down, e.g.:
// VFOX_VERSION=latest FLAVOR=official MIRROR=default E2E_MAX_JOBS=1 go test -v
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("skip container E2E in short mode")
	}
	// Ryuk has no Windows image, so the reaper can never start here.
	// Every container is terminated explicitly via t.Cleanup instead.
	t.Setenv("TESTCONTAINERS_RYUK_DISABLED", "true")

	arch, err := detectArch()
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

	ctx := context.Background()
	buildImage(t, ctx, repoRoot, image, platform, baseImage)

	combos, err := matrix()
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) == 0 {
		t.Fatal("empty matrix: nothing to run")
	}

	sem := make(chan struct{}, maxJobs())
	for _, c := range combos {
		c := c
		t.Run(c.slug(), func(t *testing.T) {
			t.Parallel()
			sem <- struct{}{}
			defer func() { <-sem }()
			runOne(t, ctx, image, platform, c)
		})
	}
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

// containerName returns a unique container name per run: the combo slug stays
// greppable in `docker ps`, the random suffix avoids clashes with leftovers
// from killed runs (the old ps1 runner detached anonymous names per batch).
func containerName(c combo) string {
	var b [4]byte
	if _, err := rand.Read(b[:]); err != nil {
		return fmt.Sprintf("vfox-flutter-e2e-%s-%d", c.slug(), time.Now().UnixNano())
	}
	return "vfox-flutter-e2e-" + c.slug() + "-" + hex.EncodeToString(b[:])
}

// runOne starts one long-lived container per combo and drives the whole
// E2E flow (setup -> preflight -> install -> verify) through pwsh exec
// calls, asserting in Go. A combo passes when every phase exits 0 and the
// outputs carry the expected markers (same bar as the old e2e.ps1).
func runOne(t *testing.T, ctx context.Context, image, platform string, c combo) {
	t.Helper()
	prefix := c.prefix(platform)

	env := map[string]string{
		"VFOX_VERSION":  c.vfox,
		"FLAVOR":        c.flavor,
		"VFOX_E2E_SLOT": c.slug(),
	}
	if c.mirror != "default" {
		env["FLUTTER_STORAGE_BASE_URL"] = c.mirror
	}
	for _, name := range passThroughEnvs {
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
	// NB: no provider.Close here: the container below terminates through
	// this very provider in t.Cleanup.
	ctr, err := provider.RunContainer(ctx, tc.ContainerRequest{
		Image:         image,
		ImagePlatform: platform,
		Name:          containerName(c),
		Env:           env,
	})
	if err != nil {
		t.Fatalf("[%s] start container: %v", prefix, err)
	}
	t.Cleanup(func() {
		_ = ctr.Terminate(context.Background())
	})

	// One overall budget per combo; the CI job timeout stays the outer bound.
	ctx, cancel := context.WithTimeout(ctx, 45*time.Minute)
	defer cancel()

	flavor := c.flavor
	mirror := c.mirror
	version := resolveFlutterVersion(t, flavor)
	procArch := procArchOfContainer(ctx, t, ctr)
	t.Logf("=== vfox %s, flutter %s, %s, mirror %s, %s ===", c.vfox, version, flavor, mirror, procArch)

	box := setupSlotEnv(ctx, t, ctr, c.slug())
	checkMirrorReachable(ctx, t, ctr, flavor, mirror)
	setupVfox(ctx, t, ctr, box, c.vfox)
	checkBogusMirrorRejected(ctx, t, ctr, box, flavor, version)
	checkBogusGithubMirrorRejected(ctx, t, ctr, box, flavor, version)

	activation := fetchActivation(ctx, t, ctr, box)
	installFlutterVersion(ctx, t, ctr, box, version)

	sdk := sdkDir(ctx, t, ctr, box, activation)
	verifySdkLayout(ctx, t, ctr, box, flavor, sdk)
	verifyManifestDrift(ctx, t, ctr, box, activation, version, sdk)
	verifyToolchain(ctx, t, ctr, box, activation, sdk)
}
