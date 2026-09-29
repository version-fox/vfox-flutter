#!/usr/bin/env bash
# Host-side matrix runner: build the image once, then fan out one container
# per (vfox version x flavor x mirror) combination, at most $max_jobs at a
# time. Logs are prefixed so parallel runs stay readable.
set -o errexit -o nounset -o pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"
# shellcheck source=config.sh
source "$here/config.sh"

run_one() {
    local image="$1"
    local platform="$2"
    local vfox="$3"
    local flavor="$4"
    local mirror="$5"
    local prefix="vfox $vfox, $flavor, mirror $mirror, $platform"
    local env=(--env "VFOX_VERSION=$vfox" --env "FLAVOR=$flavor")
    if [[ "$mirror" != "default" ]]; then
        env+=(--env "FLUTTER_STORAGE_BASE_URL=$mirror")
    fi
    docker run --rm --platform "$platform" "${env[@]}" "$image" 2>&1 | sed --expression "s|^|[$prefix] |"
}

main() {
    local repo arch platform image
    repo="$(cd "$here/../../.." && pwd)"
    arch="$(normalize_arch "${ARCH:-$(uname --machine)}")"
    platform="linux/$arch"
    image="vfox-flutter-e2e:linux-$arch"

    docker build --pull --platform "$platform" --file "$here/Dockerfile" --tag "$image" "$repo"

    # Space-separated env lists (e.g. FLAVOR="official ohos") are split
    # into arrays up front, so the loops below need no word splitting.
    # (read is a bash builtin with no long-option form for -r/-a.)
    local -a foxes flavours mirrors
    read -ra foxes <<< "${VFOX_VERSION:-latest main}"
    read -ra flavours <<< "${FLAVOR:-$(default_flavours "$arch")}"
    read -ra mirrors <<< "${MIRROR:-$(default_mirrors "$arch")}"
    local mirror_explicit="${MIRROR:-}"
    local max_jobs="${E2E_MAX_JOBS:-3}"
    local failed=0

    for vfox in "${foxes[@]}"; do
        for flavor in "${flavours[@]}"; do
            for mirror in "${mirrors[@]}"; do
                # The mirror matrix only runs against latest vfox unless the
                # caller explicitly pins MIRROR, to keep CI time bounded.
                if [[ -z "$mirror_explicit" && "$mirror" != "default" && "$vfox" != "latest" ]]; then
                    continue
                fi
                run_one "$image" "$platform" "$vfox" "$flavor" "$mirror" &
                while [[ "$(jobs -p | wc --lines)" -ge "$max_jobs" ]]; do
                    wait -n || failed=1
                done
            done
        done
    done

    while [[ "$(jobs -p | wc --lines)" -gt 0 ]]; do
        wait -n || failed=1
    done

    return "$failed"
}

main "$@"
