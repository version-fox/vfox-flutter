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

retry() {
    local label="$1"
    shift
    local output=""
    local code=1
    set +e
    for attempt in 1 2 3; do
        output="$("$@" 2>&1)"
        code=$?
        set -e
        if [ "$code" -eq 0 ]; then
            printf '%s' "$output"
            return 0
        fi
        if [ "$attempt" -lt 3 ]; then
            echo "retrying ${label}, attempt ${attempt} exited ${code}" >&2
            sleep $((10 * attempt))
            set +e
        fi
    done
    set -e
    printf '%s' "$output"
    return "$code"
}

flavor="${FLAVOR:?missing flavor}"
mirror="${FLUTTER_STORAGE_BASE_URL:-default}"
if [ "$flavor" = official ]; then
    version="${FLUTTER_VERSION:-3.47.4}"
elif [ "$flavor" = ohos ]; then
    version="${OHOS_VERSION:-3.41.10-ohos-1.0.0}"
else
    echo "FAIL unknown flavor $flavor" >&2
    exit 1
fi

echo "=== vfox ${VFOX_VERSION:-latest}, flutter $version, $flavor, mirror $mirror, $(uname -m) ==="
if [ "$flavor" = official ] && [ "$mirror" != default ]; then
    mirror_index="${mirror%/}/flutter_infra_release/releases/releases_linux.json"
    if retry "mirror $mirror_index" curl -fsSL --max-time 20 -o /dev/null "$mirror_index" >/dev/null; then
        echo "PASS mirror $mirror serves the releases index"
    else
        echo "FAIL mirror $mirror is unreachable ($mirror_index)" >&2
        exit 1
    fi
fi
source "$here/setup.sh"
if [ "$flavor" = official ]; then
    bogus_mirror="https://invalid.example.invalid"
    set +e
    bogus_output="$(FLUTTER_STORAGE_BASE_URL="$bogus_mirror" vfox install flutter@"$version" 2>&1)"
    bogus_code=$?
    set -e
    if [ "$bogus_code" -eq 0 ]; then
        echo 'FAIL bogus mirror install unexpectedly succeeded' >&2
        exit 1
    fi
    assert_contains "$bogus_output" "invalid.example.invalid" 'bogus mirror error'
fi
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

# --- in-place `flutter upgrade` drift detection ---------------------------
manifest="$sdk/.vfox-manifest"
if [ ! -f "$manifest" ]; then
    echo 'FAIL the SDK has no .vfox-manifest, so its installed version cannot be anchored' >&2
    exit 1
fi
echo 'PASS the SDK carries a .vfox-manifest'

installed_head="$(git -C "$sdk" rev-parse HEAD)"
anchor="$(sed -n 's/.*"expected_head"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest")"
if [ -z "$anchor" ]; then
    echo 'FAIL the .vfox-manifest has no expected_head' >&2
    exit 1
fi
if [ "$anchor" != "$installed_head" ]; then
    echo "FAIL the .vfox-manifest anchor $anchor does not match the installed git HEAD $installed_head" >&2
    exit 1
fi
echo 'PASS the .vfox-manifest anchor matches the installed git HEAD'

set +e
clean_output="$(vfox use --global flutter@"$version" 2>&1)"
clean_code=$?
set -e
if [ "$clean_code" -ne 0 ]; then
    echo "FAIL vfox use exited with code ${clean_code}" >&2
    exit 1
fi
if echo "$clean_output" | grep -qF 'has drifted'; then
    echo 'FAIL a freshly installed SDK reports drift' >&2
    echo "--- actual ---" >&2
    echo "$clean_output" >&2
    exit 1
fi
echo 'PASS a freshly installed SDK reports no drift'

if ! GIT_AUTHOR_NAME=e2e GIT_AUTHOR_EMAIL=e2e@vfox.flutter \
    GIT_COMMITTER_NAME=e2e GIT_COMMITTER_EMAIL=e2e@vfox.flutter \
    git -C "$sdk" commit --allow-empty -q -m 'simulated flutter upgrade'; then
    echo 'FAIL failed to record a simulated flutter upgrade commit' >&2
    exit 1
fi
drifted_head="$(git -C "$sdk" rev-parse HEAD)"

set +e
drift_output="$(vfox use --global flutter@"$version" 2>&1)"
drift_code=$?
set -e
if [ "$drift_code" -ne 0 ]; then
    echo "FAIL vfox use exited with code ${drift_code}" >&2
    exit 1
fi
assert_contains "$drift_output" 'has drifted from the version vfox installed' 'drift warning'
assert_contains "$drift_output" "$anchor" 'drift warning expected head'
assert_contains "$drift_output" "$drifted_head" 'drift warning current head'
assert_contains "$drift_output" "vfox uninstall flutter@$version" 'drift warning restore command'
assert_contains "$drift_output" "vfox install  flutter@$version" 'drift warning restore command'
assert_contains "$drift_output" "vfox use      flutter@$version" 'drift warning restore command'
assert_contains "$drift_output" 'vfox install flutter@<new-version>' 'drift warning upgrade command'

git -C "$sdk" reset -q --hard "$anchor"
set +e
restored_output="$(vfox use --global flutter@"$version" 2>&1)"
restored_code=$?
set -e
if [ "$restored_code" -ne 0 ]; then
    echo "FAIL vfox use exited with code ${restored_code}" >&2
    exit 1
fi
if echo "$restored_output" | grep -qF 'has drifted'; then
    echo 'FAIL a restored SDK still reports drift' >&2
    echo "--- actual ---" >&2
    echo "$restored_output" >&2
    exit 1
fi
echo 'PASS a restored SDK reports no drift'

if ! retry 'pub.dev' curl -fsSL --max-time 20 -o /dev/null 'https://pub.dev/api/packages/args' >/dev/null; then
    echo 'FAIL pub.dev is unreachable, the Flutter tool cannot bootstrap' >&2
    exit 1
fi
if ! dart="$(retry 'dart --version' dart --version)"; then
    echo 'FAIL dart --version did not run' >&2
    exit 1
fi
if ! flutter="$(retry 'flutter --version' flutter --version --no-version-check)"; then
    echo 'FAIL flutter --version did not run' >&2
    exit 1
fi
assert_contains "$flutter" "$(git -C "$sdk" rev-parse HEAD | cut -c1-10)" 'flutter --version revision'
assert_contains "$dart" "$(echo "$flutter" | awk '/Tools/ { print $4 }')" 'dart --version'
