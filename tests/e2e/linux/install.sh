#!/usr/bin/env bash
set -eu

version="${1:?missing version}"

eval "$(vfox activate bash)"

attempt=1
while ! vfox install flutter@"$version"; do
    if [ "$attempt" -ge 5 ]; then
        echo "FAIL vfox install flutter@$version" >&2
        exit 1
    fi
    attempt=$((attempt + 1))
    sleep 10
done

vfox use --global flutter@"$version"
eval "$(vfox activate bash)"
