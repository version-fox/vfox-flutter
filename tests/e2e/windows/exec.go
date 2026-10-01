package e2e

import (
	"context"
	"io"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	tc "github.com/testcontainers/testcontainers-go"
	tcexec "github.com/testcontainers/testcontainers-go/exec"
)

// retryAttempts caps exec retries; honours $E2E_RETRY_ATTEMPTS (default 3,
// matching Invoke-WithRetry). Kept on the standard library: the established
// retry libraries (cenkalti/backoff, avast/retry-go) have no release in the
// last 6 months, so no third-party candidate qualifies.
func retryAttempts() int {
	if v, ok := os.LookupEnv("E2E_RETRY_ATTEMPTS"); ok && strings.TrimSpace(v) != "" {
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
			return n
		}
	}
	return 3
}

// pwshPrelude mirrors the run.ps1/lib.ps1 headers: any cmdlet error aborts
// and native failures propagate. Without it, pwsh exits 0 despite script
// errors (non-terminating by default) and execOK would pass silently.
const pwshPrelude = "$ErrorActionPreference = 'Stop'; $PSNativeCommandUseErrorActionPreference = $true;"

// execRun runs script via `pwsh -NoProfile -Command` in the container and
// returns its exit code with the combined stdout+stderr output. extraEnv
// entries ("K=V") override single variables; the rest of the container env
// is inherited.
func execRun(ctx context.Context, t *testing.T, ctr tc.Container, script string, extraEnv ...string) (int, string) {
	t.Helper()
	opts := []tcexec.ProcessOption{tcexec.Multiplexed()}
	if len(extraEnv) > 0 {
		opts = append(opts, tcexec.WithEnv(extraEnv))
	}
	code, r, err := ctr.Exec(ctx, []string{"pwsh", "-NoProfile", "-Command", pwshPrelude + " " + script}, opts...)
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

// execRetry mirrors Invoke-WithRetry: run script up to retryAttempts() times
// with linear backoff (10s * attempt), logging each failed attempt.
func execRetry(ctx context.Context, t *testing.T, ctr tc.Container, label, script string, extraEnv ...string) string {
	t.Helper()
	max := retryAttempts()
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
