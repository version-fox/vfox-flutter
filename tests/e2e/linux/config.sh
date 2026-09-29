#!/usr/bin/env bash
# Single source of truth for matrix defaults. Sourced, not executed:
#   source "$here/config.sh"
#
# NOTE: tests/e2e/windows/lib.ps1 duplicates DEFAULT_OFFICIAL_VERSION and
# DEFAULT_OHOS_VERSION (bash and PowerShell share no config format).
# Bump both sides together.

if [[ -n "${VFOX_E2E_CONFIG_SH:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
VFOX_E2E_CONFIG_SH=1

DEFAULT_OFFICIAL_VERSION="3.47.4"
DEFAULT_OHOS_VERSION="3.41.10-ohos-1.0.0"
DEFAULT_MIRROR_CN="https://storage.flutter-io.cn"

# resolve_flutter_version <official|ohos> honours $FLUTTER_VERSION / $OHOS_VERSION.
resolve_flutter_version() {
    local flavor="$1"
    local version=""
    case "$flavor" in
        official) version="${FLUTTER_VERSION:-$DEFAULT_OFFICIAL_VERSION}" ;;
        ohos) version="${OHOS_VERSION:-$DEFAULT_OHOS_VERSION}" ;;
        *)
            echo "FAIL unknown flavor $flavor" >&2
            return 1
            ;;
    esac
    printf '%s' "$version"
}

# default_flavours <amd64|arm64>: ohos has no arm64 artefacts, so arm64 runs
# official only (same rule as the Windows matrix).
default_flavours() {
    if [[ "$1" == "arm64" ]]; then
        echo "official"
    else
        echo "official ohos"
    fi
}

default_mirrors() {
    if [[ "$1" == "arm64" ]]; then
        echo "default"
    else
        echo "default $DEFAULT_MIRROR_CN"
    fi
}

# releases_index_for_mirror <mirror> <linux|windows>
releases_index_for_mirror() {
    printf '%s/flutter_infra_release/releases/releases_%s.json' "${1%/}" "$2"
}
