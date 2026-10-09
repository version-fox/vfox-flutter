// Package e2e is the single Go module root of the container E2E suites.
//
// This directory holds no test logic, only the module definition
// (go.mod/go.sum) and the orchestration files; the code is split by
// subpackage:
//
//   - common: target-independent shared logic (matrix expansion, version
//     defaults, retry counts, name handling);
//   - linux: the Linux container suite (bash-driven), run in CI and locally
//     via tests/e2e/linux/compose.yaml as `go test ./linux/`;
//   - windows: the Windows container suite (pwsh-driven), run via
//     tests/e2e/windows/compose.amd64.yaml (amd64) or
//     tests/e2e/windows/compose.arm64.yaml (arm64) as `go test ./windows/`.
//
// Pure unit tests without containers (matrix expansion and friends) run from
// the module root:
//
//	go test -short ./...
package e2e
