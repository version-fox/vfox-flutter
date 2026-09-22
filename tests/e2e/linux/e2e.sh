#!/usr/bin/env bash
set -euo pipefail

here="$(dirname "${BASH_SOURCE[0]}")"
repo="$(cd "$here/../../.." && pwd)"

host_arch="$(uname -m)"
case "$host_arch" in
    x86_64) host_arch="amd64" ;;
    aarch64|arm64) host_arch="arm64" ;;
esac
arch="${ARCH:-$host_arch}"
platform="linux/$arch"
image="vfox-flutter-e2e:linux-$arch"

docker build --pull --platform "$platform" -f "$here/Dockerfile" -t "$image" "$repo"

foxes="${VFOX_VERSION:-latest main}"
default_flavours="official ohos"
default_mirrors="default https://storage.flutter-io.cn"
if [ "$arch" = arm64 ]; then
    default_flavours="official"
    default_mirrors="default"
fi
flavours="${FLAVOR:-$default_flavours}"
mirrors="${MIRROR:-$default_mirrors}"
mirror_explicit="${MIRROR:-}"

max_jobs=3
failed=0

run_one() {
    local vfox="$1"
    local flavor="$2"
    local mirror="$3"
    local prefix="vfox $vfox, $flavor, mirror $mirror, $platform"
    local env=("-e" "VFOX_VERSION=$vfox" "-e" "FLAVOR=$flavor" "-e" "GITHUB_TOKEN=${GITHUB_TOKEN:-}")
    if [ "$mirror" != default ]; then
        env+=("-e" "FLUTTER_STORAGE_BASE_URL=$mirror")
    fi
    docker run --rm --platform "$platform" "${env[@]}" "$image" 2>&1 | sed -e "s|^|[$prefix] |"
}

for vfox in $foxes; do
    for flavor in $flavours; do
        for mirror in $mirrors; do
            if [ -z "$mirror_explicit" ] && [ "$mirror" != default ] && [ "$vfox" != latest ]; then
                continue
            fi
            run_one "$vfox" "$flavor" "$mirror" &
            while [ "$(jobs -p | wc -l)" -ge "$max_jobs" ]; do
                if ! wait -n; then
                    failed=1
                fi
            done
        done
    done
done

while [ "$(jobs -p | wc -l)" -gt 0 ]; do
    if ! wait -n; then
        failed=1
    fi
done

exit "$failed"
