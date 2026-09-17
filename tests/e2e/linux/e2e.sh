#!/usr/bin/env bash
set -eu

here="$(dirname "${BASH_SOURCE[0]}")"
repo="$(cd "$here/../../.." && pwd)"
image="vfox-flutter-e2e:linux"

docker build --pull -f "$here/Dockerfile" -t "$image" "$repo"

for vfox in latest main; do
    for flavor in official ohos; do
        echo "=== vfox $vfox, $flavor ==="
        docker run --rm -e VFOX_VERSION="$vfox" -e FLAVOR="$flavor" "$image"
    done
done
