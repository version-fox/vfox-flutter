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
	"archive/zip"
	"bytes"
	"context"
	"debug/buildinfo"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

// vfoxMainArchive serves vfox main as a GitHub source archive, so building
// it needs no git (the compose runner image carries none).
const vfoxMainArchive = "https://github.com/version-fox/vfox/archive/refs/heads/main.zip"

// vfoxMainBuild is the one vfox.exe built from vfox main per run, shared by
// every main combo. It builds on the test's side while the image builds,
// instead of a Go MSI install, clone and build in every main container.
type vfoxMainBuild struct {
	done      chan struct{}
	exe       string
	goVersion string
	err       error
}

// startVfoxMainBuild fetches vfox main into dir and builds vfox.exe for
// windows/arch in the background, with the suite's own Go toolchain.
func startVfoxMainBuild(ctx context.Context, dir, arch string) *vfoxMainBuild {
	b := &vfoxMainBuild{done: make(chan struct{})}
	go func() {
		defer close(b.done)
		b.exe, b.goVersion, b.err = buildVfoxMain(ctx, dir, arch)
	}()
	return b
}

// wait blocks until the build is done and fatals the calling combo if it
// failed, so a broken vfox main fails the main combos only.
func (b *vfoxMainBuild) wait(t *testing.T) string {
	t.Helper()
	<-b.done
	if b.err != nil {
		t.Fatalf("build vfox from main: %v", b.err)
	}
	t.Logf("PASS built vfox from main with %s", b.goVersion)
	return b.exe
}

// buildVfoxMain returns the built vfox.exe and the Go version it was built
// with.
func buildVfoxMain(ctx context.Context, dir, arch string) (string, string, error) {
	src, err := fetchVfoxMain(ctx, dir)
	if err != nil {
		return "", "", err
	}
	exe := filepath.Join(dir, "vfox.exe")
	cmd := exec.CommandContext(ctx, "go", "build", "-trimpath", "-o", exe, ".")
	cmd.Dir = src
	// GOTOOLCHAIN=auto follows vfox's own go.mod should it ever need a newer
	// Go than the suite's (setup-go pins GOTOOLCHAIN=local in CI).
	cmd.Env = append(os.Environ(), "GOOS=windows", "GOARCH="+arch, "CGO_ENABLED=0", "GOTOOLCHAIN=auto")
	if out, err := cmd.CombinedOutput(); err != nil {
		return "", "", fmt.Errorf("go build: %w\n%s", err, out)
	}
	info, err := buildinfo.ReadFile(exe)
	if err != nil {
		return "", "", err
	}
	return exe, info.GoVersion, nil
}

// fetchVfoxMain extracts vfoxMainArchive under dir and returns the source
// root, the archive's single top-level vfox-main directory.
func fetchVfoxMain(ctx context.Context, dir string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, vfoxMainArchive, nil)
	if err != nil {
		return "", err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("GET %s: %s", vfoxMainArchive, resp.Status)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	zr, err := zip.NewReader(bytes.NewReader(body), int64(len(body)))
	if err != nil {
		return "", err
	}
	// The fs.FS view of the archive only yields names inside it.
	if err := os.CopyFS(dir, zr); err != nil {
		return "", err
	}
	return filepath.Join(dir, "vfox-main"), nil
}
