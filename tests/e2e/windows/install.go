// Copyright 2026 Han Li and contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
