#!/usr/bin/env bash
set -eu

version="${1:?missing version}"

eval "$(vfox activate bash)"
vfox install flutter@"$version"
vfox use --global flutter@"$version"
eval "$(vfox activate bash)"
