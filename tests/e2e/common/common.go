// Package common holds the shared logic of the Linux and Windows container
// E2E suites.
//
// The two suites target different container systems (bash vs pwsh, different
// release probing and isolation), so the code interacting with containers
// stays in the linux / windows packages; the target-independent parts
// (matrix expansion, version defaults, retry counts, name handling) live
// here and are reused by both platform packages, instead of being copied.
package common

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"
	"testing"
	"time"
)

// Flutter defaults, maintained in one place for both packages.
const (
	DefaultOfficialVersion = "3.47.4"
	DefaultOhosVersion     = "3.41.10-ohos-1.0.0"
	// BogusMirror is the unreachable mirror domain used by the negative probes.
	BogusMirror = "https://invalid.example.invalid"
	// DefaultMirrorCN is the default mainland-China Flutter storage mirror.
	DefaultMirrorCN = "https://storage.flutter-io.cn"
)

// PassThroughEnvs are host env knobs the in-container scripts honour.
// Forwarded only when set, so unset stays default.
var PassThroughEnvs = []string{
	"FLUTTER_VERSION",
	"OHOS_VERSION",
	"VFOX_FLUTTER_GITHUB_MIRROR",
	"E2E_RETRY_ATTEMPTS",
}

// Combo is one matrix cell: a vfox version, a flutter flavor and a mirror.
type Combo struct {
	Vfox   string
	Flavor string
	Mirror string
}

// Prefix renders the log prefix:
// "vfox <vfox>, <flavor>, mirror <mirror>, <platform>".
func (c Combo) Prefix(platform string) string {
	return fmt.Sprintf("vfox %s, %s, mirror %s, %s", c.Vfox, c.Flavor, c.Mirror, platform)
}

// Slug renders a docker-safe container name fragment for the combo.
func (c Combo) Slug() string {
	return c.Vfox + "-" + c.Flavor + "-" + Sanitize(c.Mirror)
}

// Sanitize replaces every non-ASCII-alphanumeric byte with '_' so arbitrary
// mirror URLs stay valid in container names.
func Sanitize(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	for i := 0; i < len(s); i++ {
		ch := s[i]
		if ch >= 'A' && ch <= 'Z' || ch >= 'a' && ch <= 'z' || ch >= '0' && ch <= '9' {
			b.WriteByte(ch)
		} else {
			b.WriteByte('_')
		}
	}
	return b.String()
}

// NormalizeArch maps uname-style names, Windows PROCESSOR_ARCHITECTURE values
// and common aliases to docker arch names.
func NormalizeArch(s string) (string, error) {
	switch strings.ToLower(s) {
	case "x86_64", "x64", "amd64":
		return "amd64", nil
	case "aarch64", "arm64":
		return "arm64", nil
	default:
		return "", fmt.Errorf("unknown architecture %s", s)
	}
}

// DetectArch reports the runner architecture: $PROCESSOR_ARCHITECTURE on
// Windows hosts (AMD64/ARM64/x86), else the test binary's own arch. There is
// deliberately no override knob: emulated runs (arm64 on an x64 host) are
// not supported, and CI covers each arch on native runners.
func DetectArch() (string, error) {
	if arch, ok := os.LookupEnv("PROCESSOR_ARCHITECTURE"); ok && strings.TrimSpace(arch) != "" {
		return NormalizeArch(strings.TrimSpace(arch))
	}
	return NormalizeArch(runtime.GOARCH)
}

// Fields splits space-separated env lists (e.g. FLAVOR="official ohos").
func Fields(s string) []string {
	return strings.Fields(s)
}

// DefaultFlavours mirrors the old rule: ohos publishes no linux-arm64 /
// windows-arm64 artefacts, so arm64 runs official only.
func DefaultFlavours(arch string) []string {
	if arch == "arm64" {
		return []string{"official"}
	}
	return []string{"official", "ohos"}
}

// DefaultMirrors mirrors the old rule: the extra mirror only runs on amd64,
// where the full matrix is affordable.
func DefaultMirrors(arch string) []string {
	if arch == "arm64" {
		return []string{"default"}
	}
	return []string{"default", DefaultMirrorCN}
}

