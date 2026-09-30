#!/usr/bin/env bash
# Install and activate one Flutter version: `bash install.sh <version>`.
# Runs standalone (called as a subprocess by run.sh, like install.ps1).
set -o errexit -o nounset -o pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"

install_flutter_version() {
    local version="$1"
    activate_vfox
    if ! retry "vfox install flutter@${version}" vfox install flutter@"$version"; then
        die "vfox install flutter@${version} failed after ${E2E_RETRY_ATTEMPTS:-3} attempts"
    fi
    vfox use --global flutter@"$version"
    activate_vfox
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    version="${1:?usage: install.sh <flutter-version>}"
    install_flutter_version "$version"
fi
