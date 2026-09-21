#!/usr/bin/env bash
set -euo pipefail

here="$(dirname "${BASH_SOURCE[0]}")"
repo="$(cd "$here/../../.." && pwd)"
image="vfox-flutter-e2e:linux"

docker build --pull -f "$here/Dockerfile" -t "$image" "$repo"

foxes="${VFOX_VERSION:-latest main}"
flavours="${FLAVOR:-official ohos}"

max_jobs=3
failed=0

run_one() {
    local vfox="$1"
    local flavor="$2"
    docker run --rm -e VFOX_VERSION="$vfox" -e FLAVOR="$flavor" "$image" 2>&1 | sed -e "s/^/[vfox $vfox, $flavor] /"
}

for vfox in $foxes; do
    for flavor in $flavours; do
        run_one "$vfox" "$flavor" &
        while [ "$(jobs -p | wc -l)" -ge "$max_jobs" ]; do
            if ! wait -n; then
                failed=1
            fi
        done
    done
done

while [ "$(jobs -p | wc -l)" -gt 0 ]; do
    if ! wait -n; then
        failed=1
    fi
done

exit "$failed"
