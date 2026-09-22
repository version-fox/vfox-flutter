#!/usr/bin/env bash
set -euo pipefail

here="$(dirname "${BASH_SOURCE[0]}")"
repo="$(cd "$here/../../.." && pwd)"
image="vfox-flutter-e2e:linux"

docker build --pull -f "$here/Dockerfile" -t "$image" "$repo"

foxes="${VFOX_VERSION:-latest main}"
flavours="${FLAVOR:-official ohos}"
mirrors="${MIRROR:-default https://storage.flutter-io.cn}"
mirror_explicit="${MIRROR:-}"

max_jobs=3
failed=0

run_one() {
    local vfox="$1"
    local flavor="$2"
    local mirror="$3"
    if [ "$mirror" = default ]; then
        docker run --rm -e VFOX_VERSION="$vfox" -e FLAVOR="$flavor" "$image" 2>&1 | sed -e "s|^|[vfox $vfox, $flavor, mirror $mirror] |"
    else
        docker run --rm -e VFOX_VERSION="$vfox" -e FLAVOR="$flavor" -e FLUTTER_STORAGE_BASE_URL="$mirror" "$image" 2>&1 | sed -e "s|^|[vfox $vfox, $flavor, mirror $mirror] |"
    fi
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
