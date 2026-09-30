#!/usr/bin/env bash
# In-container E2E entrypoint (see Dockerfile CMD). Thin orchestrator only:
# resolve config -> probe mirror -> setup -> bogus-mirror guard ->
# install -> verify. Stage logic lives in setup.sh / install.sh / verify.sh.
set -o errexit -o nounset -o pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"
# shellcheck source=config.sh
source "$here/config.sh"
# shellcheck source=setup.sh
source "$here/setup.sh"

# Official flavours download from $FLUTTER_STORAGE_BASE_URL when set; fail
# fast with a clear message if the mirror does not serve the release index.
check_mirror_reachable() {
    local flavor="$1"
    local mirror="$2"
    if [[ "$flavor" != "official" || "$mirror" == "default" ]]; then
        return 0
    fi
    local index
    index="$(releases_index_for_mirror "$mirror" linux)"
    if retry "mirror $index" curl --fail --silent --show-error --location --max-time 20 --output /dev/null "$index" >/dev/null; then
        pass "mirror $mirror serves the releases index"
    else
        die "mirror $mirror is unreachable ($index)"
    fi
}

# A bogus mirror must fail with an error naming the host, proving the
# plugin really honours $FLUTTER_STORAGE_BASE_URL instead of falling back.
check_bogus_mirror_rejected() {
    local flavor="$1"
    local version="$2"
    if [[ "$flavor" != "official" ]]; then
        return 0
    fi
    local bogus_mirror="https://invalid.example.invalid"
    local bogus_output bogus_code=0
    bogus_output="$(FLUTTER_STORAGE_BASE_URL="$bogus_mirror" vfox install flutter@"$version" 2>&1)" || bogus_code=$?
    ((bogus_code != 0)) || die "bogus mirror install unexpectedly succeeded"
    assert_contains "$bogus_output" "invalid.example.invalid" 'bogus mirror error'
}

# On ARM64 the official flavour installs from git source; a bogus
# $VFOX_FLUTTER_GITHUB_MIRROR must fail naming the host, proving the plugin
# honours it instead of falling back to https://github.com.
check_bogus_github_mirror_rejected() {
    local flavor="$1"
    local version="$2"
    if [[ "$flavor" != "official" || "$(uname --machine)" != "aarch64" ]]; then
        return 0
    fi
    local bogus_mirror="https://invalid.example.invalid"
    local bogus_output bogus_code=0
    bogus_output="$(VFOX_FLUTTER_GITHUB_MIRROR="$bogus_mirror" vfox install flutter@"$version" 2>&1)" || bogus_code=$?
    ((bogus_code != 0)) || die "bogus GitHub mirror install unexpectedly succeeded"
    assert_contains "$bogus_output" "invalid.example.invalid" 'bogus GitHub mirror error'
}

main() {
    local flavor mirror version
    flavor="$(require_env FLAVOR)"
    mirror="${FLUTTER_STORAGE_BASE_URL:-default}"
    version="$(resolve_flutter_version "$flavor")"

    echo "=== vfox ${VFOX_VERSION:-latest}, flutter $version, $flavor, mirror $mirror, $(uname --machine) ==="

    check_mirror_reachable "$flavor" "$mirror"
    setup_vfox
    check_bogus_mirror_rejected "$flavor" "$version"
    check_bogus_github_mirror_rejected "$flavor" "$version"

    bash "$here/install.sh" "$version"
    activate_vfox
    bash "$here/verify.sh" "$flavor" "$version"
}

main "$@"