// Matrix expands the vfox x flavor x mirror combinations for the runner
// architecture. Env overrides: VFOX_VERSION (default "latest main"), FLAVOR,
// MIRROR. The mirror matrix only runs against latest vfox unless the caller
// explicitly pins MIRROR, to keep CI time bounded (same rule as the old
// e2e.sh / e2e.ps1).
func Matrix() ([]Combo, error) {
	arch, err := DetectArch()
	if err != nil {
		return nil, err
	}
	return MatrixForArch(arch)
}

// MatrixForArch expands the matrix for an explicit arch. Tests use it
// directly so each arch branch stays covered on any host.
func MatrixForArch(arch string) ([]Combo, error) {

	foxes := []string{"latest", "main"}
	if v, ok := os.LookupEnv("VFOX_VERSION"); ok && len(Fields(v)) > 0 {
		foxes = Fields(v)
	}
	flavours := DefaultFlavours(arch)
	if v, ok := os.LookupEnv("FLAVOR"); ok && len(Fields(v)) > 0 {
		flavours = Fields(v)
	}
	mirrors := DefaultMirrors(arch)
	if v, ok := os.LookupEnv("MIRROR"); ok && len(Fields(v)) > 0 {
		mirrors = Fields(v)
	}
	_, mirrorExplicit := os.LookupEnv("MIRROR")
	mirrorExplicit = mirrorExplicit && len(Fields(os.Getenv("MIRROR"))) > 0

	var combos []Combo
	for _, vfox := range foxes {
		for _, flavor := range flavours {
			for _, mirror := range mirrors {
				if !mirrorExplicit && mirror != "default" && vfox != "latest" {
					continue
				}
				combos = append(combos, Combo{Vfox: vfox, Flavor: flavor, Mirror: mirror})
			}
		}
	}
	return combos, nil
}

// MaxJobs bounds parallel containers; honours $E2E_MAX_JOBS and falls back
// to def when unset or invalid. Linux passes 3, Windows passes 2 (matching
// the old e2e.ps1).
func MaxJobs(def int) int {
	if v, ok := os.LookupEnv("E2E_MAX_JOBS"); ok {
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil && n >= 1 {
			return n
		}
	}
	return def
}

// RetryAttempts caps exec retries; honours $E2E_RETRY_ATTEMPTS (default 3).
func RetryAttempts() int {
	if v, ok := os.LookupEnv("E2E_RETRY_ATTEMPTS"); ok && strings.TrimSpace(v) != "" {
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
			return n
		}
	}
	return 3
}

// ResolveFlutterVersion honours $FLUTTER_VERSION / $OHOS_VERSION, else the
// defaults above.
func ResolveFlutterVersion(t *testing.T, flavor string) string {
	t.Helper()
	switch flavor {
	case "official":
		if v := os.Getenv("FLUTTER_VERSION"); v != "" {
			return v
		}
		return DefaultOfficialVersion
	case "ohos":
		if v := os.Getenv("OHOS_VERSION"); v != "" {
			return v
		}
		return DefaultOhosVersion
	default:
		t.Fatalf("unknown flavor %s", flavor)
		return ""
	}
}

// ToolsDart extracts the Dart version from `flutter --version` output
// (was: awk '/Tools/ { print $4 }' and its pwsh equivalent; both agree).
func ToolsDart(flutterVersion string) string {
	for _, line := range strings.Split(flutterVersion, "\n") {
		if strings.Contains(line, "Tools") {
			if f := strings.Fields(line); len(f) >= 4 {
				return f[3]
			}
		}
	}
	return ""
}

// ContainerName returns a unique container name per run: the combo slug stays
// greppable in `docker ps`, the random suffix avoids clashes with leftovers
// from killed runs.
func ContainerName(slug string) string {
	var b [4]byte
	if _, err := rand.Read(b[:]); err != nil {
		return fmt.Sprintf("vfox-flutter-e2e-%s-%d", slug, time.Now().UnixNano())
	}
	return "vfox-flutter-e2e-" + slug + "-" + hex.EncodeToString(b[:])
}

// Manifest is the anchored-install record the plugin writes into the SDK.
type Manifest struct {
	ExpectedHead string `json:"expected_head"`
}
