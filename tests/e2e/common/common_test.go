package common

import (
	"testing"
)

func setEnv(t *testing.T, kv map[string]string) {
	t.Helper()
	for k, v := range kv {
		t.Setenv(k, v)
	}
}

func comboKeys(combos []Combo) []string {
	keys := make([]string, 0, len(combos))
	for _, c := range combos {
		keys = append(keys, c.Vfox+"/"+c.Flavor+"/"+c.Mirror)
	}
	return keys
}

// Default amd64 matrix: latest runs both mirrors, main runs default only.
func TestMatrixDefaultAmd64(t *testing.T) {
	t.Setenv("VFOX_VERSION", "")
	t.Setenv("FLAVOR", "")
	t.Setenv("MIRROR", "")

	// t.Setenv sets the var to "" which LookupEnv reports as set; the empty
	// values above exercise the real defaults via Fields dropping empties.
	combos, err := MatrixForArch("amd64")
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) == 0 {
		t.Fatal("empty matrix")
	}
	t.Logf("combos: %v", comboKeys(combos))
	for _, c := range combos {
		if c.Mirror != "default" && c.Vfox != "latest" {
			t.Errorf("non-default mirror runs against %s vfox: %+v", c.Vfox, c)
		}
	}
}

// arm64 defaults: official flavor, default mirror only.
func TestMatrixDefaultArm64(t *testing.T) {
	setEnv(t, map[string]string{
		"VFOX_VERSION": "latest main",
		"FLAVOR":       "",
		"MIRROR":       "",
	})

	combos, err := MatrixForArch("arm64")
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range combos {
		if c.Flavor != "official" {
			t.Errorf("arm64 flavor = %s, want official", c.Flavor)
		}
		if c.Mirror != "default" {
			t.Errorf("arm64 mirror = %s, want default", c.Mirror)
		}
	}
	if len(combos) == 0 {
		t.Fatal("empty matrix")
	}
}

// Explicit MIRROR pins the full mirror matrix even for non-latest vfox.
func TestMatrixExplicitMirror(t *testing.T) {
	setEnv(t, map[string]string{
		"VFOX_VERSION": "main",
		"FLAVOR":       "official",
		"MIRROR":       "default https://storage.flutter-io.cn",
	})

	combos, err := MatrixForArch("amd64")
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) != 2 {
		t.Fatalf("combos = %v, want 2", comboKeys(combos))
	}
}

// PROCESSOR_ARCHITECTURE values from real Windows hosts resolve correctly.
func TestMatrixProcessorArchitecture(t *testing.T) {
	t.Setenv("PROCESSOR_ARCHITECTURE", "ARM64")
	t.Setenv("VFOX_VERSION", "latest")
	t.Setenv("FLAVOR", "official")
	t.Setenv("MIRROR", "default")
	combos, err := Matrix()
	if err != nil {
		t.Fatal(err)
	}
	if len(combos) != 1 {
		t.Fatalf("combos = %v, want 1", comboKeys(combos))
	}
}

// Unknown architectures fail fast instead of running a wrong matrix.
func TestMatrixUnknownArch(t *testing.T) {
	t.Setenv("PROCESSOR_ARCHITECTURE", "bogus64")
	if _, err := Matrix(); err == nil {
		t.Error("Matrix() with bogus PROCESSOR_ARCHITECTURE succeeded, want error")
	}
}

func TestNormalizeArch(t *testing.T) {
	for in, want := range map[string]string{
		"AMD64": "amd64", "x86_64": "amd64", "x64": "amd64", "amd64": "amd64",
		"ARM64": "arm64", "aarch64": "arm64", "arm64": "arm64",
	} {
		got, err := NormalizeArch(in)
		if err != nil || got != want {
			t.Errorf("NormalizeArch(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	for _, bad := range []string{"riscv64", "x86"} {
		if _, err := NormalizeArch(bad); err == nil {
			t.Errorf("NormalizeArch(%q) succeeded, want error", bad)
		}
	}
}

func TestSanitize(t *testing.T) {
	got := Combo{Vfox: "latest", Flavor: "official", Mirror: "https://storage.flutter-io.cn"}.Slug()
	want := "latest-official-https___storage_flutter_io_cn"
	if got != want {
		t.Errorf("slug = %q, want %q", got, want)
	}
}

func TestMaxJobs(t *testing.T) {
	t.Setenv("E2E_MAX_JOBS", "")
	// empty means unset-equivalent for MaxJobs (Atoi fails -> default)
	if got := MaxJobs(3); got != 3 {
		t.Errorf("MaxJobs = %d, want 3", got)
	}
	t.Setenv("E2E_MAX_JOBS", "0")
	if got := MaxJobs(3); got != 3 {
		t.Errorf("MaxJobs(0) = %d, want 3 (clamped to default)", got)
	}
	t.Setenv("E2E_MAX_JOBS", "2")
	if got := MaxJobs(3); got != 2 {
		t.Errorf("MaxJobs(2) = %d, want 2", got)
	}
}

func TestResolveFlutterVersion(t *testing.T) {
	t.Setenv("FLUTTER_VERSION", "")
	t.Setenv("OHOS_VERSION", "")
	if got := ResolveFlutterVersion(t, "official"); got != "3.47.4" {
		t.Errorf("official default = %q", got)
	}
	if got := ResolveFlutterVersion(t, "ohos"); got != "3.41.10-ohos-1.0.0" {
		t.Errorf("ohos default = %q", got)
	}
	t.Setenv("FLUTTER_VERSION", "3.99.0")
	if got := ResolveFlutterVersion(t, "official"); got != "3.99.0" {
		t.Errorf("official override = %q", got)
	}
}

func TestToolsDart(t *testing.T) {
	out := "Flutter 3.47.4 • channel stable • https://github.com/flutter/flutter.git\n" +
		"Framework • revision abc123 (4 weeks ago) • 2026-01-01\n" +
		"Engine • revision def456\n" +
		"Tools • Dart 3.10.0 • DevTools 2.48.0\n"
	if got := ToolsDart(out); got != "3.10.0" {
		t.Errorf("toolsDart = %q, want 3.10.0", got)
	}
	if got := ToolsDart("no tools here\n"); got != "" {
		t.Errorf("toolsDart without Tools line = %q, want empty", got)
	}
}

func TestRetryAttemptsDefault(t *testing.T) {
	t.Setenv("E2E_RETRY_ATTEMPTS", "")
	if got := RetryAttempts(); got != 3 {
		t.Errorf("retryAttempts = %d, want 3", got)
	}
	t.Setenv("E2E_RETRY_ATTEMPTS", "5")
	if got := RetryAttempts(); got != 5 {
		t.Errorf("retryAttempts = %d, want 5", got)
	}
}
