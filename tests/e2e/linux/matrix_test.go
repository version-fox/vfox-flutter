package linux

import (
	"testing"
)

func TestMaxJobsDefault(t *testing.T) {
	t.Setenv("E2E_MAX_JOBS", "")
	// empty means unset-equivalent for maxJobs (Atoi fails -> default 3)
	if got := maxJobs(); got != 3 {
		t.Errorf("maxJobs = %d, want 3", got)
	}
	t.Setenv("E2E_MAX_JOBS", "0")
	if got := maxJobs(); got != 3 {
		t.Errorf("maxJobs(0) = %d, want 3 (clamped to default)", got)
	}
}

func TestReleasesIndex(t *testing.T) {
	got := releasesIndex("https://storage.flutter-io.cn/")
	want := "https://storage.flutter-io.cn/flutter_infra_release/releases/releases_linux.json"
	if got != want {
		t.Errorf("releasesIndex = %q, want %q", got, want)
	}
}
