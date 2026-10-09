package linux

import (
	"context"
	"io"
	"testing"

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

// execRetry runs script through the shared common.Retry helper (linear
// 10s*attempt backoff, per-attempt logging), preserving the old lib.sh
// retry semantics without duplicating the loop per platform.
func execRetry(ctx context.Context, t *testing.T, ctr tc.Container, label, script string, extraEnv ...string) string {
	t.Helper()
	return common.Retry(ctx, t, label, func() (int, string) {
		return execRun(ctx, t, ctr, script, extraEnv...)
	})
}

// activated prefixes script with the vfox env setup, the equivalent of the
// old lib.sh activate_vfox (`eval "$(vfox activate bash)"`). Every exec
// starts a fresh shell, so activation cannot persist and must wrap each call.
func activated(script string) string {
	return `eval "$(vfox activate bash)"; ` + script
}
