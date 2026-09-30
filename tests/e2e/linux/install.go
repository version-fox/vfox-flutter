package e2e

import (
	"context"
	"fmt"
	"testing"

	tc "github.com/testcontainers/testcontainers-go"
)

// installFlutterVersion installs one Flutter version and selects it globally
// (was install.sh).
func installFlutterVersion(ctx context.Context, t *testing.T, ctr tc.Container, version string) {
	t.Helper()
	execRetry(ctx, t, ctr, fmt.Sprintf("vfox install flutter@%s", version),
		activated(fmt.Sprintf("vfox install flutter@%s", version)))
	execOK(ctx, t, ctr, activated(fmt.Sprintf("vfox use --global flutter@%s", version)))
}
