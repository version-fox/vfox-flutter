#!/usr/bin/env bash
set -eu

version="${1:?missing version}"

eval "$(vfox activate bash)"

install_code=1
for attempt in 1 2 3; do
    if vfox install flutter@"$version"; then
        install_code=0
        break
    else
        install_code=$?
    fi
    if [ "$attempt" -lt 3 ]; then
        echo "retrying vfox install flutter@${version}, attempt ${attempt} exited ${install_code}"
        sleep $((10 * attempt))
    fi
done

if [ "$install_code" -ne 0 ]; then
    echo "FAIL vfox install flutter@${version} exited with code ${install_code}" >&2
    exit 1
fi

vfox use --global flutter@"$version"
eval "$(vfox activate bash)"
