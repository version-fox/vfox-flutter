package linux

import (
	"context"
	"io"
	"testing"
	"time"

	tc "github.com/testcontainers/testcontainers-go"
	tcexec "github.com/testcontainers/testcontainers-go/exec"

	"github.com/version-fox/vfox-flutter/tests/e2e/common"
)

// execRun runs script via `bash -c` in the container and returns its exit
// code with the combined stdout+stderr output. extraEnv entries ("K=V")
// override single variables; the rest of the container env is inherited.
func execRun(ctx context.Context, t *testing.T, ctr tc.Container, script string, extraEnv ...string) (int, string) {
	t.Helper()
	opts := []tcexec.ProcessOption{tcexec.Multiplexed()}
	if len(extraEnv) > 0 {
		opts = append(opts, tcexec.WithEnv(extraEnv))
	}
	code, r, err := ctr.Exec(ctx, []string{"bash", "-c", script}, opts...)
	if err != nil {
		t.Fatalf("exec: %v\n--- script ---\n%s", err, script)
	}
	out, err := io.ReadAll(r)
	if err != nil {
		t.Fatalf("exec read output: %v\n--- script ---\n%s", err, script)
	}
	return code, string(out)
}

// execOK runs script and fatals unless it exits 0, returning the output.
func execOK(ctx context.Context, t *testing.T, ctr tc.Container, script string, extraEnv ...string) string {
	t.Helper()
	code, out := execRun(ctx, t, ctr, script, extraEnv...)
	if code != 0 {
		t.Fatalf("exec exited with code %d\n--- script ---\n%s\n--- output ---\n%s", code, script, out)
	}
	return out
}

// execRetry keeps the old lib.sh retry semantics (linear 10s*attempt backoff,
// per-attempt logging) with the standard library only: the established retry
// libraries (cenkalti/backoff, avast/retry-go) have no release in the last
// 6 months, so no third-party candidate qualifies.
func execRetry(ctx context.Context, t *testing.T, ctr tc.Container, label, script string, extraEnv ...string) string {
	t.Helper()
	max := common.RetryAttempts()
	var out string
	for attempt := 1; ; attempt++ {
		code, o := execRun(ctx, t, ctr, script, extraEnv...)
		out = o
		if code == 0 {
			return out
		}
		if attempt >= max {
			t.Fatalf("%s failed after %d attempt(s) (exit %d)\n--- output ---\n%s", label, attempt, code, out)
		}
		t.Logf("retrying %s, attempt %d exited %d", label, attempt, code)
		t.Logf("--- output ---\n%s", out)
		select {
		case <-ctx.Done():
			t.Fatalf("%s: %v", label, ctx.Err())
		case <-time.After(time.Duration(10*attempt) * time.Second):
		}
	}
}

// activated prefixes script with the vfox env setup, the equivalent of the
// old lib.sh activate_vfox (`eval "$(vfox activate bash)"`). Every exec
// starts a fresh shell, so activation cannot persist and must wrap each call.
func activated(script string) string {
	return `eval "$(vfox activate bash)"; ` + script
}
