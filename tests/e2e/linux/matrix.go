// Package e2e is the Linux container E2E suite, driven entirely from Go via
// testcontainers-go.
//
// TestE2E builds the image in tests/e2e/linux/Dockerfile once, then runs one
// long-lived container per (vfox version x flavor x mirror) combination and
// drives setup -> install -> verify through exec calls (setup.go, install.go,
// verify.go), asserting in Go. matrix.go holds the matrix expansion.
package e2e

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"
)

// defaultMirrorCN is the default mainland-China Flutter storage mirror.
const defaultMirrorCN = "https://storage.flutter-io.cn"

// combo is one matrix cell: a vfox version, a flutter flavor and a mirror.
type combo struct {
	vfox   string
	flavor string
	mirror string
}

// prefix renders the log prefix shared with the old e2e.sh and e2e.ps1:
// "vfox <vfox>, <flavor>, mirror <mirror>, <platform>".
func (c combo) prefix(platform string) string {
	return fmt.Sprintf("vfox %s, %s, mirror %s, %s", c.vfox, c.flavor, c.mirror, platform)
}

// slug renders a docker-safe container name fragment for the combo.
func (c combo) slug() string {
	return c.vfox + "-" + c.flavor + "-" + sanitize(c.mirror)
}

// sanitize replaces every non-ASCII-alphanumeric byte with '_' so arbitrary
// mirror URLs stay valid in container names (mirrors e2e.ps1).
func sanitize(s string) string {
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

// normalizeArch maps uname-style names and ARCH aliases to docker arches.
func normalizeArch(s string) (string, error) {
	switch strings.ToLower(s) {
	case "x86_64", "x64", "amd64":
		return "amd64", nil
	case "aarch64", "arm64":
		return "arm64", nil
	default:
		return "", fmt.Errorf("unknown architecture %s", s)
	}
}

// detectArch honours $ARCH and falls back to the test binary's own arch.
func detectArch() (string, error) {
	if arch, ok := os.LookupEnv("ARCH"); ok && strings.TrimSpace(arch) != "" {
		return normalizeArch(strings.TrimSpace(arch))
	}
	return normalizeArch(runtime.GOARCH)
}

// fields splits space-separated env lists (e.g. FLAVOR="official ohos").
// strings.Fields matches bash `read -ra` on the default IFS.
func fields(s string) []string {
	return strings.Fields(s)
}

// defaultFlavours mirrors the old config.sh rule: ohos publishes no
// linux-arm64 artefacts, so arm64 runs official only (same as Windows).
func defaultFlavours(arch string) []string {
	if arch == "arm64" {
		return []string{"official"}
	}
	return []string{"official", "ohos"}
}

// defaultMirrors mirrors the old config.sh rule: the extra mirror only runs
// on amd64, where the full matrix is affordable.
func defaultMirrors(arch string) []string {
	if arch == "arm64" {
		return []string{"default"}
	}
	return []string{"default", defaultMirrorCN}
}

// matrix expands the vfox x flavor x mirror combinations. Env overrides:
// VFOX_VERSION (default "latest main"), FLAVOR, MIRROR, ARCH. The mirror
// matrix only runs against latest vfox unless the caller explicitly pins
// MIRROR, to keep CI time bounded (same rule as e2e.sh / e2e.ps1).
func matrix() ([]combo, error) {
	arch, err := detectArch()
	if err != nil {
		return nil, err
	}

	foxes := []string{"latest", "main"}
	if v, ok := os.LookupEnv("VFOX_VERSION"); ok && len(fields(v)) > 0 {
		foxes = fields(v)
	}
	flavours := defaultFlavours(arch)
	if v, ok := os.LookupEnv("FLAVOR"); ok && len(fields(v)) > 0 {
		flavours = fields(v)
	}
	mirrors := defaultMirrors(arch)
	if v, ok := os.LookupEnv("MIRROR"); ok && len(fields(v)) > 0 {
		mirrors = fields(v)
	}
	_, mirrorExplicit := os.LookupEnv("MIRROR")
	mirrorExplicit = mirrorExplicit && len(fields(os.Getenv("MIRROR"))) > 0

	var combos []combo
	for _, vfox := range foxes {
		for _, flavor := range flavours {
			for _, mirror := range mirrors {
				if !mirrorExplicit && mirror != "default" && vfox != "latest" {
					continue
				}
				combos = append(combos, combo{vfox: vfox, flavor: flavor, mirror: mirror})
			}
		}
	}
	return combos, nil
}

// maxJobs bounds parallel containers; honours $E2E_MAX_JOBS (default 3).
func maxJobs() int {
	if v, ok := os.LookupEnv("E2E_MAX_JOBS"); ok {
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil && n >= 1 {
			return n
		}
	}
	return 3
}
