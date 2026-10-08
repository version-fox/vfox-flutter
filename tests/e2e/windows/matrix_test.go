package windows

import (
	"testing"
)

func TestMaxJobsDefault(t *testing.T) {
	t.Setenv("E2E_MAX_JOBS", "")
	// empty means unset-equivalent for maxJobs (Atoi fails -> default 2)
	if got := maxJobs(); got != 2 {
		t.Errorf("maxJobs = %d, want 2", got)
	}
	t.Setenv("E2E_MAX_JOBS", "0")
	if got := maxJobs(); got != 2 {
		t.Errorf("maxJobs(0) = %d, want 2 (clamped to default)", got)
	}
}

func TestReleasesIndex(t *testing.T) {
	got := releasesIndex("https://storage.flutter-io.cn/")
	want := "https://storage.flutter-io.cn/flutter_infra_release/releases/releases_windows.json"
	if got != want {
		t.Errorf("releasesIndex = %q, want %q", got, want)
	}
}

func TestPwshQuote(t *testing.T) {
	if got := pwshQuote(`C:\a\b`); got != `'C:\a\b'` {
		t.Errorf("pwshQuote = %q", got)
	}
	if got := pwshQuote(`it's`); got != `'it''s'` {
		t.Errorf("pwshQuote escape = %q", got)
	}
	if got := winDir(`C:\sdk\bin\flutter.exe`); got != `C:\sdk\bin` {
		t.Errorf("winDir = %q", got)
	}
	if got := winDir(winDir(`C:\sdk\bin\flutter.exe`)); got != `C:\sdk` {
		t.Errorf("winDir x2 = %q", got)
	}
}
