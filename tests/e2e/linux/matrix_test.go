package e2e

import (
	"testing"
)

func setEnv(t *testing.T, kv map[string]string) {
	t.Helper()
	for k, v := range kv {
		t.Setenv(k, v)
	}
}

func comboKeys(combos []combo) []string {
	keys := make([]string, 0, len(combos))
	for _, c := range combos {
		keys = append(keys, c.vfox+"/"+c.flavor+"/"+c.mirror)
	}
	return keys
}

// Default amd64 matrix: latest runs both mirrors, main runs default only.
func TestMatrixDefaultAmd64(t *testing.T) {
	setEnv(t, map[string]string{"ARCH": "amd64"})
	t.Setenv("VFOX_VERSION", "")
	t.Setenv("FLAVOR", "")
	t.Setenv("MIRROR", "")

	// t.Setenv sets the var to "" which LookupEnv reports as set; unset
	// MIRROR/VFOX_VERSION/FLAVOR explicitly to exercise real defaults.
	// (os.Unsetenv cannot be used with t.Setenv in the same test, so set
	// the zero-ish values above and rely on fields() dropping empties.)
	combos, err := matrix()
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) == 0 {
		t.Fatal("empty matrix")
	}
	t.Logf("combos: %v", comboKeys(combos))
	for _, c := range combos {
		if c.mirror != "default" && c.vfox != "latest" {
			t.Errorf("non-default mirror runs against %s vfox: %+v", c.vfox, c)
		}
	}
}

// arm64 defaults: official flavor, default mirror only.
func TestMatrixDefaultArm64(t *testing.T) {
	setEnv(t, map[string]string{
		"ARCH":         "arm64",
		"VFOX_VERSION": "latest main",
		"FLAVOR":       "",
		"MIRROR":       "",
	})

	combos, err := matrix()
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range combos {
		if c.flavor != "official" {
			t.Errorf("arm64 flavor = %s, want official", c.flavor)
		}
		if c.mirror != "default" {
			t.Errorf("arm64 mirror = %s, want default", c.mirror)
		}
	}
	if len(combos) == 0 {
		t.Fatal("empty matrix")
	}
}

// Explicit MIRROR pins the full mirror matrix even for non-latest vfox.
func TestMatrixExplicitMirror(t *testing.T) {
	setEnv(t, map[string]string{
		"ARCH":         "amd64",
		"VFOX_VERSION": "main",
		"FLAVOR":       "official",
		"MIRROR":       "default https://storage.flutter-io.cn",
	})

	combos, err := matrix()
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) != 2 {
		t.Fatalf("combos = %v, want 2", comboKeys(combos))
	}
}

func TestNormalizeArch(t *testing.T) {
	for in, want := range map[string]string{
		"x86_64": "amd64", "amd64": "amd64", "x64": "amd64",
		"aarch64": "arm64", "arm64": "arm64",
	} {
		got, err := normalizeArch(in)
		if err != nil || got != want {
			t.Errorf("normalizeArch(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	if _, err := normalizeArch("riscv64"); err == nil {
		t.Error("normalizeArch(riscv64) succeeded, want error")
	}
}

func TestSanitize(t *testing.T) {
	got := combo{vfox: "latest", flavor: "official", mirror: "https://storage.flutter-io.cn"}.slug()
	want := "latest-official-https___storage_flutter_io_cn"
	if got != want {
		t.Errorf("slug = %q, want %q", got, want)
	}
}

func TestMaxJobsDefault(t *testing.T) {
	t.Setenv("E2E_MAX_JOBS", "")
	// empty means unset-equivalent for maxJobs (Atoi fails -> default)
	if got := maxJobs(); got != 3 {
		t.Errorf("maxJobs = %d, want 3", got)
	}
	t.Setenv("E2E_MAX_JOBS", "0")
	if got := maxJobs(); got != 3 {
		t.Errorf("maxJobs(0) = %d, want 3 (clamped to default)", got)
	}
}

func TestResolveFlutterVersion(t *testing.T) {
	t.Setenv("FLUTTER_VERSION", "")
	t.Setenv("OHOS_VERSION", "")
	if got := resolveFlutterVersion(t, "official"); got != "3.47.4" {
		t.Errorf("official default = %q", got)
	}
	if got := resolveFlutterVersion(t, "ohos"); got != "3.41.10-ohos-1.0.0" {
		t.Errorf("ohos default = %q", got)
	}
	t.Setenv("FLUTTER_VERSION", "3.99.0")
	if got := resolveFlutterVersion(t, "official"); got != "3.99.0" {
		t.Errorf("official override = %q", got)
	}
}

func TestReleasesIndex(t *testing.T) {
	got := releasesIndex("https://storage.flutter-io.cn/")
	want := "https://storage.flutter-io.cn/flutter_infra_release/releases/releases_linux.json"
	if got != want {
		t.Errorf("releasesIndex = %q, want %q", got, want)
	}
}

func TestToolsDart(t *testing.T) {
	out := "Flutter 3.47.4 • channel stable • https://github.com/flutter/flutter.git\n" +
		"Framework • revision abc123 (4 weeks ago) • 2026-01-01\n" +
		"Engine • revision def456\n" +
		"Tools • Dart 3.10.0 • DevTools 2.48.0\n"
	if got := toolsDart(out); got != "3.10.0" {
		t.Errorf("toolsDart = %q, want 3.10.0", got)
	}
	if got := toolsDart("no tools here\n"); got != "" {
		t.Errorf("toolsDart without Tools line = %q, want empty", got)
	}
}

func TestRetryAttemptsDefault(t *testing.T) {
	t.Setenv("E2E_RETRY_ATTEMPTS", "")
	if got := retryAttempts(); got != 3 {
		t.Errorf("retryAttempts = %d, want 3", got)
	}
	t.Setenv("E2E_RETRY_ATTEMPTS", "5")
	if got := retryAttempts(); got != 5 {
		t.Errorf("retryAttempts = %d, want 5", got)
	}
}
