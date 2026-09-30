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

// passThroughEnvs are host env knobs the in-container scripts (run.sh and
// friends) honour. Forwarded only when set, so unset stays default.
var passThroughEnvs = []string{
	"FLUTTER_VERSION",
	"OHOS_VERSION",
	"VFOX_FLUTTER_GITHUB_MIRROR",
	"E2E_RETRY_ATTEMPTS",
}

// TestE2E builds the image once, then runs one container per matrix combo.
// Bounded parallelism via t.Parallel + semaphore (like E2E_MAX_JOBS).
//
// Full matrix (~45min) runs in CI; locally scope it down, e.g.:
// VFOX_VERSION=latest FLAVOR=official MIRROR=default E2E_MAX_JOBS=1 go test -v
func TestE2E(t *testing.T) {
	if testing.Short() {
		t.Skip("skip container E2E in short mode")
	}

	arch, err := detectArch()
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
// --file tests/e2e/linux/Dockerfile --tag $image $repoRoot`.
func buildImage(t *testing.T, ctx context.Context, repoRoot, image, platform string) {
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
			Dockerfile:     "tests/e2e/linux/Dockerfile",
			Repo:           "vfox-flutter-e2e",
			Tag:            image[strings.LastIndex(image, ":")+1:],
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
// from killed runs (the old bash runner used anonymous names).
func containerName(c combo) string {
	var b [4]byte
	if _, err := rand.Read(b[:]); err != nil {
		return fmt.Sprintf("vfox-flutter-e2e-%s-%d", c.slug(), time.Now().UnixNano())
	}
	return "vfox-flutter-e2e-" + c.slug() + "-" + hex.EncodeToString(b[:])
}

// runOne starts one long-lived container per combo and drives the whole
// E2E flow (setup -> install -> verify) through exec calls, asserting in Go.
// A combo passes when every phase exits 0 and the outputs carry the expected
// markers (same bar as the old run.sh and the Windows matrix).
func runOne(t *testing.T, ctx context.Context, image, platform string, c combo) {
	t.Helper()
	prefix := c.prefix(platform)

	env := map[string]string{
		"VFOX_VERSION": c.vfox,
		"FLAVOR":       c.flavor,
	}
	if c.mirror != "default" {
		env["FLUTTER_STORAGE_BASE_URL"] = c.mirror
	}
	for _, name := range passThroughEnvs {
		if v, ok := os.LookupEnv(name); ok && v != "" {
			env[name] = v
		}
	}

	ctr, err := tc.GenericContainer(ctx, tc.GenericContainerRequest{
		ContainerRequest: tc.ContainerRequest{
			Image:         image,
			ImagePlatform: platform,
			Name:          containerName(c),
			Env:           env,
		},
		Started: true,
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
	machine := strings.TrimSpace(execOK(ctx, t, ctr, "uname --machine"))
	t.Logf("=== vfox %s, flutter %s, %s, mirror %s, %s ===", c.vfox, version, flavor, mirror, machine)

	checkMirrorReachable(ctx, t, ctr, flavor, mirror)
	setupVfox(ctx, t, ctr, c.vfox)
	checkBogusMirrorRejected(ctx, t, ctr, flavor, version)
	checkBogusGithubMirrorRejected(ctx, t, ctr, flavor, version)

	installFlutterVersion(ctx, t, ctr, version)

	sdk := sdkDir(ctx, t, ctr)
	verifySdkLayout(ctx, t, ctr, flavor, sdk)
	verifyManifestDrift(ctx, t, ctr, version, sdk)
	verifyToolchain(ctx, t, ctr, sdk)
}
