#!/usr/bin/env bash
set -eu

here="$(dirname "${BASH_SOURCE[0]}")"

assert_contains() {
    local actual="$1"
    local expected="$2"
    local label="$3"
    if [ -z "$expected" ]; then
        echo "FAIL $label : the expected value is empty" >&2
        exit 1
    fi
    if echo "$actual" | grep -qF -- "$expected"; then
        echo "PASS $label contains $expected"
        return 0
    fi
    echo "FAIL $label is missing $expected" >&2
    echo "--- actual ---" >&2
    echo "$actual" >&2
    exit 1
}

flavor="${FLAVOR:?missing flavor}"
if [ "$flavor" = official ]; then
    version="${FLUTTER_VERSION:-3.47.4}"
elif [ "$flavor" = ohos ]; then
    version="${OHOS_VERSION:-3.41.10-ohos-1.0.0}"
else
    echo "FAIL unknown flavor $flavor" >&2
    exit 1
fi

echo "=== vfox ${VFOX_VERSION:-latest}, flutter $version, $flavor ==="
source "$here/setup.sh"
bash "$here/install.sh" "$version"
eval "$(vfox activate bash)"
sdk="$(cd "$(dirname "$(command -v flutter)")"/.. && pwd)"
if [ "$flavor" = official ]; then
    if git -C "$sdk" log -1 --format=%s | grep -qF 'vfox install'; then
        echo 'FAIL the official SDK carries a vfox commit' >&2
        exit 1
    fi
    echo 'PASS the official SDK carries no vfox commit'
else
    if [ ! -d "$sdk/.git" ]; then
        echo 'FAIL the OpenHarmony SDK is not a git checkout' >&2
        exit 1
    fi
    if [ -z "$(git -C "$sdk" ls-files bin/internal/engine.version)" ]; then
        echo 'FAIL the OpenHarmony engine version pin is not tracked' >&2
        exit 1
    fi
    echo 'PASS the OpenHarmony SDK is a git checkout with its engine pins tracked'
fi
if ! curl -fsSL --max-time 20 -o /dev/null 'https://pub.dev/api/packages/args'; then
    echo 'FAIL pub.dev is unreachable, the Flutter tool cannot bootstrap' >&2
    exit 1
fi
dart="$(dart --version)"
flutter="$(flutter --version --no-version-check)"
assert_contains "$flutter" "$(git -C "$sdk" rev-parse HEAD | cut -c1-10)" 'flutter --version revision'
assert_contains "$dart" "$(echo "$flutter" | awk '/Tools/ { print $4 }')" 'dart --version'
