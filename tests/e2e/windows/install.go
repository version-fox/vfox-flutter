package windows

import (
	"context"
	"fmt"
	"testing"

	tc "github.com/testcontainers/testcontainers-go"
)

// installFlutterVersion installs one Flutter version and selects it globally
// (was install.ps1). Needs no activation: like the old script it runs plain,
// vfox.exe resolving through the slot PATH override.
func installFlutterVersion(ctx context.Context, t *testing.T, ctr tc.Container, box slotBox, version string) {
	t.Helper()
	execRetry(ctx, t, ctr, fmt.Sprintf("vfox install flutter@%s", version),
		fmt.Sprintf("vfox install %s", pwshQuote("flutter@"+version)),
		box.vars...)
	execOK(ctx, t, ctr,
		fmt.Sprintf("vfox use --global %s", pwshQuote("flutter@"+version)),
		box.vars...)
}
