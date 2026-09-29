#!/usr/bin/env bash
# Install vfox and register the local flutter plugin.
# Sourced by run.sh (`setup_vfox`), or executed directly for debugging:
#   bash tests/e2e/linux/setup.sh
set -o errexit -o nounset -o pipefail

if [[ -n "${VFOX_E2E_SETUP_SH:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
VFOX_E2E_SETUP_SH=1

install_vfox_release() {
    curl --fail --silent --show-error --location https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash
}

install_vfox_main() {
    local work="$1"
    git clone --depth 1 https://github.com/version-fox/vfox "$work/src"
    (cd "$work/src" && CGO_ENABLED=0 go build -trimpath -o /usr/local/bin/vfox .)
}

add_flutter_plugin() {
    local repo_root="$1"
    local work="$2"
    (cd "$repo_root" && zip -qr "$work/flutter.zip" metadata.lua hooks lib)
    vfox add flutter --source "$work/flutter.zip"
}

setup_vfox() {
    local vfox_version="${VFOX_VERSION:-latest}"
    local here repo_root work
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    repo_root="$(cd "$here/../../.." && pwd)"
    work="$(mktemp --directory)"
    # The container is ephemeral (--rm), but still clean up after ourselves
    # so repeated local runs don't leak /tmp. Expanded now: the trap must
    # not reference the function-local $work after it goes out of scope.
    # SC2064 is a false positive here: expanding now is required, because
    # the function-local $work is already out of scope when the EXIT trap
    # fires. Single quotes would defer expansion and hand rm an empty path.
    # shellcheck disable=SC2064
    trap "rm --recursive --force '${work}'" EXIT

    if [[ "$vfox_version" == "main" ]]; then
        install_vfox_main "$work"
    else
        install_vfox_release
    fi
    add_flutter_plugin "$repo_root" "$work"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_vfox "$@"
fi
