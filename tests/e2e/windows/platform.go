package windows

import (
	"github.com/version-fox/vfox-flutter/tests/e2e/common"
)

// maxJobs bounds parallel containers; honours $E2E_MAX_JOBS (default 2,
// matching the old e2e.ps1).
func maxJobs() int {
	return common.MaxJobs(2)
}
